import 'package:task_tracker/core/utils/date_parser.dart';

class TrackerHistoryModel {
  final String id;
  final String userId;
  final String trackerId;
  final String trackerName;
  final String trackerType;
  final DateTime date;
  final String type; // 'completion' or 'slip_up'

  TrackerHistoryModel({
    required this.id,
    required this.userId,
    required this.trackerId,
    required this.trackerName,
    required this.trackerType,
    required this.date,
    required this.type,
  });

  factory TrackerHistoryModel.fromMap(Map<String, dynamic> map, String id) {
    return TrackerHistoryModel(
      id: id,
      userId: map['userId'] ?? '',
      trackerId: map['trackerId'] ?? '',
      trackerName: map['trackerName'] ?? '',
      trackerType: map['trackerType'] ?? 'maintain',
      date: parseDateTime(map['date']) ?? DateTime.now(),
      type: map['type'] ?? 'completion',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'trackerId': trackerId,
      'trackerName': trackerName,
      'trackerType': trackerType,
      'date': date,
      'type': type,
    };
  }
}
