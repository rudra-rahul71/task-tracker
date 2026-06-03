import 'package:cloud_firestore/cloud_firestore.dart';

class TaskSchedule {
  final String type; // 'none', 'weekly', 'bi_weekly', 'monthly'
  final List<int> daysOfWeek; // 1 = Monday, 7 = Sunday
  final int dayOfMonth; // 1 to 31
  final DateTime? startDate; // Anchor for bi-weekly schedule

  TaskSchedule({
    required this.type,
    this.daysOfWeek = const [],
    this.dayOfMonth = 1,
    this.startDate,
  });

  // Start of the week (Monday) helper
  static DateTime startOfWeek(DateTime d) {
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  }

  factory TaskSchedule.fromMap(Map<String, dynamic> map) {
    return TaskSchedule(
      type: map['type'] ?? 'none',
      daysOfWeek: List<int>.from(map['daysOfWeek'] ?? []),
      dayOfMonth: map['dayOfMonth'] ?? 1,
      startDate: map['startDate'] != null
          ? (map['startDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'daysOfWeek': daysOfWeek,
      'dayOfMonth': dayOfMonth,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
    };
  }

  // Checks if the schedule triggers on a given date
  bool isDueOnDate(DateTime date) {
    if (type == 'none') return false;

    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (type == 'weekly') {
      return daysOfWeek.contains(normalizedDate.weekday);
    }

    if (type == 'bi_weekly') {
      if (startDate == null) return false;
      final anchor = startDate!;
      if (normalizedDate.isBefore(anchor)) return false;

      // Calculate difference in weeks between date and anchor
      final diffWeeks = (startOfWeek(normalizedDate).difference(startOfWeek(anchor)).inDays / 7).round();
      final isDueWeek = diffWeeks.abs() % 2 == 0;
      final isDueDay = daysOfWeek.contains(normalizedDate.weekday);

      return isDueWeek && isDueDay;
    }

    if (type == 'monthly') {
      final lastDayOfThisMonth = DateTime(normalizedDate.year, normalizedDate.month + 1, 0).day;
      final targetDay = dayOfMonth > lastDayOfThisMonth ? lastDayOfThisMonth : dayOfMonth;
      return normalizedDate.day == targetDay;
    }

    return false;
  }

  // Returns the timestamp marking the start of the current recurrence cycle
  DateTime getStartOfCurrentCycle(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (type == 'none') {
      return DateTime(1970); // Never resets automatically
    }

    if (type == 'weekly') {
      for (int i = 0; i < 7; i++) {
        final d = normalizedDate.subtract(Duration(days: i));
        if (daysOfWeek.contains(d.weekday)) {
          return d;
        }
      }
      return startOfWeek(normalizedDate);
    }

    if (type == 'bi_weekly') {
      for (int i = 0; i < 14; i++) {
        final d = normalizedDate.subtract(Duration(days: i));
        if (isDueOnDate(d)) {
          return d;
        }
      }
      return startOfWeek(normalizedDate);
    }

    if (type == 'monthly') {
      final lastDayOfThisMonth = DateTime(normalizedDate.year, normalizedDate.month + 1, 0).day;
      final targetDay = dayOfMonth > lastDayOfThisMonth ? lastDayOfThisMonth : dayOfMonth;
      DateTime cycleStart = DateTime(normalizedDate.year, normalizedDate.month, targetDay);

      if (normalizedDate.isBefore(cycleStart)) {
        // Today is before the target day, so we are still in the cycle that started last month
        final lastDayOfPrevMonth = DateTime(normalizedDate.year, normalizedDate.month, 0).day;
        final prevTargetDay = dayOfMonth > lastDayOfPrevMonth ? lastDayOfPrevMonth : dayOfMonth;
        cycleStart = DateTime(normalizedDate.year, normalizedDate.month - 1, prevTargetDay);
      }
      return cycleStart;
    }

    return DateTime(1970);
  }

  // Checks if the task needs a reset based on last reset time
  bool needsReset(DateTime date, DateTime? lastResetAt) {
    if (type == 'none') return false;
    if (lastResetAt == null) return true; // If never reset, needs it
    final cycleStart = getStartOfCurrentCycle(date);
    return lastResetAt.isBefore(cycleStart);
  }
}
