import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/core/widgets/page_header.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/repositories/tracker_repository.dart';
import 'package:task_tracker/features/trackers/data/models/tracker_history.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';
import 'package:task_tracker/features/tasks/data/models/task_history.dart';
import 'package:task_tracker/features/home/presentation/widgets/calendar_widget.dart';
import 'package:task_tracker/features/home/presentation/widgets/daily_details_widget.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  TrackerRepository get _repository => ref.read(trackerRepositoryProvider);
  TaskRepository get _taskRepository => ref.read(taskRepositoryProvider);
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _currentUserId;
  Stream<List<TrackerModel>>? _trackersStream;
  Stream<List<TrackerHistoryModel>>? _historyStream;
  Stream<List<TaskModel>>? _tasksStream;
  Stream<List<TaskGroupModel>>? _groupsStream;
  Stream<List<TaskHistoryModel>>? _taskHistoryStream;
  Stream<_HomeData>? _combinedStream;
  DateTime? _cachedFocusedMonth;
  String? _historyStreamUserId;

  void _initCombinedStream(String userId, DateTime focusedMonth) {
    bool streamsChanged = false;

    if (_currentUserId != userId ||
        _trackersStream == null ||
        _tasksStream == null ||
        _groupsStream == null) {
      _currentUserId = userId;
      _trackersStream = _repository.getTrackers(userId);
      _tasksStream = _taskRepository.getTasks(userId);
      _groupsStream = _taskRepository.getGroups(userId);
      streamsChanged = true;
    }

    if (_historyStreamUserId != userId ||
        _historyStream == null ||
        _taskHistoryStream == null ||
        _cachedFocusedMonth == null ||
        _cachedFocusedMonth!.year != focusedMonth.year ||
        _cachedFocusedMonth!.month != focusedMonth.month) {
      _historyStreamUserId = userId;
      _cachedFocusedMonth = focusedMonth;
      _historyStream = _repository.getMonthlyHistory(userId, focusedMonth);
      _taskHistoryStream = _taskRepository.getMonthlyTaskHistory(
        userId,
        focusedMonth,
      );
      streamsChanged = true;
    }

    if (streamsChanged || _combinedStream == null) {
      _combinedStream =
          Rx.combineLatest5<
            List<TrackerModel>,
            List<TrackerHistoryModel>,
            List<TaskHistoryModel>,
            List<TaskGroupModel>,
            List<TaskModel>,
            _HomeData
          >(
            _trackersStream!,
            _historyStream!,
            _taskHistoryStream!,
            _groupsStream!,
            _tasksStream!,
            (trackers, history, taskHistory, groups, tasks) => _HomeData(
              trackers: trackers,
              history: history,
              taskHistory: taskHistory,
              groups: groups,
              tasks: tasks,
            ),
          );
    }
  }

  bool _isTaskDueOnDate(
    TaskModel task,
    Map<String, TaskGroupModel> groupMap,
    DateTime date,
  ) {
    // A task cannot be due before its creation date
    final dateZero = DateTime(date.year, date.month, date.day);
    final createdZero = DateTime(
      task.createdAt.year,
      task.createdAt.month,
      task.createdAt.day,
    );
    if (dateZero.isBefore(createdZero)) {
      return false;
    }

    // 1. Task has its own schedule
    if (task.schedule != null) {
      if (task.schedule!.type != 'none' || task.schedule!.startDate != null) {
        if (task.status == 'completed' && task.schedule!.type == 'none') {
          return false; // Only show completed one-off tasks on the day they were completed
        }
        return task.schedule!.isDueOnDate(date);
      }
    } else {
      // 2. Task inherits its group schedule
      if (task.groupId != null) {
        final group = groupMap[task.groupId];
        if (group != null && group.schedule != null) {
          if (group.schedule!.type != 'none' ||
              group.schedule!.startDate != null) {
            if (task.status == 'completed' && group.schedule!.type == 'none') {
              return false; // Only show completed one-off tasks on the day they were completed
            }
            return group.schedule!.isDueOnDate(date);
          }
        }
      }
    }

    // 3. Unscheduled tasks: show under "Due Today" if they are pending (so they don't get lost)
    // For the calendar, we only display unscheduled pending tasks on today's date.
    final today = DateTime.now();
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    return isToday && task.status == 'pending';
  }

  bool _isTaskCompletedOnDate(
    TaskModel task,
    Map<String, bool> taskHistoryMap,
    String dateKey,
  ) {
    return taskHistoryMap["${task.id}_$dateKey"] ?? false;
  }

  bool _hasTrackerSlipUpOnDay(
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
        return !_isTrackerCompletedOnDay(
          tracker,
          dayDate,
          dateKey,
          trackerHistoryMap,
        );
      }
      return false;
    }
  }

  bool _isTrackerCompletedOnDay(
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

      // Assume completed properly if it is in the past before the tracker was created
      final createdZero = DateTime(
        tracker.createdAt.year,
        tracker.createdAt.month,
        tracker.createdAt.day,
      );
      if (dayZero.isBefore(todayZero) && dayZero.isBefore(createdZero)) {
        return true;
      }

      // Assume completed properly if it is part of the current active streak
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
      return !_hasTrackerSlipUpOnDay(
        tracker,
        dayDate,
        dateKey,
        trackerHistoryMap,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = ref.read(authRepositoryProvider).currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    _initCombinedStream(userId, _focusedMonth);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<_HomeData>(
        stream: _combinedStream!,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading dashboard: ${snapshot.error}',
                style: TextStyle(color: colorScheme.error, fontSize: 16),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final trackers = data.trackers;
          final history = data.history;
          final taskHistory = data.taskHistory;
          final groups = data.groups;
          final tasks = data.tasks;

          // Pre-index monthly tracker history
          final Map<String, Set<String>> trackerHistoryMap = {};
          for (var h in history) {
            final dateKey = "${h.date.year}-${h.date.month}-${h.date.day}";
            final key = "${h.trackerId}_$dateKey";
            trackerHistoryMap.putIfAbsent(key, () => {}).add(h.type);
          }

          // Pre-index monthly task history
          final Map<String, bool> taskHistoryMap = {};
          for (var h in taskHistory) {
            final dateKey = "${h.date.year}-${h.date.month}-${h.date.day}";
            final key = "${h.taskId}_$dateKey";
            taskHistoryMap[key] = true;
          }

          // Pre-index task groups
          final Map<String, TaskGroupModel> groupMap = {
            for (var g in groups) g.id: g,
          };

          // Check if any maintain trackers missed their period and require an auto-reset
          if (trackers.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final now = DateTime.now();
              for (final tracker in trackers) {
                final newStart = tracker.getNewStartDateIfResetNeeded(now);
                if (newStart != null) {
                  _repository.autoResetTracker(tracker, newStart);
                }
              }
            });
          }

          // Dynamically run the check/reset scheduler logic
          if (tasks.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _taskRepository.checkAndResetScheduledTasks(
                userId: userId,
                tasks: tasks,
                groups: groups,
              );
            });
          }

          final selectedDayKey =
              "${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}";

          // Pre-calculate all Calendar events
          final Map<String, CalendarDayData> calendarEvents = {};
          final year = _focusedMonth.year;
          final month = _focusedMonth.month;
          final firstDay = DateTime(year, month, 1);
          final emptySlots = firstDay.weekday % 7;
          final daysInMonth = DateTime(year, month + 1, 0).day;
          final totalCells = emptySlots + daysInMonth;

          for (int index = emptySlots; index < totalCells; index++) {
            final dayNum = index - emptySlots + 1;
            final dayDate = DateTime(year, month, dayNum);
            final dayDateKey =
                "${dayDate.year}-${dayDate.month}-${dayDate.day}";

            final completedForDay = trackers
                .where(
                  (t) => _isTrackerCompletedOnDay(
                    t,
                    dayDate,
                    dayDateKey,
                    trackerHistoryMap,
                  ),
                )
                .toList();

            final trackerIndicators = completedForDay.map((t) {
              return t.type == 'quit'
                  ? colorScheme.error
                  : colorScheme.tertiary;
            }).toList();

            final tasksOnDay = tasks.where((t) {
              return _isTaskDueOnDate(t, groupMap, dayDate) ||
                  _isTaskCompletedOnDate(t, taskHistoryMap, dayDateKey);
            }).toList();

            final calendarTasks = tasksOnDay.map((t) {
              final isCompleted = _isTaskCompletedOnDate(
                t,
                taskHistoryMap,
                dayDateKey,
              );
              final group = t.groupId != null ? groupMap[t.groupId] : null;
              final color = group != null && group.id.isNotEmpty
                  ? Color(group.colorValue)
                  : Theme.of(context).colorScheme.primary;
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

          // Look up completions and slip-ups for the currently selected day
          final completedOnSelected = trackers.where((tracker) {
            return _isTrackerCompletedOnDay(
              tracker,
              _selectedDay,
              selectedDayKey,
              trackerHistoryMap,
            );
          }).toList();

          final slippedOnSelected = trackers.where((tracker) {
            return _hasTrackerSlipUpOnDay(
              tracker,
              _selectedDay,
              selectedDayKey,
              trackerHistoryMap,
            );
          }).toList();

          // Look up tasks completed or pending on the currently selected day using history
          final completedTasksOnSelected = tasks.where((task) {
            return _isTaskCompletedOnDate(task, taskHistoryMap, selectedDayKey);
          }).toList();

          final pendingTasksOnSelected = tasks.where((task) {
            final isDue = _isTaskDueOnDate(task, groupMap, _selectedDay);
            final isCompleted = _isTaskCompletedOnDate(
              task,
              taskHistoryMap,
              selectedDayKey,
            );
            return isDue && !isCompleted;
          }).toList();

          final width = MediaQuery.of(context).size.width;
          final isLargeScreen = width >= 850;

          // Main Layout
          final mainContent = LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = constraints.maxHeight;
              final headerAndPadding = 128.0;
              final availableCardHeight = viewportHeight - headerAndPadding;
              const minCardHeight = 460.0;
              final targetCardHeight = availableCardHeight.clamp(
                minCardHeight,
                double.infinity,
              );

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const PageHeader(
                        header: 'Dashboard',
                        sub: 'Visualize your habits and tasks history',
                      ),
                      const SizedBox(height: 24),
                      isLargeScreen
                          ? SizedBox(
                              height: targetCardHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: DailyDetailsWidget(
                                      selectedDay: _selectedDay,
                                      completedTrackers: completedOnSelected,
                                      slippedTrackers: slippedOnSelected,
                                      completedTasks: completedTasksOnSelected,
                                      pendingTasks: pendingTasksOnSelected,
                                      groups: groups,
                                      isScrollable: true,
                                      taskRepository: _taskRepository,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 4,
                                    child: CalendarWidget(
                                      focusedMonth: _focusedMonth,
                                      selectedDay: _selectedDay,
                                      eventsMap: calendarEvents,
                                      onMonthChanged: (month) {
                                        setState(() {
                                          _focusedMonth = month;
                                        });
                                      },
                                      onDaySelected: (day) {
                                        setState(() {
                                          _selectedDay = day;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DailyDetailsWidget(
                                  selectedDay: _selectedDay,
                                  completedTrackers: completedOnSelected,
                                  slippedTrackers: slippedOnSelected,
                                  completedTasks: completedTasksOnSelected,
                                  pendingTasks: pendingTasksOnSelected,
                                  groups: groups,
                                  isScrollable: false,
                                  taskRepository: _taskRepository,
                                ),
                                const SizedBox(height: 24),
                                CalendarWidget(
                                  focusedMonth: _focusedMonth,
                                  selectedDay: _selectedDay,
                                  eventsMap: calendarEvents,
                                  onMonthChanged: (month) {
                                    setState(() {
                                      _focusedMonth = month;
                                    });
                                  },
                                  onDaySelected: (day) {
                                    setState(() {
                                      _selectedDay = day;
                                    });
                                  },
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              );
            },
          );

          final isWaiting = snapshot.connectionState == ConnectionState.waiting;

          return Stack(
            children: [
              isLargeScreen
                  ? mainContent
                  : Scaffold(
                      backgroundColor: Colors.transparent,
                      body: mainContent,
                    ),
              if (isWaiting)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeData {
  final List<TrackerModel> trackers;
  final List<TrackerHistoryModel> history;
  final List<TaskHistoryModel> taskHistory;
  final List<TaskGroupModel> groups;
  final List<TaskModel> tasks;

  _HomeData({
    required this.trackers,
    required this.history,
    required this.taskHistory,
    required this.groups,
    required this.tasks,
  });
}
