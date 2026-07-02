import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_history.dart';
import 'package:task_tracker/features/tasks/data/models/task_schedule.dart';

class TaskRepository {
  final DatabaseRepository _repo = GetIt.instance<DatabaseRepository>();

  late final _groupCollection = TypedCollection<TaskGroupModel>(
    repo: _repo,
    collectionName: 'task_groups',
    toMap: (group) => group.toMap(),
    fromMap: (map, id) => TaskGroupModel.fromMap(map, id),
  );

  late final _taskCollection = TypedCollection<TaskModel>(
    repo: _repo,
    collectionName: 'tasks',
    toMap: (task) => task.toMap(),
    fromMap: (map, id) => TaskModel.fromMap(map, id),
  );

  late final _historyCollection = TypedCollection<TaskHistoryModel>(
    repo: _repo,
    collectionName: 'task_history',
    toMap: (history) => history.toMap(),
    fromMap: (map, id) => TaskHistoryModel.fromMap(map, id),
  );

  // --- GROUPS ---

  Stream<List<TaskGroupModel>> getGroups(String userId) {
    return _groupCollection.watch(
      filters: [QueryFilter.eq('userId', userId)],
    ).map((groups) {
      groups.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return groups;
    });
  }

  Future<void> addGroup(TaskGroupModel group) async {
    await _groupCollection.save(group, '');
  }

  Future<void> updateGroup(TaskGroupModel group) async {
    await _groupCollection.save(group, group.id);
  }

  Future<void> deleteGroup(String userId, String groupId) async {
    // Delete the group itself
    await _groupCollection.delete(groupId);

    // Also clear the groupId reference for all tasks in this group
    try {
      final tasks = await _taskCollection.watch(
        filters: [QueryFilter.eq('userId', userId)],
      ).first;

      final tasksToUpdate = tasks.where((t) => t.groupId == groupId).toList();
      for (var task in tasksToUpdate) {
        final updatedTask = TaskModel(
          id: task.id,
          userId: task.userId,
          groupId: null,
          name: task.name,
          description: task.description,
          schedule: task.schedule,
          steps: task.steps,
          status: task.status,
          lastCompletedAt: task.lastCompletedAt,
          lastResetAt: task.lastResetAt,
          createdAt: task.createdAt,
        );
        await _taskCollection.save(updatedTask, task.id);
      }
    } catch (e) {
      debugPrint('Error updating tasks on group deletion: $e');
    }
  }

  // --- TASKS ---

  Stream<List<TaskModel>> getTasks(String userId) {
    return _taskCollection.watch(
      filters: [QueryFilter.eq('userId', userId)],
    ).map((tasks) {
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tasks;
    });
  }

  Future<void> addTask(TaskModel task) async {
    await _taskCollection.save(task, '');
  }

  Future<void> updateTask(TaskModel task) async {
    // To fetch the old status, we query for this task by ID
    String? oldStatus;
    try {
      final existingTasks = await _taskCollection.watch(
        filters: [QueryFilter.eq('id', task.id)],
      ).first;
      if (existingTasks.isNotEmpty) {
        oldStatus = existingTasks.first.status;
      }
    } catch (e) {
      debugPrint('Error fetching task for status check: $e');
    }

    await _taskCollection.save(task, task.id);

    final today = DateTime.now();
    final todayZero = DateTime(today.year, today.month, today.day);

    if (task.status == 'completed' && oldStatus != 'completed') {
      // 1. Task completed! Log history
      final historyRecord = TaskHistoryModel(
        id: '',
        userId: task.userId,
        taskId: task.id,
        taskName: task.name,
        groupId: task.groupId,
        date: todayZero,
        completedSteps: task.steps.where((s) => s.isCompleted).map((s) => s.name).toList(),
      );
      await _historyCollection.save(historyRecord, '');
    } else if (task.status == 'pending' && oldStatus == 'completed') {
      // 2. Task went from completed to pending (reset/uncompleted). Delete history for today
      try {
        final history = await _historyCollection.watch(
          filters: [QueryFilter.eq('taskId', task.id)],
        ).first;

        final todayHistory = history.where((h) {
          final hDate = DateTime(h.date.year, h.date.month, h.date.day);
          return hDate == todayZero;
        }).toList();

        for (var doc in todayHistory) {
          await _historyCollection.delete(doc.id);
        }
      } catch (e) {
        debugPrint('Error deleting today history on status reset: $e');
      }
    }
  }

  Future<void> deleteTask(String userId, String taskId) async {
    // 1. Delete task doc
    await _taskCollection.delete(taskId);

    // 2. Delete history docs
    try {
      final history = await _historyCollection.watch(
        filters: [QueryFilter.eq('taskId', taskId)],
      ).first;

      for (var doc in history) {
        await _historyCollection.delete(doc.id);
      }
    } catch (e) {
      debugPrint('Error clearing history on task deletion: $e');
    }
  }

  // Get completions stream for a specific month
  Stream<List<TaskHistoryModel>> getMonthlyTaskHistory(String userId, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1).subtract(const Duration(microseconds: 1));

    return _historyCollection.watch(
      filters: [QueryFilter.eq('userId', userId)],
    ).map((history) {
      // Filter date range client side for simplicity across database drivers
      return history.where((h) => h.date.isAfter(start.subtract(const Duration(microseconds: 1))) && h.date.isBefore(end.add(const Duration(microseconds: 1)))).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  // Scan and reset tasks if they have crossed into a new scheduling cycle
  Future<void> checkAndResetScheduledTasks({
    required String userId,
    required List<TaskModel> tasks,
    required List<TaskGroupModel> groups,
  }) async {
    final now = DateTime.now();
    final groupMap = {for (var g in groups) g.id: g};
    final List<Future<void>> updateFutures = [];

    for (var task in tasks) {
      // Determine effective schedule
      TaskSchedule? effectiveSchedule;
      if (task.schedule != null && task.schedule!.type != 'none') {
        effectiveSchedule = task.schedule;
      } else if (task.groupId != null) {
        final group = groupMap[task.groupId];
        if (group != null && group.schedule != null && group.schedule!.type != 'none') {
          effectiveSchedule = group.schedule;
        }
      }
      if (effectiveSchedule != null) {
        if (effectiveSchedule.needsReset(now, task.lastResetAt)) {
          // Task needs a reset for the new cycle!
          final resetSteps = task.steps.map((step) {
            return step.copyWith(
              isCompleted: false,
              clearTimerStartedAt: true,
              clearTimerPausedAt: true,
              timerSecondsRemaining: step.timerDuration,
              isTimerConfirmed: false,
            );
          }).toList();

          final updatedTask = task.copyWith(
            steps: resetSteps,
            status: 'pending',
            lastResetAt: now,
          );

          updateFutures.add(_taskCollection.save(updatedTask, task.id));
        }
      }
    }

    if (updateFutures.isNotEmpty) {
      await Future.wait(updateFutures);
    }
  }
}
