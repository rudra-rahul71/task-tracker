import 'package:flutter/foundation.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_history.dart';
import 'package:task_tracker/features/tasks/data/models/task_schedule.dart';

class TaskRepository {
  final DatabaseRepository _repo;
  TaskRepository(this._repo);

  TypedCollection<TaskGroupModel> get _groupCollection =>
      TypedCollection<TaskGroupModel>(
        repo: _repo,
        collectionName: 'task_groups',
        toMap: (group) => group.toMap(),
        fromMap: (map, id) => TaskGroupModel.fromMap(map, id),
      );

  TypedCollection<TaskModel> get _taskCollection => TypedCollection<TaskModel>(
    repo: _repo,
    collectionName: 'tasks',
    toMap: (task) => task.toMap(),
    fromMap: (map, id) => TaskModel.fromMap(map, id),
  );

  TypedCollection<TaskHistoryModel> get _historyCollection =>
      TypedCollection<TaskHistoryModel>(
        repo: _repo,
        collectionName: 'task_history',
        toMap: (history) => history.toMap(),
        fromMap: (map, id) => TaskHistoryModel.fromMap(map, id),
      );

  // --- GROUPS ---

  Stream<List<TaskGroupModel>> getGroups(String userId) {
    return _groupCollection
        .watch(filters: [QueryFilter.eq('userId', userId)])
        .map((groups) {
          groups.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return groups;
        })
        .handleError((error, stackTrace) {
          debugPrint('Error loading task groups stream: $error');
          return <TaskGroupModel>[];
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

    // Also clear the groupId reference for all tasks in this group using batch update
    try {
      final tasks = await _taskCollection.fetch(
        filters: [QueryFilter.eq('userId', userId)],
      );

      final tasksToUpdate = tasks
          .where((t) => t.groupId == groupId)
          .map((task) => task.copyWith(groupId: null))
          .toList();

      if (tasksToUpdate.isNotEmpty) {
        await _taskCollection.saveBatch(tasksToUpdate);
      }
    } catch (e) {
      debugPrint('Error updating tasks on group deletion: $e');
    }
  }

  // --- TASKS ---

  Stream<List<TaskModel>> getTasks(String userId) {
    return _taskCollection
        .watch(filters: [QueryFilter.eq('userId', userId)])
        .map((tasks) {
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tasks;
        })
        .handleError((error, stackTrace) {
          debugPrint('Error loading tasks stream: $error');
          return <TaskModel>[];
        });
  }

  Future<void> addTask(TaskModel task) async {
    await _taskCollection.save(task, '');
  }

  Future<void> updateTask(TaskModel task, {String? oldStatus}) async {
    // To fetch the old status, we query for this task by ID if not provided
    if (oldStatus == null) {
      try {
        final existingTasks = await _taskCollection.fetch(
          filters: [QueryFilter.eq('id', task.id)],
        );
        if (existingTasks.isNotEmpty) {
          oldStatus = existingTasks.first.status;
        }
      } catch (e) {
        debugPrint('Error fetching task for status check: $e');
      }
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
        completedSteps: task.steps
            .where((s) => s.isCompleted)
            .map((s) => s.name)
            .toList(),
      );
      await _historyCollection.save(historyRecord, '');
    } else if (task.status == 'pending' && oldStatus == 'completed') {
      // 2. Task went from completed to pending (reset/uncompleted). Delete history for today
      try {
        final tomorrowZero = todayZero.add(const Duration(days: 1));
        final history = await _historyCollection.fetch(
          filters: [
            QueryFilter.eq('taskId', task.id),
            QueryFilter.gte('date', todayZero),
            QueryFilter.lt('date', tomorrowZero),
          ],
        );

        if (history.isNotEmpty) {
          await _historyCollection.deleteBatch(history.map((doc) => doc.id).toList());
        }
      } catch (e) {
        debugPrint('Error deleting today history on status reset: $e');
      }
    }
  }

  Future<void> deleteTask(String userId, String taskId) async {
    // 1. Delete task doc
    await _taskCollection.delete(taskId);

    // 2. Delete history docs in batch
    try {
      final history = await _historyCollection.fetch(
        filters: [QueryFilter.eq('taskId', taskId)],
      );

      if (history.isNotEmpty) {
        await _historyCollection.deleteBatch(history.map((doc) => doc.id).toList());
      }
    } catch (e) {
      debugPrint('Error clearing history on task deletion: $e');
    }
  }

  // Get completions stream bounded for a specific calendar month
  Stream<List<TaskHistoryModel>> getMonthlyTaskHistory(
    String userId,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(
      month.year,
      month.month + 1,
      1,
    ).subtract(const Duration(microseconds: 1));

    return _historyCollection
        .watch(
          filters: [
            QueryFilter.eq('userId', userId),
            QueryFilter.gte('date', start),
            QueryFilter.lte('date', end),
          ],
        )
        .map((history) {
          history.sort((a, b) => b.date.compareTo(a.date));
          return history;
        })
        .handleError((error, stackTrace) {
          debugPrint('Error loading task history stream: $error');
          return <TaskHistoryModel>[];
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
    final List<TaskModel> tasksToReset = [];

    for (var task in tasks) {
      // Determine effective schedule
      TaskSchedule? effectiveSchedule;
      if (task.schedule != null && task.schedule!.type != 'none') {
        effectiveSchedule = task.schedule;
      } else if (task.groupId != null) {
        final group = groupMap[task.groupId];
        if (group != null &&
            group.schedule != null &&
            group.schedule!.type != 'none') {
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

          tasksToReset.add(
            task.copyWith(
              steps: resetSteps,
              status: 'pending',
              lastResetAt: now,
            ),
          );
        }
      }
    }

    if (tasksToReset.isNotEmpty) {
      await _taskCollection.saveBatch(tasksToReset);
    }
  }
}
