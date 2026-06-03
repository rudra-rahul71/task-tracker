import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:task_tracker/core/database/db_service.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/models/tracker_history.dart';

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

  // Add a new tracker and backfill completion entries if started in the past
  Future<void> addTracker(TrackerModel tracker) async {
    final batch = _firestore.batch();
    
    final trackerRef = _firestore
        .collection('users')
        .doc(tracker.userId)
        .collection('trackers')
        .doc();

    final start = DateTime(tracker.startDate.year, tracker.startDate.month, tracker.startDate.day);
    final originalStart = DateTime(tracker.originalStartDate.year, tracker.originalStartDate.month, tracker.originalStartDate.day);
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final completedDates = List<DateTime>.from(tracker.completedDates);
    
    // If it is a maintain habit and was started in the past, backfill completion entries
    if (tracker.type == 'maintain' && start.isBefore(today)) {
      DateTime current = start;
      while (current.isBefore(today)) {
        if (!completedDates.any((d) => d.year == current.year && d.month == current.month && d.day == current.day)) {
          completedDates.add(current);
        }
        
        final historyRef = _firestore
            .collection('users')
            .doc(tracker.userId)
            .collection('history')
            .doc();
            
        final historyRecord = TrackerHistoryModel(
          id: '',
          trackerId: trackerRef.id,
          trackerName: tracker.name,
          trackerType: tracker.type,
          date: current,
          type: 'completion',
        );
        batch.set(historyRef, historyRecord.toMap());
        
        current = current.add(const Duration(days: 1));
      }
    }
    
    final updatedTracker = TrackerModel(
      id: trackerRef.id,
      userId: tracker.userId,
      name: tracker.name,
      type: tracker.type,
      durationType: tracker.durationType,
      measurementUnit: tracker.measurementUnit,
      durationValue: tracker.durationValue,
      startDate: start,
      endDate: tracker.endDate,
      createdAt: tracker.createdAt,
      completedDates: completedDates,
      originalStartDate: originalStart,
    );
    
    batch.set(trackerRef, updatedTracker.toMap());
    await batch.commit();
  }

  // Delete an existing tracker and its associated history records
  Future<void> deleteTracker(String userId, String trackerId) async {
    final batch = _firestore.batch();

    // 1. Delete the tracker document itself
    final trackerRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('trackers')
        .doc(trackerId);
    batch.delete(trackerRef);

    // 2. Fetch history records for this tracker
    final historySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('trackerId', isEqualTo: trackerId)
        .get();

    // 3. Add deletions of all history records to batch, handling Firestore batch limit of 500 operations
    int operationCount = 1; // 1 for the tracker deletion
    var currentBatch = batch;

    for (final doc in historySnapshot.docs) {
      if (operationCount >= 500) {
        // Commit current batch and start a new one
        await currentBatch.commit();
        currentBatch = _firestore.batch();
        operationCount = 0;
      }
      currentBatch.delete(doc.reference);
      operationCount++;
    }

    // Commit any remaining operations in the last batch
    if (operationCount > 0) {
      await currentBatch.commit();
    }
  }

  // Reset a tracker's starting time to now (recalculating the end date if it is set_time)
  Future<void> resetTracker(TrackerModel tracker) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? newEndDate;

    if (tracker.durationType == 'set_time' && tracker.durationValue != null) {
      switch (tracker.measurementUnit) {
        case 'weeks':
          newEndDate = today.add(Duration(days: tracker.durationValue! * 7));
          break;
        case 'months':
          newEndDate = DateTime(today.year, today.month + tracker.durationValue!, today.day);
          break;
        case 'days':
        default:
          newEndDate = today.add(Duration(days: tracker.durationValue!));
          break;
      }
    }

    await _firestore
        .collection('users')
        .doc(tracker.userId)
        .collection('trackers')
        .doc(tracker.id)
        .update({
      'startDate': Timestamp.fromDate(today),
      'endDate': newEndDate != null ? Timestamp.fromDate(newEndDate) : null,
    });
  }

  // Mark a tracker as completed by appending the current date/time to completedDates and writing history
  Future<void> markTrackerCompleted(TrackerModel tracker) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final updated = List<DateTime>.from(tracker.completedDates)..add(today);

    final batch = _firestore.batch();

    // 1. Update the tracker document
    final trackerRef = _firestore
        .collection('users')
        .doc(tracker.userId)
        .collection('trackers')
        .doc(tracker.id);
    batch.update(trackerRef, {
      'completedDates': updated.map((d) => Timestamp.fromDate(d)).toList(),
    });

    // 2. Add history record
    final historyRef = _firestore
        .collection('users')
        .doc(tracker.userId)
        .collection('history')
        .doc();
    final historyRecord = TrackerHistoryModel(
      id: '',
      trackerId: tracker.id,
      trackerName: tracker.name,
      trackerType: tracker.type,
      date: today,
      type: 'completion',
    );
    batch.set(historyRef, historyRecord.toMap());

    await batch.commit();
  }

  // Auto-reset a tracker to a specific startDate when a period has been missed
  Future<void> autoResetTracker(TrackerModel tracker, DateTime newStartDate) async {
    final start = DateTime(newStartDate.year, newStartDate.month, newStartDate.day);
    DateTime? newEndDate;

    if (tracker.durationType == 'set_time' && tracker.durationValue != null) {
      switch (tracker.measurementUnit) {
        case 'weeks':
          newEndDate = start.add(Duration(days: tracker.durationValue! * 7));
          break;
        case 'months':
          newEndDate = DateTime(start.year, start.month + tracker.durationValue!, start.day);
          break;
        case 'days':
        default:
          newEndDate = start.add(Duration(days: tracker.durationValue!));
          break;
      }
    }

    await _firestore
        .collection('users')
        .doc(tracker.userId)
        .collection('trackers')
        .doc(tracker.id)
        .update({
      'startDate': Timestamp.fromDate(start),
      'endDate': newEndDate != null ? Timestamp.fromDate(newEndDate) : null,
    });
  }

  // Report a slip-up for a bad habit (type == 'quit')
  // This appends the current date/time to completedDates, resets the starting date/time to now, and logs to history
  Future<void> reportSlipUp(TrackerModel tracker) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final updatedCompleted = List<DateTime>.from(tracker.completedDates)..add(today);

    DateTime? newEndDate;
    if (tracker.durationType == 'set_time' && tracker.durationValue != null) {
      switch (tracker.measurementUnit) {
        case 'weeks':
          newEndDate = today.add(Duration(days: tracker.durationValue! * 7));
          break;
        case 'months':
          newEndDate = DateTime(today.year, today.month + tracker.durationValue!, today.day);
          break;
        case 'days':
        default:
          newEndDate = today.add(Duration(days: tracker.durationValue!));
          break;
      }
    }

    final batch = _firestore.batch();

    // 1. Update the tracker document
    final trackerRef = _firestore
        .collection('users')
        .doc(tracker.userId)
        .collection('trackers')
        .doc(tracker.id);
    batch.update(trackerRef, {
      'startDate': Timestamp.fromDate(today),
      'endDate': newEndDate != null ? Timestamp.fromDate(newEndDate) : null,
      'completedDates': updatedCompleted.map((d) => Timestamp.fromDate(d)).toList(),
    });

    // 2. Add history record
    final historyRef = _firestore
        .collection('users')
        .doc(tracker.userId)
        .collection('history')
        .doc();
    final historyRecord = TrackerHistoryModel(
      id: '',
      trackerId: tracker.id,
      trackerName: tracker.name,
      trackerType: tracker.type,
      date: today,
      type: 'slip_up',
    );
    batch.set(historyRef, historyRecord.toMap());

    await batch.commit();
  }

  // Get completions/slip-ups stream for a specific month to keep memory usage low
  Stream<List<TrackerHistoryModel>> getMonthlyHistory(String userId, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1).subtract(const Duration(microseconds: 1));

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TrackerHistoryModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
