import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker/core/widgets/page_header.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/repositories/tracker_repository.dart';
import 'package:task_tracker/features/trackers/data/models/tracker_history.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/task_card.dart';
import 'package:task_tracker/features/tasks/data/models/task_history.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TrackerRepository _repository = TrackerRepository();
  final TaskRepository _taskRepository = TaskRepository();
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _currentUserId;
  Stream<List<TrackerModel>>? _trackersStream;
  Stream<List<TrackerHistoryModel>>? _historyStream;
  Stream<List<TaskModel>>? _tasksStream;
  Stream<List<TaskGroupModel>>? _groupsStream;
  Stream<List<TaskHistoryModel>>? _taskHistoryStream;
  DateTime? _cachedFocusedMonth;
  String? _historyStreamUserId;

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final List<String> _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  void _initStreamsForUser(String userId) {
    if (_currentUserId == userId &&
        _trackersStream != null &&
        _tasksStream != null &&
        _groupsStream != null) {
      return;
    }
    _currentUserId = userId;
    _trackersStream = _repository.getTrackers(userId);
    _tasksStream = _taskRepository.getTasks(userId);
    _groupsStream = _taskRepository.getGroups(userId);
  }

  bool _isTaskDueOnDate(TaskModel task, List<TaskGroupModel> groups, DateTime date) {
    // A task cannot be due before its creation date
    final dateZero = DateTime(date.year, date.month, date.day);
    final createdZero = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
    if (dateZero.isBefore(createdZero)) {
      return false;
    }

    // 1. Task has its own schedule
    if (task.schedule != null && task.schedule!.type != 'none') {
      return task.schedule!.isDueOnDate(date);
    }

    // 2. Task inherits its group schedule
    if (task.groupId != null) {
      final group = groups.firstWhere(
        (g) => g.id == task.groupId,
        orElse: () => TaskGroupModel(
          id: '',
          userId: '',
          name: '',
          colorValue: 0xFF9E9E9E,
          createdAt: DateTime.now(),
        ),
      );
      if (group.id.isNotEmpty && group.schedule != null && group.schedule!.type != 'none') {
        return group.schedule!.isDueOnDate(date);
      }
    }

    // 3. Unscheduled tasks: show under "Due Today" if they are pending (so they don't get lost)
    // For the calendar, we only display unscheduled pending tasks on today's date.
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    return isToday && task.status == 'pending';
  }

  bool _isTaskCompletedOnDate(TaskModel task, List<TaskHistoryModel> taskHistory, DateTime date) {
    return taskHistory.any((h) =>
        h.taskId == task.id &&
        h.date.year == date.year &&
        h.date.month == date.month &&
        h.date.day == date.day);
  }

  void _initHistoryStream(String userId, DateTime focusedMonth) {
    if (_historyStreamUserId == userId &&
        _historyStream != null &&
        _taskHistoryStream != null &&
        _cachedFocusedMonth != null &&
        _cachedFocusedMonth!.year == focusedMonth.year &&
        _cachedFocusedMonth!.month == focusedMonth.month) {
      return;
    }
    _historyStreamUserId = userId;
    _cachedFocusedMonth = focusedMonth;
    _historyStream = _repository.getMonthlyHistory(userId, focusedMonth);
    _taskHistoryStream = _taskRepository.getMonthlyTaskHistory(userId, focusedMonth);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    _initStreamsForUser(userId);
    _initHistoryStream(userId, _focusedMonth);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<TrackerModel>>(
        stream: _trackersStream!,
        builder: (context, trackersSnapshot) {
          if (trackersSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (trackersSnapshot.hasError) {
            return Center(
              child: Text(
                'Error loading trackers: ${trackersSnapshot.error}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            );
          }

          final trackers = trackersSnapshot.data ?? [];

          return StreamBuilder<List<TrackerHistoryModel>>(
            stream: _historyStream!,
            builder: (context, historySnapshot) {
              if (historySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (historySnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading monthly history: ${historySnapshot.error}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              final history = historySnapshot.data ?? [];

              return StreamBuilder<List<TaskHistoryModel>>(
                stream: _taskHistoryStream!,
                builder: (context, taskHistorySnapshot) {
                  if (taskHistorySnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (taskHistorySnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading task history: ${taskHistorySnapshot.error}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  final taskHistory = taskHistorySnapshot.data ?? [];

                  return StreamBuilder<List<TaskGroupModel>>(
                    stream: _groupsStream!,
                    builder: (context, groupsSnapshot) {
                      if (groupsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (groupsSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading task groups: ${groupsSnapshot.error}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      final groups = groupsSnapshot.data ?? [];

                      return StreamBuilder<List<TaskModel>>(
                        stream: _tasksStream!,
                        builder: (context, tasksSnapshot) {
                          if (tasksSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (tasksSnapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading tasks: ${tasksSnapshot.error}',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          }

                          final tasks = tasksSnapshot.data ?? [];

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

                          // Helper methods for daily status checking using monthly history
                          bool hasTrackerSlipUpOnDay(
                            TrackerModel tracker,
                            DateTime dayDate,
                          ) {
                            if (tracker.type != 'quit') return false;
                            return history.any(
                              (h) =>
                                  h.trackerId == tracker.id &&
                                  h.type == 'slip_up' &&
                                  h.date.year == dayDate.year &&
                                  h.date.month == dayDate.month &&
                                  h.date.day == dayDate.day,
                            );
                          }

                          bool isTrackerCompletedOnDay(
                            TrackerModel tracker,
                            DateTime dayDate,
                          ) {
                            final dayZero = DateTime(
                              dayDate.year,
                              dayDate.month,
                              dayDate.day,
                            );
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

                            if (dayZero.isBefore(originalStartZero) ||
                                dayZero.isAfter(todayZero)) {
                              return false;
                            }

                            if (tracker.type == 'maintain') {
                              final hasManualCompletion = history.any(
                                (h) =>
                                    h.trackerId == tracker.id &&
                                    h.type == 'completion' &&
                                    h.date.year == dayDate.year &&
                                    h.date.month == dayDate.month &&
                                    h.date.day == dayDate.day,
                              );
                              if (hasManualCompletion) return true;

                              // Assume completed properly if it is in the past before the tracker was created
                              final createdZero = DateTime(
                                tracker.createdAt.year,
                                tracker.createdAt.month,
                                tracker.createdAt.day,
                              );
                              if (dayZero.isBefore(todayZero) &&
                                  dayZero.isBefore(createdZero)) {
                                return true;
                              }

                              // Assume completed properly if it is part of the current active streak
                              final currentStartZero = DateTime(
                                tracker.startDate.year,
                                tracker.startDate.month,
                                tracker.startDate.day,
                              );
                              if (dayZero.isBefore(todayZero) &&
                                  !dayZero.isBefore(currentStartZero)) {
                                return true;
                              }

                              return false;
                            } else {
                              return !hasTrackerSlipUpOnDay(tracker, dayDate);
                            }
                          }

                          // Compute values for calendar grid
                          final year = _focusedMonth.year;
                          final month = _focusedMonth.month;
                          final firstDay = DateTime(year, month, 1);
                          final emptySlots = firstDay.weekday % 7; // Sunday is index 0
                          final daysInMonth = DateTime(year, month + 1, 0).day;
                          final totalCells = emptySlots + daysInMonth;

                          // Look up completions and slip-ups for the currently selected day
                          final completedOnSelected = trackers.where((tracker) {
                            return isTrackerCompletedOnDay(tracker, _selectedDay);
                          }).toList();

                          final slippedOnSelected = trackers.where((tracker) {
                            return hasTrackerSlipUpOnDay(tracker, _selectedDay);
                          }).toList();

                          // Look up tasks completed or pending on the currently selected day using history
                          final completedTasksOnSelected = tasks.where((task) {
                            return _isTaskCompletedOnDate(task, taskHistory, _selectedDay);
                          }).toList();

                          final pendingTasksOnSelected = tasks.where((task) {
                            final isDue = _isTaskDueOnDate(task, groups, _selectedDay);
                            final isCompleted = _isTaskCompletedOnDate(task, taskHistory, _selectedDay);
                            return isDue && !isCompleted;
                          }).toList();

                          final width = MediaQuery.of(context).size.width;
                          final isLargeScreen = width >= 850;

                          // Main Layout
                          final mainContent = Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const PageHeader(
                                  header: 'Dashboard',
                                  sub: 'Visualize your habits and tasks history',
                                ),
                                const SizedBox(height: 24),
                                Expanded(
                                  child: isLargeScreen
                                      ? Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: _buildDetailPanel(
                                                completedTrackers: completedOnSelected,
                                                slippedTrackers: slippedOnSelected,
                                                completedTasks: completedTasksOnSelected,
                                                pendingTasks: pendingTasksOnSelected,
                                                groups: groups,
                                                isScrollable: true,
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(
                                              flex: 4,
                                              child: _buildCalendarCard(
                                                emptySlots: emptySlots,
                                                daysInMonth: daysInMonth,
                                                totalCells: totalCells,
                                                trackers: trackers,
                                                history: history,
                                                tasks: tasks,
                                                groups: groups,
                                                taskHistory: taskHistory,
                                              ),
                                            ),
                                          ],
                                        )
                                      : SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildDetailPanel(
                                                completedTrackers: completedOnSelected,
                                                slippedTrackers: slippedOnSelected,
                                                completedTasks: completedTasksOnSelected,
                                                pendingTasks: pendingTasksOnSelected,
                                                groups: groups,
                                                isScrollable: false,
                                              ),
                                              const SizedBox(height: 24),
                                              _buildCalendarCard(
                                                emptySlots: emptySlots,
                                                daysInMonth: daysInMonth,
                                                totalCells: totalCells,
                                                trackers: trackers,
                                                history: history,
                                                tasks: tasks,
                                                groups: groups,
                                                taskHistory: taskHistory,
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          );

                          return isLargeScreen
                              ? mainContent
                              : Scaffold(
                                  backgroundColor: Colors.transparent,
                                  body: mainContent,
                                );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Build Calendar UI Card
  Widget _buildCalendarCard({
    required int emptySlots,
    required int daysInMonth,
    required int totalCells,
    required List<TrackerModel> trackers,
    required List<TrackerHistoryModel> history,
    required List<TaskModel> tasks,
    required List<TaskGroupModel> groups,
    required List<TaskHistoryModel> taskHistory,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final useTextBanners = cardWidth >= 520;
        final cellAspectRatio = useTextBanners ? 0.95 : 0.72;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          color: const Color(0xFF1E1E1E),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Calendar Header Month / Year & Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month - 1,
                        );
                      });
                    },
                  ),
                  Text(
                    '${_months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month + 1,
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Weekday Grid Labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _weekdays.map((w) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              // Days Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: cellAspectRatio,
                ),
                itemCount: totalCells,
                itemBuilder: (context, index) {
                  if (index < emptySlots) {
                    return const SizedBox.shrink();
                  }

                  final dayNum = index - emptySlots + 1;
                  final dayDate = DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month,
                    dayNum,
                  );

                  final isSelected =
                      _selectedDay.year == dayDate.year &&
                      _selectedDay.month == dayDate.month &&
                      _selectedDay.day == dayDate.day;

                  final today = DateTime.now();
                  final isToday =
                      today.year == dayDate.year &&
                      today.month == dayDate.month &&
                      today.day == dayDate.day;

                  bool hasTrackerSlipUpOnDay(
                    TrackerModel tracker,
                    DateTime date,
                  ) {
                    if (tracker.type != 'quit') return false;
                    return history.any(
                      (h) =>
                          h.trackerId == tracker.id &&
                          h.type == 'slip_up' &&
                          h.date.year == date.year &&
                          h.date.month == date.month &&
                          h.date.day == date.day,
                    );
                  }

                  bool isTrackerCompletedOnDay(
                    TrackerModel tracker,
                    DateTime date,
                  ) {
                    final dayZero = DateTime(date.year, date.month, date.day);
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

                    if (dayZero.isBefore(originalStartZero) ||
                        dayZero.isAfter(todayZero)) {
                      return false;
                    }

                    if (tracker.type == 'maintain') {
                      final hasManualCompletion = history.any(
                        (h) =>
                            h.trackerId == tracker.id &&
                            h.type == 'completion' &&
                            h.date.year == date.year &&
                            h.date.month == date.month &&
                            h.date.day == date.day,
                      );
                      if (hasManualCompletion) return true;

                      // Assume completed properly if it is in the past before the tracker was created
                      final createdZero = DateTime(
                        tracker.createdAt.year,
                        tracker.createdAt.month,
                        tracker.createdAt.day,
                      );
                      if (dayZero.isBefore(todayZero) &&
                          dayZero.isBefore(createdZero)) {
                        return true;
                      }

                      // Assume completed properly if it is part of the current active streak
                      final currentStartZero = DateTime(
                        tracker.startDate.year,
                        tracker.startDate.month,
                        tracker.startDate.day,
                      );
                      if (dayZero.isBefore(todayZero) &&
                          !dayZero.isBefore(currentStartZero)) {
                        return true;
                      }

                      return false;
                    } else {
                      return !hasTrackerSlipUpOnDay(tracker, date);
                    }
                  }

                  final completedForDay = trackers
                      .where((t) => isTrackerCompletedOnDay(t, dayDate))
                      .toList();

                  final allIndicators = [
                    ...completedForDay.map((t) {
                      return t.type == 'quit'
                          ? const Color(
                              0xFFEF5350,
                            ) // Red dot matching quit habits
                          : const Color(
                              0xFF26A69A,
                            ); // Teal dot matching maintain habits
                    }),
                  ];

                  // Look up tasks completed or pending on this day using history
                  final tasksOnDay = tasks.where((t) {
                    return _isTaskDueOnDate(t, groups, dayDate) ||
                        _isTaskCompletedOnDate(t, taskHistory, dayDate);
                  }).toList();

                  final List<Widget> taskBanners = [];
                  final List<Widget> taskIndicators = [];

                  if (tasksOnDay.isNotEmpty) {
                    if (useTextBanners) {
                      final displayLimit = 2;
                      final showMore = tasksOnDay.length > displayLimit;
                      final count = showMore ? displayLimit - 1 : tasksOnDay.length;

                      for (int i = 0; i < count; i++) {
                        final t = tasksOnDay[i];
                        final isCompleted = _isTaskCompletedOnDate(t, taskHistory, dayDate);
                        final group = t.groupId != null
                            ? groups.firstWhere(
                                (g) => g.id == t.groupId,
                                orElse: () => TaskGroupModel(
                                  id: '',
                                  userId: '',
                                  name: '',
                                  colorValue: 0xFF9E9E9E,
                                  createdAt: DateTime.now(),
                                ),
                              )
                            : null;
                        final color = group != null && group.id.isNotEmpty
                            ? Color(group.colorValue)
                            : Theme.of(context).colorScheme.primary;

                        final isLightColor =
                            ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.light;
                        final textColor = isCompleted
                            ? (isLightColor ? Colors.black87 : Colors.white70)
                            : (isLightColor ? color.withValues(alpha: 0.9) : color);

                        taskBanners.add(
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(
                              vertical: 1.0,
                              horizontal: 2.0,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? color.withValues(alpha: 0.85)
                                  : color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: isCompleted
                                  ? null
                                  : Border.all(
                                      color: color.withValues(alpha: 0.5),
                                      width: 0.8,
                                    ),
                            ),
                            child: Text(
                              t.name,
                              style: TextStyle(
                                fontSize: 8.0,
                                fontWeight: FontWeight.bold,
                                color: isCompleted
                                    ? (isLightColor ? Colors.black : Colors.white)
                                    : textColor,
                                decoration:
                                    isCompleted ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (showMore) {
                        final remainingCount = tasksOnDay.length - count;
                        taskBanners.add(
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(
                              vertical: 1.0,
                              horizontal: 2.0,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+$remainingCount more',
                              style: const TextStyle(
                                fontSize: 7.5,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                    } else {
                      // Render mini banners for tasks on mobile layout
                      for (final t in tasksOnDay) {
                        final isCompleted = _isTaskCompletedOnDate(t, taskHistory, dayDate);
                        final group = t.groupId != null
                            ? groups.firstWhere(
                                (g) => g.id == t.groupId,
                                orElse: () => TaskGroupModel(
                                  id: '',
                                  userId: '',
                                  name: '',
                                  colorValue: 0xFF9E9E9E,
                                  createdAt: DateTime.now(),
                                ),
                              )
                            : null;
                        final color = group != null && group.id.isNotEmpty
                            ? Color(group.colorValue)
                            : Theme.of(context).colorScheme.primary;

                        taskIndicators.add(
                          Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 1.0,
                              horizontal: 3.0,
                            ),
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isCompleted ? color : Colors.transparent,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: color.withValues(alpha: isCompleted ? 1.0 : 0.6),
                                width: 1.0,
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = dayDate;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.25)
                            : isToday
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : isToday
                              ? Colors.grey
                              : Colors.white.withValues(alpha: 0.05),
                          width: isSelected || isToday ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                '$dayNum',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white,
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (useTextBanners)
                              Positioned.fill(
                                top: 18,
                                bottom: 10,
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: taskBanners,
                                ),
                              ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!useTextBanners && taskIndicators.isNotEmpty) ...[
                                    Column(
                                      children: taskIndicators.take(2).toList(),
                                    ),
                                    const SizedBox(height: 3),
                                  ],
                                  if (allIndicators.isNotEmpty)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: allIndicators.take(4).map((color) {
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 1.0,
                                          ),
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  },
);
}

  // Build Details Panel Card (Completed / Pending trackers for selected day)
  Widget _buildDetailPanel({
    required List<TrackerModel> completedTrackers,
    required List<TrackerModel> slippedTrackers,
    required List<TaskModel> completedTasks,
    required List<TaskModel> pendingTasks,
    required List<TaskGroupModel> groups,
    required bool isScrollable,
  }) {
    final formattedDate =
        '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}';

    final today = DateTime.now();
    final isSelectedDayToday = _selectedDay.year == today.year &&
        _selectedDay.month == today.month &&
        _selectedDay.day == today.day;

    final listWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- TASKS SECTION ---
        const Text(
          'TODAY\'S TASKS',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        if (pendingTasks.isEmpty && completedTasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.assignment_outlined, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No tasks scheduled or completed on this day.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (pendingTasks.isNotEmpty) ...[
            const Text(
              'PENDING',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...pendingTasks.map((task) {
              final taskForCard = isSelectedDayToday
                  ? task
                  : task.copyWith(
                      status: 'pending',
                      steps: task.steps
                          .map((s) => s.copyWith(
                                isCompleted: false,
                                clearTimerStartedAt: true,
                                clearTimerPausedAt: true,
                                timerSecondsRemaining: s.timerDuration,
                                isTimerConfirmed: false,
                              ))
                          .toList(),
                    );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TaskCard(
                  task: taskForCard,
                  groups: groups,
                  repository: _taskRepository,
                  isInteractive: isSelectedDayToday,
                  showCompletionStatus: true,
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
          if (completedTasks.isNotEmpty) ...[
            const Text(
              'COMPLETED',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...completedTasks.map((task) {
              final taskForCard = isSelectedDayToday
                  ? task
                  : task.copyWith(
                      status: 'completed',
                      steps: task.steps.map((s) => s.copyWith(isCompleted: true)).toList(),
                    );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TaskCard(
                  task: taskForCard,
                  groups: groups,
                  repository: _taskRepository,
                  isInteractive: isSelectedDayToday,
                  showCompletionStatus: true,
                ),
              );
            }),
          ],
        ],

        const Divider(height: 32, thickness: 1, color: Colors.white10),

        // --- HABIT TRACKERS SECTION ---
        const Text(
          'SUCCESSFUL HABITS / CLEAN DAYS',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        if (completedTrackers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No habits completed or clean on this day.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
          )
        else
          ...completedTrackers.map((t) => _buildDetailItem(t, true)),

        if (slippedTrackers.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'SLIPPED UP / BROKEN HABITS',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ...slippedTrackers.map((t) => _buildDetailItem(t, false, isSlip: true)),
        ],
      ],
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Habits & tasks completion details',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const Divider(height: 32, thickness: 1, color: Colors.white10),

            if (isScrollable)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: listWidget,
                ),
              )
            else
              listWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    TrackerModel tracker,
    bool isCompleted, {
    bool isSlip = false,
  }) {
    final color = tracker.type == 'quit'
        ? const Color(0xFFEF5350)
        : const Color(0xFF26A69A);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSlip
              ? const Color(0xFFEF5350).withValues(alpha: 0.3)
              : isCompleted
              ? color.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isSlip
                      ? Icons.cancel_outlined
                      : isCompleted
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: isSlip
                      ? const Color(0xFFEF5350)
                      : isCompleted
                      ? color
                      : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tracker.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tracker.type == 'quit'
                  ? const Color(0xFFEF5350).withValues(alpha: 0.1)
                  : const Color(0xFF26A69A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tracker.type == 'quit' ? 'Quit' : 'Maintain',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
