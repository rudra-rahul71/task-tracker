import 'package:cloud_firestore/cloud_firestore.dart';

class TaskHistoryModel {
  final String id;
  final String taskId;
  final String taskName;
  final String? groupId;
  final DateTime date;
  final String type; // 'completion'
  final List<String> completedSteps;

  TaskHistoryModel({
    required this.id,
    required this.taskId,
    required this.taskName,
    this.groupId,
    required this.date,
    this.type = 'completion',
    this.completedSteps = const [],
  });

  factory TaskHistoryModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskHistoryModel(
      id: id,
      taskId: map['taskId'] ?? '',
      taskName: map['taskName'] ?? '',
      groupId: map['groupId'],
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : DateTime.now(),
      type: map['type'] ?? 'completion',
      completedSteps: List<String>.from(map['completedSteps'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'taskName': taskName,
      'groupId': groupId,
      'date': Timestamp.fromDate(date),
      'type': type,
      'completedSteps': completedSteps,
    };
  }
}
