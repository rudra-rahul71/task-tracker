import 'package:flutter/material.dart';
import 'package:task_tracker/core/utils/snackbar.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/repositories/tracker_repository.dart';

class TrackerCard extends StatelessWidget {
  final TrackerModel tracker;
  final TrackerRepository _repository = TrackerRepository();

  TrackerCard({super.key, required this.tracker});

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete Tracker',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${tracker.name}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _repository.deleteTracker(tracker.userId, tracker.id);
                if (context.mounted) {
                  SnackbarService(context).showSuccessSnackbar(
                    message: 'Tracker deleted successfully',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarService(context).showErrorSnackbar(
                    message: 'Error deleting tracker: $e',
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

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Reset Progress',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          tracker.type == 'quit'
              ? 'Did you slip up? Resetting will restart your clean streak from now.'
              : 'Are you sure you want to restart this tracker from now?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _repository.resetTracker(tracker);
                if (context.mounted) {
                  SnackbarService(context).showSuccessSnackbar(
                    message: 'Tracker reset successfully',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarService(context).showErrorSnackbar(
                    message: 'Error resetting tracker: $e',
                  );
                }
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isQuit = tracker.type == 'quit';
    final isSetTime = tracker.durationType == 'set_time';

    final accentColor = isQuit
        ? const Color(0xFFEF5350) // Premium crimson red for quitting
        : const Color(0xFF26A69A); // Premium teal emerald for maintaining

    final formattedText = tracker.getFormattedDuration();
    final progress = tracker.getProgress();

    final singularUnit = tracker.measurementUnit == 'days'
        ? 'day'
        : tracker.measurementUnit == 'weeks'
            ? 'week'
            : tracker.measurementUnit == 'months'
                ? 'month'
                : tracker.measurementUnit == 'hours'
                    ? 'hour'
                    : tracker.measurementUnit == 'minutes'
                        ? 'minute'
                        : 'period';

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      color: const Color(0xFF1E1E1E),
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
                          isQuit ? Icons.block_flipped : Icons.check_circle_outline_rounded,
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
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                                  Colors.white.withValues(alpha: 0.06),
                                  Colors.grey[400]!,
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
                      icon: const Icon(Icons.refresh, color: Colors.amber, size: 22),
                      tooltip: 'Reset timer to now',
                      onPressed: () => _showResetDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF5350), size: 22),
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
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSetTime
                      ? '${(progress * 100).toStringAsFixed(0)}% completed'
                      : '${(progress * 100).toStringAsFixed(0)}% of current $singularUnit completed',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                if (isSetTime)
                  Text(
                    'Target: ${tracker.durationValue} ${tracker.measurementUnit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
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
