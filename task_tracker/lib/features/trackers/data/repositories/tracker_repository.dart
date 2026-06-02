import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:task_tracker/core/database/db_service.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';

class TrackerRepository {
  final FirebaseFirestore _firestore = DatabaseService.instance.firestore;

  // Stream of trackers for a specific user, sorted by creation date
  Stream<List<TrackerModel>> getTrackers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('trackers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TrackerModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Add a new tracker
  Future<void> addTracker(TrackerModel tracker) async {
    await _firestore
        .collection('users')
        .doc(tracker.userId)
        .collection('trackers')
        .add(tracker.toMap());
  }

  // Delete an existing tracker
  Future<void> deleteTracker(String userId, String trackerId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('trackers')
        .doc(trackerId)
        .delete();
  }

  // Reset a tracker's starting time to now (recalculating the end date if it is set_time)
  Future<void> resetTracker(TrackerModel tracker) async {
    final now = DateTime.now();
    DateTime? newEndDate;

    if (tracker.durationType == 'set_time' && tracker.durationValue != null) {
      switch (tracker.measurementUnit) {
        case 'minutes':
          newEndDate = now.add(Duration(minutes: tracker.durationValue!));
          break;
        case 'hours':
          newEndDate = now.add(Duration(hours: tracker.durationValue!));
          break;
        case 'weeks':
          newEndDate = now.add(Duration(days: tracker.durationValue! * 7));
          break;
        case 'months':
          // Add calendar months
          newEndDate = DateTime(now.year, now.month + tracker.durationValue!, now.day);
          break;
        case 'days':
        default:
          newEndDate = now.add(Duration(days: tracker.durationValue!));
          break;
      }
    }

    await _firestore
        .collection('users')
        .doc(tracker.userId)
        .collection('trackers')
        .doc(tracker.id)
        .update({
      'startDate': Timestamp.fromDate(now),
      'endDate': newEndDate != null ? Timestamp.fromDate(newEndDate) : null,
    });
  }
}
