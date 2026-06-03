import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker/core/widgets/page_header.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/repositories/tracker_repository.dart';
import 'package:task_tracker/features/trackers/presentation/widgets/add_tracker_dialog.dart';
import 'package:task_tracker/features/trackers/presentation/widgets/tracker_card.dart';

class TrackersPage extends StatefulWidget {
  const TrackersPage({super.key});

  @override
  State<TrackersPage> createState() => _TrackersPageState();
}

class _TrackersPageState extends State<TrackersPage> {
  final TrackerRepository _repository = TrackerRepository();
  String _activeFilter = 'all'; // 'all', 'maintain', 'quit'
  String? _currentUserId;
  Stream<List<TrackerModel>>? _trackersStream;

  void _initStreamsForUser(String userId) {
    if (_currentUserId == userId && _trackersStream != null) {
      return;
    }
    _currentUserId = userId;
    _trackersStream = _repository.getTrackers(userId);
  }

  void _showAddTrackerDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddTrackerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    _initStreamsForUser(userId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              header: 'Trackers',
              sub: 'Monitor and build your habit streaks',
              action: ElevatedButton.icon(
                onPressed: () => _showAddTrackerDialog(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Choice chips for filtering
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All Trackers'),
                  selected: _activeFilter == 'all',
                  onSelected: (selected) {
                    if (selected) setState(() => _activeFilter = 'all');
                  },
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _activeFilter == 'all'
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Maintaining'),
                  selected: _activeFilter == 'maintain',
                  onSelected: (selected) {
                    if (selected) setState(() => _activeFilter = 'maintain');
                  },
                  selectedColor: const Color(0xFF26A69A).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _activeFilter == 'maintain'
                        ? const Color(0xFF26A69A)
                        : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Quitting'),
                  selected: _activeFilter == 'quit',
                  onSelected: (selected) {
                    if (selected) setState(() => _activeFilter = 'quit');
                  },
                  selectedColor: const Color(0xFFEF5350).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _activeFilter == 'quit'
                        ? const Color(0xFFEF5350)
                        : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Trackers StreamBuilder
            Expanded(
              child: StreamBuilder<List<TrackerModel>>(
                stream: _trackersStream!,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading trackers: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                      ),
                    );
                  }

                  final trackers = snapshot.data ?? [];
                  final filteredTrackers = trackers.where((t) {
                    if (_activeFilter == 'all') return true;
                    return t.type == _activeFilter;
                  }).toList();

                  if (filteredTrackers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.track_changes_outlined,
                            size: 64,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _activeFilter == 'all'
                                ? 'No habit trackers created yet'
                                : _activeFilter == 'maintain'
                                    ? 'No habits to maintain yet'
                                    : 'No habits to quit yet',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Add Tracker" in the top right to start tracking!',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // Responsive design layout
                  final width = MediaQuery.of(context).size.width;
                  if (width >= 850) {
                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 8,
                        mainAxisExtent: 190,
                      ),
                      itemCount: filteredTrackers.length,
                      itemBuilder: (context, index) {
                        return TrackerCard(tracker: filteredTrackers[index]);
                      },
                    );
                  } else {
                    return ListView.builder(
                      itemCount: filteredTrackers.length,
                      itemBuilder: (context, index) {
                        return TrackerCard(tracker: filteredTrackers[index]);
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
