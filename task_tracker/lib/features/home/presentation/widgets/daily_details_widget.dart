import 'package:flutter/material.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/task_card.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';

class DailyDetailsWidget extends StatelessWidget {
  final DateTime selectedDay;
  final List<TrackerModel> completedTrackers;
  final List<TrackerModel> slippedTrackers;
  final List<TaskModel> completedTasks;
  final List<TaskModel> pendingTasks;
  final List<TaskGroupModel> groups;
  final bool isScrollable;
  final TaskRepository taskRepository;

  const DailyDetailsWidget({
    super.key,
    required this.selectedDay,
    required this.completedTrackers,
    required this.slippedTrackers,
    required this.completedTasks,
    required this.pendingTasks,
    required this.groups,
    required this.isScrollable,
    required this.taskRepository,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';

    final today = DateTime.now();
    final isSelectedDayToday =
        selectedDay.year == today.year &&
        selectedDay.month == today.month &&
        selectedDay.day == today.day;

    final listWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- TASKS SECTION ---
        const Text(
          'TODAY\'S TASKS',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        if (pendingTasks.isEmpty && completedTasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.assignment_outlined, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No tasks scheduled or completed on this day.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (pendingTasks.isNotEmpty) ...[
            const Text(
              'PENDING',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...pendingTasks.map((task) {
              final taskForCard = isSelectedDayToday
                  ? task
                  : task.copyWith(
                      status: 'pending',
                      steps: task.steps
                          .map(
                            (s) => s.copyWith(
                              isCompleted: false,
                              clearTimerStartedAt: true,
                              clearTimerPausedAt: true,
                              timerSecondsRemaining: s.timerDuration,
                              isTimerConfirmed: false,
                            ),
                          )
                          .toList(),
                    );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TaskCard(
                  task: taskForCard,
                  groups: groups,
                  repository: taskRepository,
                  isInteractive: isSelectedDayToday,
                  showCompletionStatus: isSelectedDayToday,
                  showEditAction: false,
                  showDeleteAction: false,
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
          if (completedTasks.isNotEmpty) ...[
            const Text(
              'COMPLETED',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...completedTasks.map((task) {
              final taskForCard = isSelectedDayToday
                  ? task
                  : task.copyWith(
                      status: 'completed',
                      steps: task.steps
                          .map((s) => s.copyWith(isCompleted: true))
                          .toList(),
                    );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TaskCard(
                  task: taskForCard,
                  groups: groups,
                  repository: taskRepository,
                  isInteractive: isSelectedDayToday,
                  showCompletionStatus: isSelectedDayToday,
                  showEditAction: false,
                  showDeleteAction: false,
                ),
              );
            }),
          ],
        ],

        const Divider(height: 32, thickness: 1, color: Colors.white10),

        // --- HABIT TRACKERS SECTION ---
        const Text(
          'SUCCESSFUL HABITS / CLEAN DAYS',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        if (completedTrackers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No habits completed or clean on this day.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
          )
        else
          ...completedTrackers.map((t) => _buildDetailItem(t, true)),

        if (slippedTrackers.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'SLIPPED UP / BROKEN HABITS',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ...slippedTrackers.map(
            (t) => _buildDetailItem(t, false, isSlip: true),
          ),
        ],
      ],
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Habits & tasks completion details',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const Divider(height: 32, thickness: 1, color: Colors.white10),

            if (isScrollable)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: listWidget,
                ),
              )
            else
              listWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    TrackerModel tracker,
    bool isCompleted, {
    bool isSlip = false,
  }) {
    final color = tracker.type == 'quit'
        ? const Color(0xFFEF5350)
        : const Color(0xFF26A69A);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSlip
              ? const Color(0xFFEF5350).withValues(alpha: 0.3)
              : isCompleted
              ? color.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isSlip
                      ? Icons.cancel_outlined
                      : isCompleted
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: isSlip
                      ? const Color(0xFFEF5350)
                      : isCompleted
                      ? color
                      : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tracker.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tracker.type == 'quit'
                  ? const Color(0xFFEF5350).withValues(alpha: 0.1)
                  : const Color(0xFF26A69A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tracker.type == 'quit' ? 'Quit' : 'Maintain',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
