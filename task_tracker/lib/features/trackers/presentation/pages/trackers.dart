import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/core/widgets/page_header.dart';
import 'package:task_tracker/features/tasks/presentation/providers/task_providers.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/presentation/providers/tracker_providers.dart';
import 'package:task_tracker/features/trackers/presentation/widgets/add_tracker_dialog.dart';
import 'package:task_tracker/features/trackers/presentation/widgets/tracker_card.dart';

class TrackersPage extends ConsumerWidget {
  const TrackersPage({super.key});

  void _showAddTrackerDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddTrackerDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = ref.watch(userIdProvider);
    final activeFilter = ref.watch(trackerFilterProvider);
    final filteredTrackersAsync = ref.watch(filteredTrackersProvider);

    // Auto-reset check side-effect for maintain trackers via reactive listener
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

    if (userId == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              header: 'Trackers',
              sub: 'Monitor and build your habit streaks',
              action: ElevatedButton.icon(
                onPressed: () => _showAddTrackerDialog(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Add Tracker',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Choice chips for filtering
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All Trackers'),
                  selected: activeFilter == 'all',
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(trackerFilterProvider.notifier).state = 'all';
                    }
                  },
                  selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: activeFilter == 'all'
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Maintaining'),
                  selected: activeFilter == 'maintain',
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(trackerFilterProvider.notifier).state =
                          'maintain';
                    }
                  },
                  selectedColor: colorScheme.tertiary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: activeFilter == 'maintain'
                        ? colorScheme.tertiary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Quitting'),
                  selected: activeFilter == 'quit',
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(trackerFilterProvider.notifier).state = 'quit';
                    }
                  },
                  selectedColor: colorScheme.error.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: activeFilter == 'quit'
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Trackers Content via AsyncValue
            filteredTrackersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Error loading trackers: $error',
                  style: TextStyle(color: colorScheme.error, fontSize: 16),
                ),
              ),
              data: (filteredTrackers) {
                if (filteredTrackers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.track_changes_outlined,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          activeFilter == 'all'
                              ? 'No habit trackers created yet'
                              : activeFilter == 'maintain'
                              ? 'No habits to maintain yet'
                              : 'No habits to quit yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Add Tracker" in the top right to start tracking!',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Responsive layout
                final width = MediaQuery.of(context).size.width;
                if (width >= 850) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 8,
                          mainAxisExtent: 265,
                        ),
                    itemCount: filteredTrackers.length,
                    itemBuilder: (context, index) {
                      return TrackerCard(tracker: filteredTrackers[index]);
                    },
                  );
                } else {
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredTrackers.length,
                    itemBuilder: (context, index) {
                      return TrackerCard(tracker: filteredTrackers[index]);
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
