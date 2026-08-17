import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker/features/home/presentation/providers/home_providers.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_schedule.dart';
import 'package:task_tracker/features/tasks/data/models/task_history.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/models/tracker_history.dart';

void main() {
  group('CalendarCalculationUtils Tests', () {
    final tracker = TrackerModel(
      id: 'tracker-1',
      userId: 'user-1',
      name: 'Meditation',
      type: 'maintain',
      durationType: 'indefinite',
      measurementUnit: 'days',
      durationValue: null,
      startDate: DateTime(2026, 8, 1),
      originalStartDate: DateTime(2026, 8, 1),
      createdAt: DateTime(2026, 8, 1),
    );

    test('isTrackerCompletedOnDay - detects manual completion in history', () {
      final trackerHistoryMap = {
        'tracker-1_2026-8-15': {'completion'},
      };

      final completed = CalendarCalculationUtils.isTrackerCompletedOnDay(
        tracker,
        DateTime(2026, 8, 15),
        '2026-8-15',
        trackerHistoryMap,
      );

      expect(completed, isTrue);
    });

    test('hasTrackerSlipUpOnDay - detects slip up for quit tracker', () {
      final quitTracker = TrackerModel(
        id: 'tracker-quit',
        userId: 'user-1',
        name: 'No Sugar',
        type: 'quit',
        durationType: 'indefinite',
        measurementUnit: 'days',
        durationValue: null,
        startDate: DateTime(2026, 8, 1),
        originalStartDate: DateTime(2026, 8, 1),
        createdAt: DateTime(2026, 8, 1),
      );

      final trackerHistoryMap = {
        'tracker-quit_2026-8-12': {'slip_up'},
      };

      final slipped = CalendarCalculationUtils.hasTrackerSlipUpOnDay(
        quitTracker,
        DateTime(2026, 8, 12),
        '2026-8-12',
        trackerHistoryMap,
      );

      expect(slipped, isTrue);
    });

    test('calculateCalendarEvents - generates days and task indicators', () {
      final month = DateTime(2026, 8, 1);
      final task = TaskModel(
        id: 'task-1',
        userId: 'user-1',
        name: 'Morning Workout',
        schedule: TaskSchedule(type: 'daily'),
        steps: [],
        status: 'pending',
        createdAt: DateTime(2026, 8, 1),
      );

      final events = CalendarCalculationUtils.calculateCalendarEvents(
        month: month,
        trackers: [tracker],
        trackerHistory: [
          TrackerHistoryModel(
            id: 'h-1',
            userId: 'user-1',
            trackerId: 'tracker-1',
            trackerName: 'Meditation',
            trackerType: 'maintain',
            date: DateTime(2026, 8, 10),
            type: 'completion',
          ),
        ],
        tasks: [task],
        taskHistory: [
          TaskHistoryModel(
            id: 'th-1',
            userId: 'user-1',
            taskId: 'task-1',
            taskName: 'Morning Workout',
            date: DateTime(2026, 8, 10),
            completedSteps: [],
          ),
        ],
        groups: [],
        errorColor: Colors.red,
        tertiaryColor: Colors.teal,
        defaultTaskColor: Colors.amber,
      );

      expect(events.containsKey('2026-8-10'), isTrue);
      final day10 = events['2026-8-10']!;
      expect(day10.tasks.isNotEmpty, isTrue);
      expect(day10.tasks.first.name, 'Morning Workout');
      expect(day10.tasks.first.isCompleted, isTrue);
    });
  });
}
