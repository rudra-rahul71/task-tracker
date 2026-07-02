import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/models/tracker_history.dart';

class TrackerRepository {
  final DatabaseRepository _repo = GetIt.instance<DatabaseRepository>();

  late final _trackerCollection = TypedCollection<TrackerModel>(
    repo: _repo,
    collectionName: 'trackers',
    toMap: (tracker) => tracker.toMap(),
    fromMap: (map, id) => TrackerModel.fromMap(map, id),
  );

  late final _historyCollection = TypedCollection<TrackerHistoryModel>(
    repo: _repo,
    collectionName: 'tracker_history',
    toMap: (history) => history.toMap(),
    fromMap: (map, id) => TrackerHistoryModel.fromMap(map, id),
  );

  // Stream of trackers for a specific user, sorted by creation date
  Stream<List<TrackerModel>> getTrackers(String userId) {
    return _trackerCollection.watch(
      filters: [QueryFilter.eq('userId', userId)],
    ).map((trackers) {
      trackers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return trackers;
    });
  }

  // Add a new tracker and backfill completion entries if started in the past
  Future<void> addTracker(TrackerModel tracker) async {
    // Generate a temporary / fallback ID for tracker if empty, but library saveMap handles empty ID by adding.
    // However, to link history records, we need a tracker ID. Let's generate a unique string using DateTime.
    final trackerId = tracker.id.isNotEmpty ? tracker.id : 'tr_${DateTime.now().millisecondsSinceEpoch}';

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
        
        final historyRecord = TrackerHistoryModel(
          id: '',
          userId: tracker.userId,
          trackerId: trackerId,
          trackerName: tracker.name,
          trackerType: tracker.type,
          date: current,
          type: 'completion',
        );
        await _historyCollection.save(historyRecord, '');
        
        current = current.add(const Duration(days: 1));
      }
    }
    
    final updatedTracker = TrackerModel(
      id: trackerId,
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
    
    await _trackerCollection.save(updatedTracker, trackerId);
  }

  // Delete an existing tracker and its associated history records
  Future<void> deleteTracker(String userId, String trackerId) async {
    // 1. Delete the tracker document itself
    await _trackerCollection.delete(trackerId);

    // 2. Fetch and delete history records for this tracker
    try {
      final history = await _historyCollection.watch(
        filters: [QueryFilter.eq('trackerId', trackerId)],
      ).first;

      for (final doc in history) {
        await _historyCollection.delete(doc.id);
      }
    } catch (e) {
      debugPrint('Error deleting history records on tracker deletion: $e');
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

    final updated = TrackerModel(
      id: tracker.id,
      userId: tracker.userId,
      name: tracker.name,
      type: tracker.type,
      durationType: tracker.durationType,
      measurementUnit: tracker.measurementUnit,
      durationValue: tracker.durationValue,
      startDate: today,
      endDate: newEndDate,
      createdAt: tracker.createdAt,
      completedDates: tracker.completedDates,
      originalStartDate: tracker.originalStartDate,
    );

    await _trackerCollection.save(updated, tracker.id);
  }

  // Mark a tracker as completed by appending the current date/time to completedDates and writing history
  Future<void> markTrackerCompleted(TrackerModel tracker) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final updatedDates = List<DateTime>.from(tracker.completedDates)..add(today);

    final updatedTracker = TrackerModel(
      id: tracker.id,
      userId: tracker.userId,
      name: tracker.name,
      type: tracker.type,
      durationType: tracker.durationType,
      measurementUnit: tracker.measurementUnit,
      durationValue: tracker.durationValue,
      startDate: tracker.startDate,
      endDate: tracker.endDate,
      createdAt: tracker.createdAt,
      completedDates: updatedDates,
      originalStartDate: tracker.originalStartDate,
    );

    await _trackerCollection.save(updatedTracker, tracker.id);

    final historyRecord = TrackerHistoryModel(
      id: '',
      userId: tracker.userId,
      trackerId: tracker.id,
      trackerName: tracker.name,
      trackerType: tracker.type,
      date: today,
      type: 'completion',
    );
    await _historyCollection.save(historyRecord, '');
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

    final updatedTracker = TrackerModel(
      id: tracker.id,
      userId: tracker.userId,
      name: tracker.name,
      type: tracker.type,
      durationType: tracker.durationType,
      measurementUnit: tracker.measurementUnit,
      durationValue: tracker.durationValue,
      startDate: start,
      endDate: newEndDate,
      createdAt: tracker.createdAt,
      completedDates: tracker.completedDates,
      originalStartDate: tracker.originalStartDate,
    );

    await _trackerCollection.save(updatedTracker, tracker.id);
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

    final updatedTracker = TrackerModel(
      id: tracker.id,
      userId: tracker.userId,
      name: tracker.name,
      type: tracker.type,
      durationType: tracker.durationType,
      measurementUnit: tracker.measurementUnit,
      durationValue: tracker.durationValue,
      startDate: today,
      endDate: newEndDate,
      createdAt: tracker.createdAt,
      completedDates: updatedCompleted,
      originalStartDate: tracker.originalStartDate,
    );

    await _trackerCollection.save(updatedTracker, tracker.id);

    final historyRecord = TrackerHistoryModel(
      id: '',
      userId: tracker.userId,
      trackerId: tracker.id,
      trackerName: tracker.name,
      trackerType: tracker.type,
      date: today,
      type: 'slip_up',
    );
    await _historyCollection.save(historyRecord, '');
  }

  // Get completions/slip-ups stream for a specific month
  Stream<List<TrackerHistoryModel>> getMonthlyHistory(String userId, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1).subtract(const Duration(microseconds: 1));

    return _historyCollection.watch(
      filters: [QueryFilter.eq('userId', userId)],
    ).map((history) {
      // Filter date range client side for simplicity across database drivers
      return history.where((h) => h.date.isAfter(start.subtract(const Duration(microseconds: 1))) && h.date.isBefore(end.add(const Duration(microseconds: 1)))).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }
}
