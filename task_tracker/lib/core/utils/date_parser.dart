/// Safely parses a dynamic database value into a [DateTime].
/// Supports ISO-8601 [String] and native [DateTime].
DateTime? parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed?.toLocal();
  }
  return null;
}

extension DateUtilsExtension on DateTime {
  /// Returns a new [DateTime] with time components set to zero (midnight).
  DateTime get dateOnly => DateTime(year, month, day);

  /// Returns true if this date matches [other] in year, month, and day.
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}
