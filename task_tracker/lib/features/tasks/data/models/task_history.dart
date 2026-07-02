import 'package:task_tracker/core/utils/date_parser.dart';

class TaskHistoryModel {
  final String id;
  final String userId;
  final String taskId;
  final String taskName;
  final String? groupId;
  final DateTime date;
  final String type; // 'completion'
  final List<String> completedSteps;

  TaskHistoryModel({
    required this.id,
    required this.userId,
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
      userId: map['userId'] ?? '',
      taskId: map['taskId'] ?? '',
      taskName: map['taskName'] ?? '',
      groupId: map['groupId'],
      date: parseDateTime(map['date']) ?? DateTime.now(),
      type: map['type'] ?? 'completion',
      completedSteps: List<String>.from(map['completedSteps'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'taskId': taskId,
      'taskName': taskName,
      'groupId': groupId,
      'date': date,
      'type': type,
      'completedSteps': completedSteps,
    };
  }
}
