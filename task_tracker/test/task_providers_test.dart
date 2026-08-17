import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_schedule.dart';
import 'package:task_tracker/features/tasks/data/models/task_step.dart';
import 'package:task_tracker/features/tasks/presentation/providers/task_providers.dart';

void main() {
  group('TaskEvaluationUtils Tests', () {
    final groupA = TaskGroupModel(
      id: 'group-1',
      userId: 'user-1',
      name: 'Morning Routine',
      colorValue: 0xFFFF0000,
      schedule: TaskSchedule(
        type: 'weekly',
        daysOfWeek: [1, 3, 5], // Mon, Wed, Fri
      ),
      createdAt: DateTime(2026, 1, 1),
    );

    final groups = [groupA];

    test('isTaskDueToday - one-off task due today', () {
      final today = DateTime(2026, 8, 17, 10, 0);

      final task = TaskModel(
        id: 'task-1',
        userId: 'user-1',
        name: 'Buy Groceries',
        schedule: TaskSchedule(type: 'none', startDate: DateTime(2026, 8, 17)),
        steps: [TaskStep(name: 'Milk')],
        status: 'pending',
        createdAt: DateTime(2026, 8, 1),
      );

      expect(TaskEvaluationUtils.isTaskDueToday(task, groups, today), isTrue);
    });

    test('isTaskDueToday - inherited group schedule', () {
      // 2026-08-17 is a Monday (weekday 1)
      final monday = DateTime(2026, 8, 17, 10, 0);
      // 2026-08-18 is a Tuesday (weekday 2)
      final tuesday = DateTime(2026, 8, 18, 10, 0);

      final groupTask = TaskModel(
        id: 'task-2',
        userId: 'user-1',
        groupId: 'group-1',
        name: 'Drink Water',
        schedule: null, // Inherits group-1 schedule (Mon, Wed, Fri)
        steps: [],
        status: 'pending',
        createdAt: DateTime(2026, 8, 1),
      );

      expect(TaskEvaluationUtils.isTaskDueToday(groupTask, groups, monday), isTrue);
      expect(TaskEvaluationUtils.isTaskDueToday(groupTask, groups, tuesday), isFalse);
    });

    test('isTaskOverdueOneOff - detects overdue pending one-off task', () {
      final today = DateTime(2026, 8, 17);

      final overdueTask = TaskModel(
        id: 'task-3',
        userId: 'user-1',
        name: 'Pay Rent',
        schedule: TaskSchedule(type: 'none', startDate: DateTime(2026, 8, 10)),
        steps: [],
        status: 'pending',
        createdAt: DateTime(2026, 8, 1),
      );

      final futureTask = TaskModel(
        id: 'task-4',
        userId: 'user-1',
        name: 'File Taxes',
        schedule: TaskSchedule(type: 'none', startDate: DateTime(2026, 8, 25)),
        steps: [],
        status: 'pending',
        createdAt: DateTime(2026, 8, 1),
      );

      expect(TaskEvaluationUtils.isTaskOverdueOneOff(overdueTask, groups, today), isTrue);
      expect(TaskEvaluationUtils.isTaskOverdueOneOff(futureTask, groups, today), isFalse);
    });

    test('partitionTasksByOverdue - correctly splits overdue and upcoming', () {
      final today = DateTime(2026, 8, 17);

      final tasks = [
        TaskModel(
          id: 't-1',
          userId: 'u-1',
          name: 'Old Task',
          schedule: TaskSchedule(type: 'none', startDate: DateTime(2026, 8, 1)),
          steps: [],
          status: 'pending',
          createdAt: DateTime(2026, 7, 1),
        ),
        TaskModel(
          id: 't-2',
          userId: 'u-1',
          name: 'Future Task',
          schedule: TaskSchedule(type: 'none', startDate: DateTime(2026, 8, 20)),
          steps: [],
          status: 'pending',
          createdAt: DateTime(2026, 8, 1),
        ),
      ];

      final (overdue, upcoming) = TaskEvaluationUtils.partitionTasksByOverdue(tasks, groups, today);
      expect(overdue.length, 1);
      expect(overdue.first.id, 't-1');
      expect(upcoming.length, 1);
      expect(upcoming.first.id, 't-2');
    });

    test('filterTasks - filters by status and recurrence', () {
      final today = DateTime(2026, 8, 17);

      final tasks = [
        TaskModel(
          id: 't-due',
          userId: 'u-1',
          name: 'Due Today',
          schedule: TaskSchedule(type: 'none', startDate: DateTime(2026, 8, 17)),
          steps: [],
          status: 'pending',
          createdAt: DateTime(2026, 8, 1),
        ),
        TaskModel(
          id: 't-completed',
          userId: 'u-1',
          name: 'Completed One-Off',
          schedule: TaskSchedule(type: 'none', startDate: DateTime(2026, 8, 10)),
          steps: [],
          status: 'completed',
          lastCompletedAt: DateTime(2026, 8, 10),
          createdAt: DateTime(2026, 8, 1),
        ),
      ];

      final dueTasks = TaskEvaluationUtils.filterTasks(
        tasks: tasks,
        groups: groups,
        filter: 'due',
        currentDate: today,
      );
      expect(dueTasks.map((t) => t.id), contains('t-due'));
      expect(dueTasks.map((t) => t.id), isNot(contains('t-completed')));

      final completedTasks = TaskEvaluationUtils.filterTasks(
        tasks: tasks,
        groups: groups,
        filter: 'completed',
        currentDate: today,
      );
      expect(completedTasks.map((t) => t.id), contains('t-completed'));
      expect(completedTasks.map((t) => t.id), isNot(contains('t-due')));
    });
  });
}
