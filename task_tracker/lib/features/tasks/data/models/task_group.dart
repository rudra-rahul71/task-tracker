import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:task_tracker/features/tasks/data/models/task_schedule.dart';

class TaskGroupModel {
  final String id;
  final String userId;
  final String name;
  final int colorValue;
  final TaskSchedule? schedule;
  final DateTime createdAt;

  TaskGroupModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorValue,
    this.schedule,
    required this.createdAt,
  });

  factory TaskGroupModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TaskGroupModel(
      id: documentId,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      colorValue: map['colorValue'] ?? 0xFF4CAF50, // default green
      schedule: map['schedule'] != null ? TaskSchedule.fromMap(map['schedule']) : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'colorValue': colorValue,
      'schedule': schedule?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TaskGroupModel copyWith({
    String? id,
    String? userId,
    String? name,
    int? colorValue,
    TaskSchedule? schedule,
    DateTime? createdAt,
  }) {
    return TaskGroupModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      schedule: schedule ?? this.schedule,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
