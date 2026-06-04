import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';

void main() {
  group('TrackerModel Tests', () {
    test('Maintain Tracker - Completion and Slip-up detection', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      // Create a maintain tracker created 2 days ago
      final tracker = TrackerModel(
        id: 't1',
        userId: 'u1',
        name: 'Exercise',
        type: 'maintain',
        durationType: 'indefinite',
        measurementUnit: 'days',
        startDate: twoDaysAgo,
        originalStartDate: twoDaysAgo,
        createdAt: twoDaysAgo,
        completedDates: [
          twoDaysAgo,
        ], // Completed two days ago, but missed yesterday
      );

      // 1. Two days ago: should be completed, not a slip-up
      expect(tracker.isCompletedOnDay(twoDaysAgo), isTrue);
      expect(tracker.hasSlipUpOnDay(twoDaysAgo), isFalse);

      // 2. Yesterday: missed/not completed, should detect as a slip-up
      // Since it missed yesterday, getNewStartDateIfResetNeeded(today) should return today,
      // which shifts the active streak to start today.
      expect(tracker.isCompletedOnDay(yesterday), isFalse);
      expect(tracker.hasSlipUpOnDay(yesterday), isTrue);

      // 3. Today: not completed yet (still has time), so not a slip-up
      expect(tracker.isCompletedOnDay(today), isFalse);
      expect(tracker.hasSlipUpOnDay(today), isFalse);
    });

    test('Quit Tracker - Completion and Slip-up detection', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      // Create a quit tracker (bad habit) created 2 days ago
      final tracker = TrackerModel(
        id: 't2',
        userId: 'u1',
        name: 'Smoking',
        type: 'quit',
        durationType: 'indefinite',
        measurementUnit: 'days',
        startDate: twoDaysAgo,
        originalStartDate: twoDaysAgo,
        createdAt: twoDaysAgo,
        completedDates: [yesterday], // Slipped up yesterday
      );

      // 1. Two days ago: no slip up recorded, so completed (clean)
      expect(tracker.isCompletedOnDay(twoDaysAgo), isTrue);
      expect(tracker.hasSlipUpOnDay(twoDaysAgo), isFalse);

      // 2. Yesterday: slipped up
      expect(tracker.isCompletedOnDay(yesterday), isFalse);
      expect(tracker.hasSlipUpOnDay(yesterday), isTrue);

      // 3. Today: no slip up recorded yet
      expect(tracker.isCompletedOnDay(today), isTrue);
      expect(tracker.hasSlipUpOnDay(today), isFalse);
    });
  });
}
