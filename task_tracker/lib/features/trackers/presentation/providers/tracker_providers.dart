import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/features/tasks/presentation/providers/task_providers.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';

/// StreamProvider providing a live list of habit trackers for the current user.
final trackersStreamProvider =
    StreamProvider.autoDispose<List<TrackerModel>>((ref) {
      final userId = ref.watch(userIdProvider);
      if (userId == null) return const Stream.empty();
      return ref.watch(trackerRepositoryProvider).getTrackers(userId);
    });

/// StateProvider holding the active tracker filter ('all', 'maintain', 'quit').
final trackerFilterProvider = StateProvider<String>((ref) => 'all');

/// Computed selector provider returning filtered trackers based on active filter.
final filteredTrackersProvider =
    Provider.autoDispose<AsyncValue<List<TrackerModel>>>((ref) {
      final trackersAsync = ref.watch(trackersStreamProvider);
      final filter = ref.watch(trackerFilterProvider);

      return trackersAsync.whenData((trackers) {
        if (filter == 'all') return trackers;
        return trackers.where((t) => t.type == filter).toList();
      });
    });
