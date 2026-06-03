import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:task_tracker/features/tasks/data/models/task_schedule.dart';
import 'package:task_tracker/features/tasks/data/models/task_step.dart';

class TaskModel {
  final String id;
  final String userId;
  final String? groupId;
  final String name;
  final String description;
  final TaskSchedule? schedule; // If set, overrides group schedule
  final List<TaskStep> steps;
  final String status; // 'pending', 'completed'
  final DateTime? lastCompletedAt;
  final DateTime? lastResetAt;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.userId,
    this.groupId,
    required this.name,
    this.description = '',
    this.schedule,
    required this.steps,
    this.status = 'pending',
    this.lastCompletedAt,
    this.lastResetAt,
    required this.createdAt,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TaskModel(
      id: documentId,
      userId: map['userId'] ?? '',
      groupId: map['groupId'],
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      schedule: map['schedule'] != null ? TaskSchedule.fromMap(map['schedule']) : null,
      steps: map['steps'] != null
          ? (map['steps'] as List).map((stepMap) => TaskStep.fromMap(Map<String, dynamic>.from(stepMap))).toList()
          : [],
      status: map['status'] ?? 'pending',
      lastCompletedAt: map['lastCompletedAt'] != null
          ? (map['lastCompletedAt'] as Timestamp).toDate()
          : null,
      lastResetAt: map['lastResetAt'] != null
          ? (map['lastResetAt'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'groupId': groupId,
      'name': name,
      'description': description,
      'schedule': schedule?.toMap(),
      'steps': steps.map((step) => step.toMap()).toList(),
      'status': status,
      'lastCompletedAt': lastCompletedAt != null ? Timestamp.fromDate(lastCompletedAt!) : null,
      'lastResetAt': lastResetAt != null ? Timestamp.fromDate(lastResetAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TaskModel copyWith({
    String? id,
    String? userId,
    String? groupId,
    String? name,
    String? description,
    TaskSchedule? schedule,
    List<TaskStep>? steps,
    String? status,
    DateTime? lastCompletedAt,
    DateTime? lastResetAt,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      description: description ?? this.description,
      schedule: schedule ?? this.schedule,
      steps: steps ?? this.steps,
      status: status ?? this.status,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      lastResetAt: lastResetAt ?? this.lastResetAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isAllStepsCompleted => steps.isNotEmpty && steps.every((s) => s.isCompleted);

  double get progress => steps.isEmpty ? 0.0 : steps.where((s) => s.isCompleted).length / steps.length;
}
