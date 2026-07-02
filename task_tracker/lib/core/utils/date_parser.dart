import 'package:cloud_firestore/cloud_firestore.dart';

/// Safely parses a dynamic database value into a [DateTime].
/// Supports Firestore [Timestamp], ISO-8601 [String], and native [DateTime].
DateTime? parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value.toLocal();
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed?.toLocal();
  }
  return null;
}
