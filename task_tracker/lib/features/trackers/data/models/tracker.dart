import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  // Convert Firestore DocumentSnapshot to TrackerModel
  factory TrackerModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TrackerModel(
      id: documentId,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'maintain',
      durationType: map['durationType'] ?? 'indefinite',
      measurementUnit: map['measurementUnit'] ?? 'days',
      durationValue: map['durationValue'],
      startDate: map['startDate'] != null 
          ? (map['startDate'] as Timestamp).toDate() 
          : DateTime.now(),
      endDate: map['endDate'] != null 
          ? (map['endDate'] as Timestamp).toDate() 
          : null,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
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
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Calculate elapsed time or countdown text
  String getFormattedDuration() {
    final now = DateTime.now();
    if (durationType == 'indefinite') {
      final diff = now.difference(startDate);
      if (diff.isNegative) return 'Not started';

      switch (measurementUnit) {
        case 'minutes':
          final mins = diff.inMinutes;
          return '$mins ${mins == 1 ? 'minute' : 'minutes'}';

        case 'hours':
          final hours = diff.inHours;
          return '$hours ${hours == 1 ? 'hour' : 'hours'}';

        case 'weeks':
          final totalDays = diff.inDays;
          final weeks = totalDays ~/ 7;
          final days = totalDays % 7;
          final weeksStr = '$weeks ${weeks == 1 ? 'week' : 'weeks'}';
          if (days == 0) return weeksStr;
          return '$weeksStr, $days ${days == 1 ? 'day' : 'days'}';

        case 'months':
          int yearsDiff = now.year - startDate.year;
          int monthsDiff = now.month - startDate.month + (yearsDiff * 12);
          DateTime tempDate = DateTime(startDate.year, startDate.month + monthsDiff, startDate.day);
          if (tempDate.isAfter(now)) {
            monthsDiff--;
            tempDate = DateTime(startDate.year, startDate.month + monthsDiff, startDate.day);
          }
          final daysDiff = now.difference(tempDate).inDays;
          final monthsStr = '$monthsDiff ${monthsDiff == 1 ? 'month' : 'months'}';
          if (daysDiff == 0) return monthsStr;
          return '$monthsStr, $daysDiff ${daysDiff == 1 ? 'day' : 'days'}';

        case 'days':
        default:
          final days = diff.inDays;
          return '$days ${days == 1 ? 'day' : 'days'}';
      }
    } else {
      // Set time countdown
      if (endDate == null) return 'No end date';
      final remaining = endDate!.difference(now);
      if (remaining.isNegative) {
        return 'Completed!';
      }

      switch (measurementUnit) {
        case 'minutes':
          final mins = remaining.inMinutes;
          return '$mins ${mins == 1 ? 'min' : 'mins'} remaining';

        case 'hours':
          final hours = remaining.inHours;
          return '$hours ${hours == 1 ? 'hour' : 'hours'} remaining';

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
          DateTime tempDate = DateTime(now.year, now.month + monthsDiff, now.day);
          if (tempDate.isAfter(endDate!)) {
            monthsDiff--;
            tempDate = DateTime(now.year, now.month + monthsDiff, now.day);
          }
          final daysDiff = endDate!.difference(tempDate).inDays;
          final monthsStr = '$monthsDiff ${monthsDiff == 1 ? 'month' : 'months'}';
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
        case 'minutes':
          final elapsedSecs = diff.inSeconds % 60;
          return elapsedSecs / 60.0;

        case 'hours':
          final elapsedMins = diff.inMinutes % 60;
          final elapsedSecs = diff.inSeconds % 60;
          return (elapsedMins * 60 + elapsedSecs) / 3600.0;

        case 'weeks':
          final elapsedMs = diff.inMilliseconds;
          const weekMs = 7 * 24 * 60 * 60 * 1000;
          return (elapsedMs % weekMs) / weekMs;

        case 'months':
          int yearsDiff = now.year - startDate.year;
          int monthsDiff = now.month - startDate.month + (yearsDiff * 12);
          DateTime currentAnniversary = DateTime(startDate.year, startDate.month + monthsDiff, startDate.day);
          if (currentAnniversary.isAfter(now)) {
            monthsDiff--;
            currentAnniversary = DateTime(startDate.year, startDate.month + monthsDiff, startDate.day);
          }
          DateTime nextAnniversary = DateTime(startDate.year, startDate.month + monthsDiff + 1, startDate.day);

          final totalDaysInMonth = nextAnniversary.difference(currentAnniversary).inDays;
          final daysSinceAnniversary = now.difference(currentAnniversary).inDays;

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
}
