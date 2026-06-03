import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:task_tracker/core/database/db_service.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_schedule.dart';
import 'package:task_tracker/features/tasks/data/models/task_history.dart';

class TaskRepository {
  final FirebaseFirestore _firestore = DatabaseService.instance.firestore;

  // --- GROUPS ---

  Stream<List<TaskGroupModel>> getGroups(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('task_groups')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskGroupModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addGroup(TaskGroupModel group) async {
    await _firestore
        .collection('users')
        .doc(group.userId)
        .collection('task_groups')
        .add(group.toMap());
  }

  Future<void> updateGroup(TaskGroupModel group) async {
    await _firestore
        .collection('users')
        .doc(group.userId)
        .collection('task_groups')
        .doc(group.id)
        .update(group.toMap());
  }

  Future<void> deleteGroup(String userId, String groupId) async {
    // Delete the group itself
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('task_groups')
        .doc(groupId)
        .delete();

    // Also clear the groupId reference for all tasks in this group
    final tasksSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('groupId', isEqualTo: groupId)
        .get();

    final batch = _firestore.batch();
    for (var doc in tasksSnapshot.docs) {
      batch.update(doc.reference, {'groupId': null});
    }
    await batch.commit();
  }

  // --- TASKS ---

  Stream<List<TaskModel>> getTasks(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addTask(TaskModel task) async {
    await _firestore
        .collection('users')
        .doc(task.userId)
        .collection('tasks')
        .add(task.toMap());
  }

  Future<void> updateTask(TaskModel task) async {
    final docRef = _firestore
        .collection('users')
        .doc(task.userId)
        .collection('tasks')
        .doc(task.id);

    // Get the current snapshot to compare status changes
    final docSnap = await docRef.get();
    final Map<String, dynamic>? oldMap = docSnap.data();
    final String? oldStatus = oldMap?['status'];

    final batch = _firestore.batch();
    batch.update(docRef, task.toMap());

    final today = DateTime.now();
    final todayZero = DateTime(today.year, today.month, today.day);

    if (task.status == 'completed' && oldStatus != 'completed') {
      // 1. Task completed! Log history
      final historyRef = _firestore
          .collection('users')
          .doc(task.userId)
          .collection('task_history')
          .doc();

      final historyRecord = TaskHistoryModel(
        id: '',
        taskId: task.id,
        taskName: task.name,
        groupId: task.groupId,
        date: todayZero,
        completedSteps: task.steps.where((s) => s.isCompleted).map((s) => s.name).toList(),
      );
      batch.set(historyRef, historyRecord.toMap());
    } else if (task.status == 'pending' && oldStatus == 'completed') {
      // 2. Task went from completed to pending (reset/uncompleted). Delete history for today
      final historySnapshot = await _firestore
          .collection('users')
          .doc(task.userId)
          .collection('task_history')
          .where('taskId', isEqualTo: task.id)
          .where('date', isEqualTo: Timestamp.fromDate(todayZero))
          .get();

      for (var doc in historySnapshot.docs) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  Future<void> deleteTask(String userId, String taskId) async {
    final batch = _firestore.batch();

    // 1. Delete task doc
    final taskRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId);
    batch.delete(taskRef);

    // 2. Delete history docs
    final historySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('task_history')
        .where('taskId', isEqualTo: taskId)
        .get();

    for (var doc in historySnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Get completions stream for a specific month
  Stream<List<TaskHistoryModel>> getMonthlyTaskHistory(String userId, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1).subtract(const Duration(microseconds: 1));

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('task_history')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskHistoryModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Scan and reset tasks if they have crossed into a new scheduling cycle
  Future<void> checkAndResetScheduledTasks({
    required String userId,
    required List<TaskModel> tasks,
    required List<TaskGroupModel> groups,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();
    bool hasUpdates = false;

    // Build a map of groups for quick lookup
    final groupMap = {for (var g in groups) g.id: g};

    for (var task in tasks) {
      // Determine effective schedule
      TaskSchedule? effectiveSchedule;
      if (task.schedule != null && task.schedule!.type != 'none') {
        effectiveSchedule = task.schedule;
      } else if (task.groupId != null) {
        final group = groupMap[task.groupId];
        if (group != null && group.schedule != null && group.schedule!.type != 'none') {
          effectiveSchedule = group.schedule;
        }
      }
      if (effectiveSchedule != null) {
        if (effectiveSchedule.needsReset(now, task.lastResetAt)) {
          // Task needs a reset for the new cycle!
          final resetSteps = task.steps.map((step) {
            return step.copyWith(
              isCompleted: false,
              clearTimerStartedAt: true,
              clearTimerPausedAt: true,
              timerSecondsRemaining: step.timerDuration,
              isTimerConfirmed: false,
            );
          }).toList();

          final updatedTask = task.copyWith(
            steps: resetSteps,
            status: 'pending',
            lastResetAt: now,
          );

          final docRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('tasks')
              .doc(task.id);

          batch.update(docRef, updatedTask.toMap());
          hasUpdates = true;
        }
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }
}
