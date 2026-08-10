import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_step.dart';

void main() {
  group('TaskModel Tests', () {
    test('TaskModel lastUpdatedByToken serialization and copyWith', () {
      final now = DateTime.now();
      final task = TaskModel(
        id: 'task_1',
        userId: 'user_1',
        name: 'Test Task',
        steps: [TaskStep(name: 'Step 1')],
        createdAt: now,
        lastUpdatedByToken: 'fcm_token_123',
      );

      expect(task.lastUpdatedByToken, equals('fcm_token_123'));

      final map = task.toMap();
      expect(map['lastUpdatedByToken'], equals('fcm_token_123'));

      final reconstructed = TaskModel.fromMap(map, 'task_1');
      expect(reconstructed.lastUpdatedByToken, equals('fcm_token_123'));

      final updated = task.copyWith(lastUpdatedByToken: 'fcm_token_456');
      expect(updated.lastUpdatedByToken, equals('fcm_token_456'));
    });
  });
}
