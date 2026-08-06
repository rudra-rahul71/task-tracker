import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/repositories/tracker_repository.dart';
import 'package:task_tracker/features/trackers/presentation/widgets/add_tracker_dialog.dart';

class TrackerCard extends StatelessWidget {
  final TrackerModel tracker;
  final TrackerRepository _repository = GetIt.instance<TrackerRepository>();

  TrackerCard({super.key, required this.tracker});

  void _showDeleteDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Delete Tracker',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${tracker.name}"?',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _repository.deleteTracker(tracker.userId, tracker.id);
                if (context.mounted) {
                  AppBannerService.showSuccess(
                    context,
                    'Tracker deleted successfully',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AppBannerService.showError(
                    context,
                    'Error deleting tracker: $e',
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isQuit = tracker.type == 'quit';
    final isSetTime = tracker.durationType == 'set_time';

    final accentColor = isQuit ? colorScheme.error : colorScheme.tertiary;

    final formattedText = tracker.getFormattedDuration();
    final progress = tracker.getProgress();

    final singularUnit = tracker.measurementUnit == 'days'
        ? 'day'
        : tracker.measurementUnit == 'weeks'
        ? 'week'
        : tracker.measurementUnit == 'months'
        ? 'month'
        : 'period';

    final showTimeLeft = !isQuit && !isSetTime;
    final displayProgress = showTimeLeft ? (1.0 - progress) : progress;

    final currentPeriod = tracker.getCurrentPeriodIndex(DateTime.now());
    final isCompletedForPeriod = tracker.isPeriodCompleted(currentPeriod);
    final periodName = (singularUnit == 'day' || singularUnit == 'days')
        ? 'today'
        : 'this $singularUnit';

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withValues(alpha: 0.3), width: 1.5),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Info and Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isQuit
                              ? Icons.block_flipped
                              : Icons.check_circle_outline_rounded,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tracker.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _buildBadge(
                                  isQuit ? 'Quitting' : 'Maintaining',
                                  accentColor.withValues(alpha: 0.15),
                                  accentColor,
                                ),
                                _buildBadge(
                                  isSetTime
                                      ? 'Set Time (${tracker.durationValue} ${tracker.measurementUnit})'
                                      : 'Indefinite',
                                  colorScheme.onSurface.withValues(alpha: 0.06),
                                  colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                      tooltip: 'Edit tracker',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) =>
                              AddTrackerDialog(trackerToEdit: tracker),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: colorScheme.error,
                        size: 22,
                      ),
                      tooltip: 'Delete tracker',
                      onPressed: () => _showDeleteDialog(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Middle Row: Counter Display
            Center(
              child: Column(
                children: [
                  Text(
                    formattedText,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: displayProgress,
                minHeight: 6,
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSetTime
                      ? '${(displayProgress * 100).toStringAsFixed(0)}% completed'
                      : showTimeLeft
                      ? '${(displayProgress * 100).toStringAsFixed(0)}% of current $singularUnit left'
                      : '${(displayProgress * 100).toStringAsFixed(0)}% of current $singularUnit completed',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isSetTime)
                  Text(
                    'Target: ${tracker.durationValue} ${tracker.measurementUnit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (!isQuit) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: isCompletedForPeriod
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.check, color: colorScheme.tertiary),
                        label: Text(
                          'Completed for $periodName',
                          style: TextStyle(
                            color: colorScheme.tertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colorScheme.tertiary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await _repository.markTrackerCompleted(tracker);
                            if (context.mounted) {
                              AppBannerService.showSuccess(
                                context,
                                'Habit marked completed!',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppBannerService.showError(
                                context,
                                'Error marking completed: $e',
                              );
                            }
                          }
                        },
                        icon: Icon(
                          Icons.check_circle_outline,
                          color: colorScheme.onTertiary,
                        ),
                        label: Text(
                          'Mark Completed for $periodName',
                          style: TextStyle(
                            color: colorScheme.onTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
            ],
            if (isQuit) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await _repository.reportSlipUp(tracker);
                      if (context.mounted) {
                        AppBannerService.showSuccess(
                          context,
                          'Streak reset. Stay strong, you can do this!',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppBannerService.showError(
                          context,
                          'Error reporting slip-up: $e',
                        );
                      }
                    }
                  },
                  icon: Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.onError,
                  ),
                  label: Text(
                    'Report Slip-Up (Reset Streak)',
                    style: TextStyle(
                      color: colorScheme.onError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
