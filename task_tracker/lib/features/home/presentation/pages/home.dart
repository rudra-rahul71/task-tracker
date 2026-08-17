import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/core/widgets/page_header.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/presentation/providers/task_providers.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/presentation/providers/tracker_providers.dart';
import 'package:task_tracker/features/home/presentation/providers/home_providers.dart';
import 'package:task_tracker/features/home/presentation/widgets/calendar_widget.dart';
import 'package:task_tracker/features/home/presentation/widgets/daily_details_widget.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = ref.watch(userIdProvider);
    final focusedMonth = ref.watch(focusedMonthProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    final calendarEventsAsync = ref.watch(calendarEventsProvider);
    final dayDetailsAsync = ref.watch(dayDetailsProvider);
    final groupsAsync = ref.watch(taskGroupsProvider);
    final taskRepo = ref.read(taskRepositoryProvider);

    // Auto-reset check side-effect for maintain trackers
    ref.listen<AsyncValue<List<TrackerModel>>>(trackersStreamProvider, (
      prev,
      next,
    ) {
      next.whenData((trackers) {
        if (trackers.isNotEmpty) {
          final now = DateTime.now();
          for (final tracker in trackers) {
            final newStart = tracker.getNewStartDateIfResetNeeded(now);
            if (newStart != null) {
              ref
                  .read(trackerRepositoryProvider)
                  .autoResetTracker(tracker, newStart);
            }
          }
        }
      });
    });

    // Auto-schedule check side-effect for scheduled tasks
    ref.listen<AsyncValue<List<TaskModel>>>(tasksStreamProvider, (prev, next) {
      next.whenData((tasks) {
        final groups = groupsAsync.value ?? [];
        if (userId != null && tasks.isNotEmpty) {
          ref.read(taskRepositoryProvider).checkAndResetScheduledTasks(
            userId: userId,
            tasks: tasks,
            groups: groups,
          );
        }
      });
    });

    if (userId == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= 850;

    final calendarEvents =
        calendarEventsAsync.value ?? const <String, CalendarDayData>{};

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

        final dailyDetailsCard = dayDetailsAsync.when(
          loading: () => Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1.5,
              ),
            ),
            color: colorScheme.surface,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) => Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.error.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            color: colorScheme.surface,
            child: Center(
              child: Text(
                'Error loading details: $err',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ),
          data: (details) => DailyDetailsWidget(
            selectedDay: selectedDay,
            completedTrackers: details.completedTrackers,
            slippedTrackers: details.slippedTrackers,
            completedTasks: details.completedTasks,
            pendingTasks: details.pendingTasks,
            groups: details.groups,
            isScrollable: isLargeScreen,
            taskRepository: taskRepo,
          ),
        );

        final calendarCard = CalendarWidget(
          focusedMonth: focusedMonth,
          selectedDay: selectedDay,
          eventsMap: calendarEvents,
          onMonthChanged: (month) {
            ref.read(focusedMonthProvider.notifier).state = month;
          },
          onDaySelected: (day) {
            ref.read(selectedDayProvider.notifier).state = day;
          },
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
                            Expanded(flex: 3, child: dailyDetailsCard),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: calendarCard),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          dailyDetailsCard,
                          const SizedBox(height: 24),
                          calendarCard,
                        ],
                      ),
              ],
            ),
          ),
        );
      },
    );

    final isWaiting =
        calendarEventsAsync.isLoading || dayDetailsAsync.isLoading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          mainContent,
          if (isWaiting && calendarEventsAsync.value == null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
