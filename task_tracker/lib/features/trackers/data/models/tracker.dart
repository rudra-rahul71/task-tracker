import 'package:task_tracker/core/utils/date_parser.dart';

class TrackerModel {
  final String id;
  final String userId;
  final String name;
  final String type; // 'quit' (bad habit) or 'maintain' (good habit)
  final String durationType; // 'indefinite' or 'set_time'
  final String measurementUnit; // 'days', 'weeks', 'months'
  final int? durationValue; // e.g., 30 for 30 days
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final List<DateTime> completedDates;
  final DateTime originalStartDate;

  TrackerModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.durationType,
    required this.measurementUnit,
    this.durationValue,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    this.completedDates = const [],
    required this.originalStartDate,
  });

  // Convert Firestore DocumentSnapshot to TrackerModel
  factory TrackerModel.fromMap(Map<String, dynamic> map, String documentId) {
    final rawStart = parseDateTime(map['startDate']) ?? DateTime.now();
    final start = DateTime(rawStart.year, rawStart.month, rawStart.day);

    final rawOriginalStart = parseDateTime(map['originalStartDate']) ?? start;
    final originalStart = DateTime(
      rawOriginalStart.year,
      rawOriginalStart.month,
      rawOriginalStart.day,
    );

    final rawEndDate = parseDateTime(map['endDate']);
    final endDate = rawEndDate != null
        ? DateTime(rawEndDate.year, rawEndDate.month, rawEndDate.day)
        : null;

    final createdAt = parseDateTime(map['createdAt']) ?? DateTime.now();

    return TrackerModel(
      id: documentId,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'maintain',
      durationType: map['durationType'] ?? 'indefinite',
      measurementUnit: map['measurementUnit'] ?? 'days',
      durationValue: map['durationValue'],
      startDate: start,
      endDate: endDate,
      createdAt: createdAt,
      completedDates:
          (map['completedDates'] as List<dynamic>?)?.map((item) {
            final d = parseDateTime(item) ?? DateTime.now();
            return DateTime(d.year, d.month, d.day);
          }).toList() ??
          [],
      originalStartDate: originalStart,
    );
  }

  // Convert TrackerModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'type': type,
      'durationType': durationType,
      'measurementUnit': measurementUnit,
      'durationValue': durationValue,
      'startDate': startDate,
      'endDate': endDate,
      'createdAt': createdAt,
      'completedDates': completedDates,
      'originalStartDate': originalStartDate,
    };
  }

  // Calculate elapsed time or countdown text
  String getFormattedDuration() {
    final now = DateTime.now();
    if (durationType == 'indefinite') {
      final streak = getActiveStreak();
      final unit = measurementUnit == 'weeks'
          ? (streak == 1 ? 'week' : 'weeks')
          : measurementUnit == 'months'
          ? (streak == 1 ? 'month' : 'months')
          : (streak == 1 ? 'day' : 'days');
      return '$streak $unit';
    } else {
      // Set time countdown
      if (endDate == null) return 'No end date';
      final remaining = endDate!.difference(now);
      if (remaining.isNegative) {
        return 'Completed!';
      }

      switch (measurementUnit) {
        case 'weeks':
          final totalDays = remaining.inDays;
          final weeks = totalDays ~/ 7;
          final days = totalDays % 7;
          final weeksStr = '$weeks ${weeks == 1 ? 'week' : 'weeks'}';
          if (days == 0) return '$weeksStr remaining';
          return '$weeksStr, $days ${days == 1 ? 'day' : 'days'} remaining';

        case 'months':
          int yearsDiff = endDate!.year - now.year;
          int monthsDiff = endDate!.month - now.month + (yearsDiff * 12);
          DateTime tempDate = DateTime(
            now.year,
            now.month + monthsDiff,
            now.day,
          );
          if (tempDate.isAfter(endDate!)) {
            monthsDiff--;
            tempDate = DateTime(now.year, now.month + monthsDiff, now.day);
          }
          final daysDiff = endDate!.difference(tempDate).inDays;
          final monthsStr =
              '$monthsDiff ${monthsDiff == 1 ? 'month' : 'months'}';
          if (daysDiff == 0) return '$monthsStr remaining';
          return '$monthsStr, $daysDiff ${daysDiff == 1 ? 'day' : 'days'} remaining';

        case 'days':
        default:
          final days = remaining.inDays;
          return '$days ${days == 1 ? 'day' : 'days'} remaining';
      }
    }
  }

  // Calculate completion progress ratio (0.0 to 1.0)
  double getProgress() {
    if (durationType == 'indefinite') {
      final now = DateTime.now();
      final diff = now.difference(startDate);
      if (diff.isNegative) return 0.0;

      switch (measurementUnit) {
        case 'weeks':
          final elapsedMs = diff.inMilliseconds;
          const weekMs = 7 * 24 * 60 * 60 * 1000;
          return (elapsedMs % weekMs) / weekMs;

        case 'months':
          int yearsDiff = now.year - startDate.year;
          int monthsDiff = now.month - startDate.month + (yearsDiff * 12);
          DateTime currentAnniversary = DateTime(
            startDate.year,
            startDate.month + monthsDiff,
            startDate.day,
          );
          if (currentAnniversary.isAfter(now)) {
            monthsDiff--;
            currentAnniversary = DateTime(
              startDate.year,
              startDate.month + monthsDiff,
              startDate.day,
            );
          }
          DateTime nextAnniversary = DateTime(
            startDate.year,
            startDate.month + monthsDiff + 1,
            startDate.day,
          );

          final totalDaysInMonth = nextAnniversary
              .difference(currentAnniversary)
              .inDays;
          final daysSinceAnniversary = now
              .difference(currentAnniversary)
              .inDays;

          if (totalDaysInMonth <= 0) return 0.0;
          return (daysSinceAnniversary / totalDaysInMonth).clamp(0.0, 1.0);

        case 'days':
        default:
          final elapsedMs = diff.inMilliseconds;
          const dayMs = 24 * 60 * 60 * 1000;
          return (elapsedMs % dayMs) / dayMs;
      }
    } else {
      // Set time countdown progress (overall progress)
      if (endDate == null) return 1.0;
      final totalMs = endDate!.difference(startDate).inMilliseconds;
      if (totalMs <= 0) return 1.0;

      final elapsedMs = DateTime.now().difference(startDate).inMilliseconds;
      final progress = elapsedMs / totalMs;
      return progress.clamp(0.0, 1.0);
    }
  }

  DateTime getPeriodStart(int i) {
    switch (measurementUnit) {
      case 'weeks':
        return startDate.add(Duration(days: i * 7));
      case 'months':
        return DateTime(startDate.year, startDate.month + i, startDate.day);
      case 'days':
      default:
        return startDate.add(Duration(days: i));
    }
  }

  DateTime getPeriodEnd(int i) {
    return getPeriodStart(i + 1);
  }

  int getCurrentPeriodIndex(DateTime now) {
    if (now.isBefore(startDate)) return 0;
    int i = 0;
    while (true) {
      final end = getPeriodEnd(i);
      if (end.isAfter(now)) {
        return i;
      }
      if (i > 10000) return i; // Safety limit
      i++;
    }
  }

  bool isPeriodCompleted(int i) {
    final start = getPeriodStart(i);
    final end = getPeriodEnd(i);
    return completedDates.any(
      (date) =>
          (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
          date.isBefore(end),
    );
  }

  DateTime? getNewStartDateIfResetNeeded(DateTime now) {
    if (type != 'maintain') return null; // Only auto-reset maintain habits
    if (now.isBefore(startDate)) return null;

    final currentPeriod = getCurrentPeriodIndex(now);
    // Check all past periods: i = 0 to currentPeriod - 1
    for (int i = 0; i < currentPeriod; i++) {
      if (!isPeriodCompleted(i)) {
        // Missed a period! Reset startDate to the start of the current period C
        final newStart = getPeriodStart(currentPeriod);
        if (newStart != startDate) {
          return newStart;
        }
      }
    }
    return null;
  }

  int getActiveStreak() {
    if (type != 'maintain') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      if (today.isBefore(start)) return 0;
      final diffDays = today.difference(start).inDays;
      if (measurementUnit == 'weeks') {
        return diffDays ~/ 7;
      } else if (measurementUnit == 'months') {
        int yearsDiff = today.year - start.year;
        int monthsDiff = today.month - start.month + (yearsDiff * 12);
        DateTime tempDate = DateTime(
          start.year,
          start.month + monthsDiff,
          start.day,
        );
        if (tempDate.isAfter(today)) {
          monthsDiff--;
        }
        return monthsDiff;
      } else {
        return diffDays;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // We count periods backwards from the current period
    final currentPeriod = getCurrentPeriodIndex(today);

    // Check if the current period is completed
    bool currentCompleted = isPeriodCompleted(currentPeriod);

    int streak = 0;
    if (currentCompleted) {
      streak = 1;
      // Count consecutive completed past periods
      int p = currentPeriod - 1;
      while (p >= 0 && isPeriodCompleted(p)) {
        streak++;
        p--;
      }
    } else {
      // Current period is not completed yet.
      // The user still has time left to complete it, so the streak is not broken.
      // We check if the previous period (currentPeriod - 1) was completed.
      if (currentPeriod > 0 && isPeriodCompleted(currentPeriod - 1)) {
        streak = 0;
        int p = currentPeriod - 1;
        while (p >= 0 && isPeriodCompleted(p)) {
          streak++;
          p--;
        }
      } else {
        // Yesterday/previous period was missed, so the streak is 0
        streak = 0;
      }
    }
    return streak;
  }

  bool isCompletedOnDay(DateTime dayDate) {
    final dayZero = DateTime(dayDate.year, dayDate.month, dayDate.day);
    final originalStartZero = DateTime(
      originalStartDate.year,
      originalStartDate.month,
      originalStartDate.day,
    );
    final todayZero = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    if (dayZero.isBefore(originalStartZero) || dayZero.isAfter(todayZero)) {
      return false;
    }

    if (type == 'maintain') {
      final hasManualCompletion = completedDates.any(
        (d) =>
            d.year == dayDate.year &&
            d.month == dayDate.month &&
            d.day == dayDate.day,
      );
      if (hasManualCompletion) return true;

      final createdZero = DateTime(
        createdAt.year,
        createdAt.month,
        createdAt.day,
      );
      if (dayZero.isBefore(todayZero) && dayZero.isBefore(createdZero)) {
        return true;
      }

      // Assume completed properly if it is part of the current active streak
      final newStartDate = getNewStartDateIfResetNeeded(DateTime.now());
      final currentStartZero = DateTime(
        (newStartDate ?? startDate).year,
        (newStartDate ?? startDate).month,
        (newStartDate ?? startDate).day,
      );
      if (dayZero.isBefore(todayZero) && !dayZero.isBefore(currentStartZero)) {
        return true;
      }

      return false;
    } else {
      // For quit habits, they are completed properly (clean) if they did NOT slip up
      return !hasSlipUpOnDay(dayDate);
    }
  }

  bool hasSlipUpOnDay(DateTime dayDate) {
    if (type == 'quit') {
      return completedDates.any(
        (d) =>
            d.year == dayDate.year &&
            d.month == dayDate.month &&
            d.day == dayDate.day,
      );
    } else {
      final dayZero = DateTime(dayDate.year, dayDate.month, dayDate.day);
      final originalStartZero = DateTime(
        originalStartDate.year,
        originalStartDate.month,
        originalStartDate.day,
      );
      final todayZero = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final endZero = endDate != null
          ? DateTime(endDate!.year, endDate!.month, endDate!.day)
          : null;

      if (dayZero.isBefore(todayZero) &&
          !dayZero.isBefore(originalStartZero) &&
          (endZero == null || !dayZero.isAfter(endZero))) {
        return !isCompletedOnDay(dayDate);
      }
      return false;
    }
  }
}
