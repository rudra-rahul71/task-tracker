import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/features/tasks/presentation/providers/task_providers.dart';
import 'package:task_tracker/features/trackers/presentation/providers/tracker_providers.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/models/tracker_history.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_history.dart';
import 'package:task_tracker/features/home/presentation/widgets/calendar_widget.dart';

/// StateProvider for currently focused calendar month.
final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// StateProvider for currently selected day in the dashboard.
final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// StreamProvider.family for monthly tracker history.
final monthlyTrackerHistoryProvider = StreamProvider.family
    .autoDispose<List<TrackerHistoryModel>, DateTime>((ref, month) {
      final userId = ref.watch(userIdProvider);
      if (userId == null) return const Stream.empty();
      return ref
          .watch(trackerRepositoryProvider)
          .getMonthlyHistory(userId, month);
    });

/// StreamProvider.family for monthly task completion history.
final monthlyTaskHistoryProvider = StreamProvider.family
    .autoDispose<List<TaskHistoryModel>, DateTime>((ref, month) {
      final userId = ref.watch(userIdProvider);
      if (userId == null) return const Stream.empty();
      return ref
          .watch(taskRepositoryProvider)
          .getMonthlyTaskHistory(userId, month);
    });

/// Daily details data bundle for the selected day.
class DailyDetailsData {
  final DateTime selectedDay;
  final List<TrackerModel> completedTrackers;
  final List<TrackerModel> slippedTrackers;
  final List<TaskModel> completedTasks;
  final List<TaskModel> pendingTasks;
  final List<TaskGroupModel> groups;

  const DailyDetailsData({
    required this.selectedDay,
    required this.completedTrackers,
    required this.slippedTrackers,
    required this.completedTasks,
    required this.pendingTasks,
    required this.groups,
  });
}

/// Pure calendar calculation helpers.
class CalendarCalculationUtils {
  static bool isTaskDueOnDate(
    TaskModel task,
    Map<String, TaskGroupModel> groupMap,
    DateTime date,
  ) {
    final dateZero = DateTime(date.year, date.month, date.day);
    final createdZero = DateTime(
      task.createdAt.year,
      task.createdAt.month,
      task.createdAt.day,
    );
    if (dateZero.isBefore(createdZero)) {
      return false;
    }

    if (task.schedule != null) {
      if (task.schedule!.type != 'none' || task.schedule!.startDate != null) {
        if (task.status == 'completed' && task.schedule!.type == 'none') {
          return false;
        }
        return task.schedule!.isDueOnDate(date);
      }
    } else {
      if (task.groupId != null) {
        final group = groupMap[task.groupId];
        if (group != null && group.schedule != null) {
          if (group.schedule!.type != 'none' ||
              group.schedule!.startDate != null) {
            if (task.status == 'completed' && group.schedule!.type == 'none') {
              return false;
            }
            return group.schedule!.isDueOnDate(date);
          }
        }
      }
    }

    final today = DateTime.now();
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    return isToday && task.status == 'pending';
  }

  static bool isTaskCompletedOnDate(
    TaskModel task,
    Map<String, bool> taskHistoryMap,
    String dateKey,
  ) {
    return taskHistoryMap["${task.id}_$dateKey"] ?? false;
  }

  static bool hasTrackerSlipUpOnDay(
    TrackerModel tracker,
    DateTime dayDate,
    String dateKey,
    Map<String, Set<String>> trackerHistoryMap,
  ) {
    final lookupKey = "${tracker.id}_$dateKey";
    if (tracker.type == 'quit') {
      return trackerHistoryMap[lookupKey]?.contains('slip_up') ?? false;
    } else {
      final dayZero = DateTime(dayDate.year, dayDate.month, dayDate.day);
      final originalStartZero = DateTime(
        tracker.originalStartDate.year,
        tracker.originalStartDate.month,
        tracker.originalStartDate.day,
      );
      final todayZero = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final endZero = tracker.endDate != null
          ? DateTime(
              tracker.endDate!.year,
              tracker.endDate!.month,
              tracker.endDate!.day,
            )
          : null;

      if (dayZero.isBefore(todayZero) &&
          !dayZero.isBefore(originalStartZero) &&
          (endZero == null || !dayZero.isAfter(endZero))) {
        return !isTrackerCompletedOnDay(
          tracker,
          dayDate,
          dateKey,
          trackerHistoryMap,
        );
      }
      return false;
    }
  }

  static bool isTrackerCompletedOnDay(
    TrackerModel tracker,
    DateTime dayDate,
    String dateKey,
    Map<String, Set<String>> trackerHistoryMap,
  ) {
    final dayZero = DateTime(dayDate.year, dayDate.month, dayDate.day);
    final originalStartZero = DateTime(
      tracker.originalStartDate.year,
      tracker.originalStartDate.month,
      tracker.originalStartDate.day,
    );
    final todayZero = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    if (dayZero.isBefore(originalStartZero) || dayZero.isAfter(todayZero)) {
      return false;
    }

    if (tracker.type == 'maintain') {
      final lookupKey = "${tracker.id}_$dateKey";
      final hasManualCompletion =
          trackerHistoryMap[lookupKey]?.contains('completion') ?? false;
      if (hasManualCompletion) return true;

      final createdZero = DateTime(
        tracker.createdAt.year,
        tracker.createdAt.month,
        tracker.createdAt.day,
      );
      if (dayZero.isBefore(todayZero) && dayZero.isBefore(createdZero)) {
        return true;
      }

      final newStartDate = tracker.getNewStartDateIfResetNeeded(DateTime.now());
      final currentStartZero = DateTime(
        (newStartDate ?? tracker.startDate).year,
        (newStartDate ?? tracker.startDate).month,
        (newStartDate ?? tracker.startDate).day,
      );
      if (dayZero.isBefore(todayZero) && !dayZero.isBefore(currentStartZero)) {
        return true;
      }

      return false;
    } else {
      return !hasTrackerSlipUpOnDay(
        tracker,
        dayDate,
        dateKey,
        trackerHistoryMap,
      );
    }
  }

  static Map<String, CalendarDayData> calculateCalendarEvents({
    required DateTime month,
    required List<TrackerModel> trackers,
    required List<TrackerHistoryModel> trackerHistory,
    required List<TaskModel> tasks,
    required List<TaskHistoryModel> taskHistory,
    required List<TaskGroupModel> groups,
    required Color errorColor,
    required Color tertiaryColor,
    required Color defaultTaskColor,
  }) {
    final Map<String, Set<String>> trackerHistoryMap = {};
    for (var h in trackerHistory) {
      final dateKey = "${h.date.year}-${h.date.month}-${h.date.day}";
      final key = "${h.trackerId}_$dateKey";
      trackerHistoryMap.putIfAbsent(key, () => {}).add(h.type);
    }

    final Map<String, bool> taskHistoryMap = {};
    for (var h in taskHistory) {
      final dateKey = "${h.date.year}-${h.date.month}-${h.date.day}";
      final key = "${h.taskId}_$dateKey";
      taskHistoryMap[key] = true;
    }

    final Map<String, TaskGroupModel> groupMap = {
      for (var g in groups) g.id: g,
    };

    final Map<String, CalendarDayData> calendarEvents = {};
    final year = month.year;
    final monthInt = month.month;
    final firstDay = DateTime(year, monthInt, 1);
    final emptySlots = firstDay.weekday % 7;
    final daysInMonth = DateTime(year, monthInt + 1, 0).day;
    final totalCells = emptySlots + daysInMonth;

    for (int index = emptySlots; index < totalCells; index++) {
      final dayNum = index - emptySlots + 1;
      final dayDate = DateTime(year, monthInt, dayNum);
      final dayDateKey = "${dayDate.year}-${dayDate.month}-${dayDate.day}";

      final completedForDay = trackers
          .where(
            (t) =>
                isTrackerCompletedOnDay(t, dayDate, dayDateKey, trackerHistoryMap),
          )
          .toList();

      final trackerIndicators = completedForDay.map((t) {
        return t.type == 'quit' ? errorColor : tertiaryColor;
      }).toList();

      final tasksOnDay = tasks.where((t) {
        return isTaskDueOnDate(t, groupMap, dayDate) ||
            isTaskCompletedOnDate(t, taskHistoryMap, dayDateKey);
      }).toList();

      final calendarTasks = tasksOnDay.map((t) {
        final isCompleted = isTaskCompletedOnDate(
          t,
          taskHistoryMap,
          dayDateKey,
        );
        final group = t.groupId != null ? groupMap[t.groupId] : null;
        final color = group != null && group.id.isNotEmpty
            ? Color(group.colorValue)
            : defaultTaskColor;
        return CalendarTaskData(
          name: t.name,
          color: color,
          isCompleted: isCompleted,
        );
      }).toList();

      calendarEvents[dayDateKey] = CalendarDayData(
        trackerIndicators: trackerIndicators,
        tasks: calendarTasks,
      );
    }

    return calendarEvents;
  }
}

/// Computed provider for calendar events in the focused month.
final calendarEventsProvider =
    Provider.autoDispose<AsyncValue<Map<String, CalendarDayData>>>((ref) {
      final month = ref.watch(focusedMonthProvider);
      final trackersAsync = ref.watch(trackersStreamProvider);
      final trackerHistoryAsync = ref.watch(
        monthlyTrackerHistoryProvider(month),
      );
      final tasksAsync = ref.watch(tasksStreamProvider);
      final taskHistoryAsync = ref.watch(monthlyTaskHistoryProvider(month));
      final groupsAsync = ref.watch(taskGroupsProvider);

      if (trackersAsync.isLoading ||
          trackerHistoryAsync.isLoading ||
          tasksAsync.isLoading ||
          taskHistoryAsync.isLoading ||
          groupsAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (trackersAsync.hasError) {
        return AsyncValue.error(
          trackersAsync.error!,
          trackersAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (tasksAsync.hasError) {
        return AsyncValue.error(
          tasksAsync.error!,
          tasksAsync.stackTrace ?? StackTrace.current,
        );
      }

      final trackers = trackersAsync.value ?? [];
      final trackerHistory = trackerHistoryAsync.value ?? [];
      final tasks = tasksAsync.value ?? [];
      final taskHistory = taskHistoryAsync.value ?? [];
      final groups = groupsAsync.value ?? [];

      const errorColor = Color(0xFFEF5350);
      const tertiaryColor = Color(0xFF26A69A);
      const primaryColor = Color(0xFFD4AF37);

      final events = CalendarCalculationUtils.calculateCalendarEvents(
        month: month,
        trackers: trackers,
        trackerHistory: trackerHistory,
        tasks: tasks,
        taskHistory: taskHistory,
        groups: groups,
        errorColor: errorColor,
        tertiaryColor: tertiaryColor,
        defaultTaskColor: primaryColor,
      );

      return AsyncValue.data(events);
    });

/// Computed provider for detailed metrics and lists on the selected day.
final dayDetailsProvider =
    Provider.autoDispose<AsyncValue<DailyDetailsData>>((ref) {
      final selectedDay = ref.watch(selectedDayProvider);
      final month = DateTime(selectedDay.year, selectedDay.month);

      final trackersAsync = ref.watch(trackersStreamProvider);
      final trackerHistoryAsync = ref.watch(
        monthlyTrackerHistoryProvider(month),
      );
      final tasksAsync = ref.watch(tasksStreamProvider);
      final taskHistoryAsync = ref.watch(monthlyTaskHistoryProvider(month));
      final groupsAsync = ref.watch(taskGroupsProvider);

      if (trackersAsync.isLoading ||
          trackerHistoryAsync.isLoading ||
          tasksAsync.isLoading ||
          taskHistoryAsync.isLoading ||
          groupsAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (trackersAsync.hasError) {
        return AsyncValue.error(
          trackersAsync.error!,
          trackersAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (tasksAsync.hasError) {
        return AsyncValue.error(
          tasksAsync.error!,
          tasksAsync.stackTrace ?? StackTrace.current,
        );
      }

      final trackers = trackersAsync.value ?? [];
      final trackerHistory = trackerHistoryAsync.value ?? [];
      final tasks = tasksAsync.value ?? [];
      final taskHistory = taskHistoryAsync.value ?? [];
      final groups = groupsAsync.value ?? [];

      final Map<String, Set<String>> trackerHistoryMap = {};
      for (var h in trackerHistory) {
        final dateKey = "${h.date.year}-${h.date.month}-${h.date.day}";
        final key = "${h.trackerId}_$dateKey";
        trackerHistoryMap.putIfAbsent(key, () => {}).add(h.type);
      }

      final Map<String, bool> taskHistoryMap = {};
      for (var h in taskHistory) {
        final dateKey = "${h.date.year}-${h.date.month}-${h.date.day}";
        final key = "${h.taskId}_$dateKey";
        taskHistoryMap[key] = true;
      }

      final Map<String, TaskGroupModel> groupMap = {
        for (var g in groups) g.id: g,
      };

      final selectedDayKey =
          "${selectedDay.year}-${selectedDay.month}-${selectedDay.day}";

      final completedTrackers = trackers
          .where(
            (t) => CalendarCalculationUtils.isTrackerCompletedOnDay(
              t,
              selectedDay,
              selectedDayKey,
              trackerHistoryMap,
            ),
          )
          .toList();

      final slippedTrackers = trackers
          .where(
            (t) => CalendarCalculationUtils.hasTrackerSlipUpOnDay(
              t,
              selectedDay,
              selectedDayKey,
              trackerHistoryMap,
            ),
          )
          .toList();

      final completedTasks = tasks
          .where(
            (task) => CalendarCalculationUtils.isTaskCompletedOnDate(
              task,
              taskHistoryMap,
              selectedDayKey,
            ),
          )
          .toList();

      final pendingTasks = tasks.where((task) {
        final isDue = CalendarCalculationUtils.isTaskDueOnDate(
          task,
          groupMap,
          selectedDay,
        );
        final isCompleted = CalendarCalculationUtils.isTaskCompletedOnDate(
          task,
          taskHistoryMap,
          selectedDayKey,
        );
        return isDue && !isCompleted;
      }).toList();

      return AsyncValue.data(
        DailyDetailsData(
          selectedDay: selectedDay,
          completedTrackers: completedTrackers,
          slippedTrackers: slippedTrackers,
          completedTasks: completedTasks,
          pendingTasks: pendingTasks,
          groups: groups,
        ),
      );
    });
