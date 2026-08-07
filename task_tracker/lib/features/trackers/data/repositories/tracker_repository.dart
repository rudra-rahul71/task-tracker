import 'package:flutter/foundation.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:task_tracker/core/utils/date_parser.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/models/tracker_history.dart';

class TrackerRepository {
  final DatabaseRepository _repo;
  TrackerRepository(this._repo);

  TypedCollection<TrackerModel> get _trackerCollection =>
      TypedCollection<TrackerModel>(
        repo: _repo,
        collectionName: 'trackers',
        toMap: (tracker) => tracker.toMap(),
        fromMap: (map, id) => TrackerModel.fromMap(map, id),
      );

  TypedCollection<TrackerHistoryModel> get _historyCollection =>
      TypedCollection<TrackerHistoryModel>(
        repo: _repo,
        collectionName: 'tracker_history',
        toMap: (history) => history.toMap(),
        fromMap: (map, id) => TrackerHistoryModel.fromMap(map, id),
      );

  // Helper method to backfill completion entries for maintain habits started in the past
  (List<DateTime>, List<TrackerHistoryModel>) _backfillMaintainCompletions(
    TrackerModel tracker,
    String trackerId,
    DateTime today,
  ) {
    final completedDates = List<DateTime>.from(tracker.completedDates);
    final List<TrackerHistoryModel> backfilledHistory = [];

    if (tracker.type == 'maintain' && tracker.startDate.isBefore(today)) {
      DateTime current = tracker.startDate.dateOnly;
      while (current.isBefore(today)) {
        if (!completedDates.any((d) => d.isSameDay(current))) {
          completedDates.add(current);
          backfilledHistory.add(
            TrackerHistoryModel(
              id: '',
              userId: tracker.userId,
              trackerId: trackerId,
              trackerName: tracker.name,
              trackerType: tracker.type,
              date: current,
              type: 'completion',
            ),
          );
        }
        current = current.add(const Duration(days: 1));
      }
    }
    return (completedDates, backfilledHistory);
  }

  // Stream of trackers for a specific user, sorted by creation date
  Stream<List<TrackerModel>> getTrackers(String userId) {
    return _trackerCollection
        .watch(filters: [QueryFilter.eq('userId', userId)])
        .map((trackers) {
          trackers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return trackers;
        });
  }

  // Add a new tracker and backfill completion entries if started in the past
  Future<void> addTracker(TrackerModel tracker) async {
    final trackerId = tracker.id.isNotEmpty
        ? tracker.id
        : 'tr_${DateTime.now().millisecondsSinceEpoch}';
    final today = DateTime.now().dateOnly;

    final (completedDates, backfilledHistory) = _backfillMaintainCompletions(
      tracker,
      trackerId,
      today,
    );

    final updatedTracker = tracker.copyWith(
      id: trackerId,
      startDate: tracker.startDate.dateOnly,
      originalStartDate: tracker.originalStartDate.dateOnly,
      completedDates: completedDates,
    );

    // Save tracker first so foreign key constraint in tracker_history (trackerId -> trackers.id) is satisfied
    await _trackerCollection.save(updatedTracker, trackerId);

    // Save backfilled history records after the tracker exists in the database
    for (final historyRecord in backfilledHistory) {
      await _historyCollection.save(historyRecord, '');
    }
  }

  // Update an existing tracker
  Future<void> updateTracker(TrackerModel tracker) async {
    final today = DateTime.now().dateOnly;
    final (completedDates, backfilledHistory) = _backfillMaintainCompletions(
      tracker,
      tracker.id,
      today,
    );

    final updatedTracker = tracker.copyWith(completedDates: completedDates);

    await _trackerCollection.save(updatedTracker, updatedTracker.id);

    // Save backfilled history records
    for (final historyRecord in backfilledHistory) {
      await _historyCollection.save(historyRecord, '');
    }
  }

  // Delete an existing tracker and its associated history records
  Future<void> deleteTracker(String userId, String trackerId) async {
    // 1. Delete the tracker document itself
    await _trackerCollection.delete(trackerId);

    // 2. Fetch and delete history records for this tracker
    try {
      final history = await _historyCollection.fetch(
        filters: [QueryFilter.eq('trackerId', trackerId)],
      );

      for (final doc in history) {
        await _historyCollection.delete(doc.id);
      }
    } catch (e) {
      debugPrint('Error deleting history records on tracker deletion: $e');
    }
  }

  // Reset a tracker's starting time to now (recalculating the end date if it is set_time)
  Future<void> resetTracker(TrackerModel tracker) async {
    final today = DateTime.now().dateOnly;
    final updated = tracker.copyWith(
      startDate: today,
      endDate: tracker.calculateEndDate(today),
    );

    await _trackerCollection.save(updated, tracker.id);
  }

  // Mark a tracker as completed by appending the current date/time to completedDates and writing history
  Future<void> markTrackerCompleted(TrackerModel tracker) async {
    final today = DateTime.now().dateOnly;
    final updatedTracker = tracker.copyWith(
      completedDates: [...tracker.completedDates, today],
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
  Future<void> autoResetTracker(
    TrackerModel tracker,
    DateTime newStartDate,
  ) async {
    final start = newStartDate.dateOnly;
    final updatedTracker = tracker.copyWith(
      startDate: start,
      endDate: tracker.calculateEndDate(start),
    );

    await _trackerCollection.save(updatedTracker, tracker.id);
  }

  // Report a slip-up for a bad habit (type == 'quit')
  // This appends the current date/time to completedDates, resets the starting date/time to now, and logs to history
  Future<void> reportSlipUp(TrackerModel tracker) async {
    final today = DateTime.now().dateOnly;
    final updatedTracker = tracker.copyWith(
      startDate: today,
      endDate: tracker.calculateEndDate(today),
      completedDates: [...tracker.completedDates, today],
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
  Stream<List<TrackerHistoryModel>> getMonthlyHistory(
    String userId,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(
      month.year,
      month.month + 1,
      1,
    ).subtract(const Duration(microseconds: 1));

    return _historyCollection
        .watch(filters: [QueryFilter.eq('userId', userId)])
        .map((history) {
          // Filter date range client side for simplicity across database drivers
          return history
              .where(
                (h) =>
                    h.date.isAfter(
                      start.subtract(const Duration(microseconds: 1)),
                    ) &&
                    h.date.isBefore(end.add(const Duration(microseconds: 1))),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
        });
  }
}
