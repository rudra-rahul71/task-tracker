import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker/core/widgets/page_header.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/repositories/tracker_repository.dart';
import 'package:task_tracker/features/trackers/data/models/tracker_history.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TrackerRepository _repository = TrackerRepository();
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _currentUserId;
  Stream<List<TrackerModel>>? _trackersStream;

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
    if (_currentUserId == userId && _trackersStream != null) {
      return;
    }
    _currentUserId = userId;
    _trackersStream = _repository.getTrackers(userId);
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
            stream: _repository.getMonthlyHistory(userId, _focusedMonth),
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
                      sub: 'Visualize your habit completion history',
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: isLargeScreen
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _buildCalendarCard(
                                    emptySlots: emptySlots,
                                    daysInMonth: daysInMonth,
                                    totalCells: totalCells,
                                    trackers: trackers,
                                    history: history,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 3,
                                  child: _buildDetailPanel(
                                    completed: completedOnSelected,
                                    slipped: slippedOnSelected,
                                    isScrollable: true,
                                  ),
                                ),
                              ],
                            )
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCalendarCard(
                                    emptySlots: emptySlots,
                                    daysInMonth: daysInMonth,
                                    totalCells: totalCells,
                                    trackers: trackers,
                                    history: history,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildDetailPanel(
                                    completed: completedOnSelected,
                                    slipped: slippedOnSelected,
                                    isScrollable: false,
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
  }) {
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.0,
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
                            ) // Red dot matching quit cards
                          : const Color(
                              0xFF26A69A,
                            ); // Teal dot matching maintain cards
                    }),
                  ];

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
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white,
                                fontWeight: isSelected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            if (allIndicators.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: allIndicators.take(4).map((color) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1.0,
                                    ),
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
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
  }

  // Build Details Panel Card (Completed / Pending trackers for selected day)
  Widget _buildDetailPanel({
    required List<TrackerModel> completed,
    required List<TrackerModel> slipped,
    required bool isScrollable,
  }) {
    final formattedDate =
        '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}';

    final listWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Completions List
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
        if (completed.isEmpty)
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
          ...completed.map((t) => _buildDetailItem(t, true)),

        if (slipped.isNotEmpty) ...[
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
          ...slipped.map((t) => _buildDetailItem(t, false, isSlip: true)),
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
              'Habit completions details',
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
