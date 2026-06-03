import 'package:cloud_firestore/cloud_firestore.dart';

class TaskStep {
  final String name;
  final bool isCompleted;
  
  // Timer fields
  final int? timerDuration; // In seconds. Null means no timer.
  final DateTime? timerStartedAt; // Null if not running
  final DateTime? timerPausedAt; // Null if not paused
  final int? timerSecondsRemaining; // Seconds remaining at pause/start
  final bool isTimerConfirmed; // User confirmed completion after timer expired

  TaskStep({
    required this.name,
    this.isCompleted = false,
    this.timerDuration,
    this.timerStartedAt,
    this.timerPausedAt,
    this.timerSecondsRemaining,
    this.isTimerConfirmed = false,
  });

  TaskStep copyWith({
    String? name,
    bool? isCompleted,
    int? timerDuration,
    DateTime? timerStartedAt,
    DateTime? timerPausedAt,
    int? timerSecondsRemaining,
    bool? isTimerConfirmed,
    bool clearTimerStartedAt = false,
    bool clearTimerPausedAt = false,
  }) {
    return TaskStep(
      name: name ?? this.name,
      isCompleted: isCompleted ?? this.isCompleted,
      timerDuration: timerDuration ?? this.timerDuration,
      timerStartedAt: clearTimerStartedAt ? null : (timerStartedAt ?? this.timerStartedAt),
      timerPausedAt: clearTimerPausedAt ? null : (timerPausedAt ?? this.timerPausedAt),
      timerSecondsRemaining: timerSecondsRemaining ?? this.timerSecondsRemaining,
      isTimerConfirmed: isTimerConfirmed ?? this.isTimerConfirmed,
    );
  }

  factory TaskStep.fromMap(Map<String, dynamic> map) {
    return TaskStep(
      name: map['name'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      timerDuration: map['timerDuration'],
      timerStartedAt: map['timerStartedAt'] != null
          ? (map['timerStartedAt'] as Timestamp).toDate()
          : null,
      timerPausedAt: map['timerPausedAt'] != null
          ? (map['timerPausedAt'] as Timestamp).toDate()
          : null,
      timerSecondsRemaining: map['timerSecondsRemaining'],
      isTimerConfirmed: map['isTimerConfirmed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isCompleted': isCompleted,
      'timerDuration': timerDuration,
      'timerStartedAt': timerStartedAt != null ? Timestamp.fromDate(timerStartedAt!) : null,
      'timerPausedAt': timerPausedAt != null ? Timestamp.fromDate(timerPausedAt!) : null,
      'timerSecondsRemaining': timerSecondsRemaining,
      'isTimerConfirmed': isTimerConfirmed,
    };
  }

  // Calculate remaining seconds dynamically
  int getSecondsRemaining() {
    if (timerDuration == null) return 0;
    if (timerStartedAt == null) return timerSecondsRemaining ?? timerDuration!;
    if (timerPausedAt != null) return timerSecondsRemaining ?? 0;

    final elapsed = DateTime.now().difference(timerStartedAt!).inSeconds;
    final remaining = (timerSecondsRemaining ?? timerDuration!) - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  bool isTimerRunning() {
    return timerStartedAt != null && timerPausedAt == null;
  }

  bool isTimerExpired() {
    if (timerDuration == null) return false;
    return getSecondsRemaining() <= 0 && timerStartedAt != null;
  }
}
