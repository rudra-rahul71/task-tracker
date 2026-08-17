import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';

/// Provider exposing the current authenticated user's ID.
final userIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider).value?.uid;
});

/// StreamProvider providing a live list of Task Groups for the current user.
final taskGroupsProvider =
    StreamProvider.autoDispose<List<TaskGroupModel>>((ref) {
      final userId = ref.watch(userIdProvider);
      if (userId == null) return const Stream.empty();
      return ref.watch(taskRepositoryProvider).getGroups(userId);
    });

/// StreamProvider providing a live list of Tasks for the current user.
final tasksStreamProvider = StreamProvider.autoDispose<List<TaskModel>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(taskRepositoryProvider).getTasks(userId);
});

/// StateProvider holding the active task filter ('due', 'all', 'group', 'completed').
final taskFilterProvider = StateProvider<String>((ref) => 'due');

/// Pure utility helpers for evaluating task schedules, recurrence, and filtering.
class TaskEvaluationUtils {
  static TaskGroupModel? findGroup(
    String? groupId,
    List<TaskGroupModel> groups,
  ) {
    if (groupId == null) return null;
    for (final g in groups) {
      if (g.id == groupId) return g;
    }
    return null;
  }

  static (bool, DateTime?) getScheduleInfo(
    TaskModel task,
    List<TaskGroupModel> groups,
  ) {
    if (task.schedule != null) {
      return (task.schedule!.type != 'none', task.schedule!.startDate);
    }
    final group = findGroup(task.groupId, groups);
    if (group?.schedule != null) {
      return (group!.schedule!.type != 'none', group.schedule!.startDate);
    }
    return (false, null);
  }

  static bool isTaskRecurring(TaskModel task, List<TaskGroupModel> groups) {
    if (task.schedule != null) {
      return task.schedule!.type != 'none';
    }
    final group = findGroup(task.groupId, groups);
    return group?.schedule?.type != null && group!.schedule!.type != 'none';
  }

  static bool isCompletedToday(TaskModel t, [DateTime? currentDate]) {
    if (t.status != 'completed' || t.lastCompletedAt == null) {
      return false;
    }
    final now = currentDate ?? DateTime.now();
    return t.lastCompletedAt!.year == now.year &&
        t.lastCompletedAt!.month == now.month &&
        t.lastCompletedAt!.day == now.day;
  }

  static bool isTaskDueToday(
    TaskModel task,
    List<TaskGroupModel> groups, [
    DateTime? currentDate,
  ]) {
    final now = currentDate ?? DateTime.now();

    // 1. Task has its own schedule
    if (task.schedule != null) {
      if (task.schedule!.type != 'none' || task.schedule!.startDate != null) {
        return task.schedule!.isDueOnDate(now);
      }
    } else {
      // 2. Task inherits its group schedule
      final group = findGroup(task.groupId, groups);
      if (group?.schedule != null) {
        if (group!.schedule!.type != 'none' ||
            group.schedule!.startDate != null) {
          return group.schedule!.isDueOnDate(now);
        }
      }
    }

    // 3. Unscheduled tasks: show under "Due Today" if they are pending or completed today
    return task.status == 'pending' || isCompletedToday(task, now);
  }

  static bool isTaskOverdueOneOff(
    TaskModel task,
    List<TaskGroupModel> groups, [
    DateTime? currentDate,
  ]) {
    if (task.status != 'pending') return false;
    final now = currentDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (task.schedule != null) {
      if (task.schedule!.type == 'none' && task.schedule!.startDate != null) {
        final sDate = task.schedule!.startDate!;
        return DateTime(sDate.year, sDate.month, sDate.day).isBefore(today);
      }
      return false;
    }

    final g = findGroup(task.groupId, groups);
    if (g?.schedule != null) {
      if (g!.schedule!.type == 'none' && g.schedule!.startDate != null) {
        final sDate = g.schedule!.startDate!;
        return DateTime(sDate.year, sDate.month, sDate.day).isBefore(today);
      }
    }
    return false;
  }

  static (List<TaskModel>, List<TaskModel>) partitionTasksByOverdue(
    List<TaskModel> tasks,
    List<TaskGroupModel> groups, [
    DateTime? currentDate,
  ]) {
    final upcoming = <TaskModel>[];
    final overdue = <TaskModel>[];
    for (final t in tasks) {
      if (isTaskOverdueOneOff(t, groups, currentDate)) {
        overdue.add(t);
      } else {
        upcoming.add(t);
      }
    }
    return (overdue, upcoming);
  }

  static int sortTasks(
    TaskModel a,
    TaskModel b,
    List<TaskGroupModel> groups,
  ) {
    final (aIsScheduled, aStartDate) = getScheduleInfo(a, groups);
    final (bIsScheduled, bStartDate) = getScheduleInfo(b, groups);

    if (aIsScheduled && !bIsScheduled) return -1;
    if (!aIsScheduled && bIsScheduled) return 1;

    if (!aIsScheduled && !bIsScheduled) {
      if (aStartDate != null && bStartDate != null) {
        return aStartDate.compareTo(bStartDate);
      }
      if (aStartDate != null) return -1;
      if (bStartDate != null) return 1;
    }

    return a.createdAt.compareTo(b.createdAt);
  }

  static List<TaskModel> filterTasks({
    required List<TaskModel> tasks,
    required List<TaskGroupModel> groups,
    required String filter,
    DateTime? currentDate,
  }) {
    final now = currentDate ?? DateTime.now();

    if (filter == 'due') {
      return tasks.where((t) {
        final isDue = isTaskDueToday(t, groups, now);
        return isDue && (t.status == 'pending' || isCompletedToday(t, now));
      }).toList();
    } else if (filter == 'completed') {
      final completedTasks = tasks
          .where((t) => t.status == 'completed' && !isTaskRecurring(t, groups))
          .toList();

      completedTasks.sort((a, b) {
        if (a.lastCompletedAt != null && b.lastCompletedAt != null) {
          return b.lastCompletedAt!.compareTo(a.lastCompletedAt!);
        }
        return 0;
      });
      return completedTasks;
    } else {
      // 'all' or 'group'
      final allOrGroupTasks = tasks.where((t) {
        if (isTaskRecurring(t, groups)) return true;
        return t.status == 'pending';
      }).toList();

      allOrGroupTasks.sort((a, b) => sortTasks(a, b, groups));
      return allOrGroupTasks;
    }
  }
}

/// Computed selector provider that returns the filtered and sorted list of tasks.
final filteredTasksProvider =
    Provider.autoDispose<AsyncValue<List<TaskModel>>>((ref) {
      final tasksAsync = ref.watch(tasksStreamProvider);
      final groupsAsync = ref.watch(taskGroupsProvider);
      final filter = ref.watch(taskFilterProvider);

      return tasksAsync.whenData((tasks) {
        final groups = groupsAsync.value ?? [];
        return TaskEvaluationUtils.filterTasks(
          tasks: tasks,
          groups: groups,
          filter: filter,
        );
      });
    });
