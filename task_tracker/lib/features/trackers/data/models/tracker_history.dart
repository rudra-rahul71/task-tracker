import 'package:cloud_firestore/cloud_firestore.dart';

class TrackerHistoryModel {
  final String id;
  final String trackerId;
  final String trackerName;
  final String trackerType;
  final DateTime date;
  final String type; // 'completion' or 'slip_up'

  TrackerHistoryModel({
    required this.id,
    required this.trackerId,
    required this.trackerName,
    required this.trackerType,
    required this.date,
    required this.type,
  });

  factory TrackerHistoryModel.fromMap(Map<String, dynamic> map, String id) {
    return TrackerHistoryModel(
      id: id,
      trackerId: map['trackerId'] ?? '',
      trackerName: map['trackerName'] ?? '',
      trackerType: map['trackerType'] ?? 'maintain',
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : DateTime.now(),
      type: map['type'] ?? 'completion',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trackerId': trackerId,
      'trackerName': trackerName,
      'trackerType': trackerType,
      'date': Timestamp.fromDate(date),
      'type': type,
    };
  }
}
