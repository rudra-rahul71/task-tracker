import 'package:flutter/material.dart';
import 'package:task_tracker/core/utils/snackbar.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_step.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/step_timer_widget.dart';

class TaskCard extends StatefulWidget {
  final TaskModel task;
  final List<TaskGroupModel> groups;
  final TaskRepository repository;
  final bool isInteractive;
  final bool showCompletionStatus;

  const TaskCard({
    super.key,
    required this.task,
    required this.groups,
    required this.repository,
    this.isInteractive = true,
    this.showCompletionStatus = true,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isExpanded = false;

  final List<String> _daysOfWeekNames = const [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  TaskGroupModel? _getGroup() {
    if (widget.task.groupId == null) return null;
    return widget.groups.firstWhere(
      (g) => g.id == widget.task.groupId,
      orElse: () => TaskGroupModel(
        id: '',
        userId: '',
        name: 'Unknown',
        colorValue: 0xFF9E9E9E,
        createdAt: DateTime.now(),
      ),
    );
  }

  String _getScheduleText() {
    // If task has individual schedule
    if (widget.task.schedule != null && widget.task.schedule!.type != 'none') {
      return _formatSchedule(widget.task.schedule!);
    }
    // Else, check inherited group schedule
    final group = _getGroup();
    if (group != null && group.schedule != null && group.schedule!.type != 'none') {
      return '${group.schedule!.type.replaceAll('_', ' ').toUpperCase()} (Inherited)';
    }
    return 'One-off Task';
  }

  String _formatSchedule(dynamic schedule) {
    if (schedule.type == 'weekly') {
      final days = (schedule.daysOfWeek as List<int>)
          .map((d) => _daysOfWeekNames[d - 1])
          .join(', ');
      return 'Weekly on $days';
    }
    if (schedule.type == 'bi_weekly') {
      final days = (schedule.daysOfWeek as List<int>)
          .map((d) => _daysOfWeekNames[d - 1])
          .join(', ');
      return 'Every other week: $days';
    }
    if (schedule.type == 'monthly') {
      return 'Monthly on Day ${schedule.dayOfMonth}';
    }
    return 'None';
  }

  void _toggleStepCompletion(int index, bool isCompleted) async {
    final updatedSteps = List<TaskStep>.from(widget.task.steps);
    final currentStep = updatedSteps[index];
    // When marking complete, cancel timers
    updatedSteps[index] = currentStep.copyWith(
      isCompleted: isCompleted,
      clearTimerStartedAt: true,
      clearTimerPausedAt: true,
      timerSecondsRemaining: isCompleted ? 0 : currentStep.timerDuration,
      isTimerConfirmed: isCompleted,
    );
    String newStatus = widget.task.status;
    if (!isCompleted && widget.task.status == 'completed') {
      newStatus = 'pending';
    }

    final updatedTask = widget.task.copyWith(
      steps: updatedSteps,
      status: newStatus,
    );
    await widget.repository.updateTask(updatedTask);
  }

  void _resetTask() async {
    final resetSteps = widget.task.steps.map((step) {
      return step.copyWith(
        isCompleted: false,
        timerStartedAt: null,
        timerPausedAt: null,
        timerSecondsRemaining: step.timerDuration,
        isTimerConfirmed: false,
      );
    }).toList();

    final updatedTask = widget.task.copyWith(
      steps: resetSteps,
      status: 'pending',
    );

    try {
      await widget.repository.updateTask(updatedTask);
      if (mounted) {
        SnackbarService(context).showSuccessSnackbar(
          message: 'Task "${widget.task.name}" checklist reset.',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarService(context).showErrorSnackbar(
          message: 'Failed to reset task: $e',
        );
      }
    }
  }

  void _completeTask() async {
    if (!widget.task.isAllStepsCompleted) return;

    final updatedTask = widget.task.copyWith(
      status: 'completed',
      lastCompletedAt: DateTime.now(),
    );

    try {
      await widget.repository.updateTask(updatedTask);
      if (mounted) {
        SnackbarService(context).showSuccessSnackbar(
          message: '🏆 Task "${widget.task.name}" completed!',
        );
      }
      setState(() {
        _isExpanded = false;
      });
    } catch (e) {
      if (mounted) {
        SnackbarService(context).showErrorSnackbar(
          message: 'Failed to complete task: $e',
        );
      }
    }
  }

  void _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Task?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${widget.task.name}"?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.repository.deleteTask(widget.task.userId, widget.task.id);
        if (mounted) {
          SnackbarService(context).showSuccessSnackbar(message: 'Task deleted');
        }
      } catch (e) {
        if (mounted) {
          SnackbarService(context).showErrorSnackbar(message: 'Failed to delete task: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _getGroup();
    final color = group != null ? Color(group.colorValue) : Theme.of(context).colorScheme.primary;
    final isCompleted = widget.showCompletionStatus && (widget.task.status == 'completed');

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withValues(alpha: isCompleted ? 0.05 : 0.15),
          width: 1.5,
        ),
      ),
      elevation: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isCompleted ? Colors.grey[700]! : color,
                width: 6,
              ),
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _isExpanded = expanded;
                });
              },
              tilePadding: const EdgeInsets.only(left: 16.0, right: 0.0),
              trailing: const SizedBox.shrink(),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.task.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? Colors.grey : Colors.white,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (widget.task.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.task.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.isInteractive) ...[
                        if (isCompleted) ...[
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
                            tooltip: 'Reset Task',
                            onPressed: _resetTask,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.check_circle, color: Colors.grey, size: 24),
                        ] else ...[
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.grey, size: 18),
                            tooltip: 'Reset Checklist',
                            onPressed: _resetTask,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                            onPressed: _deleteTask,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                          onPressed: _deleteTask,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            // Group Tag
                            if (group != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  group.name,
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),

                            // Schedule Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getScheduleText(),
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        if (widget.showCompletionStatus) ...[
                          const SizedBox(height: 12),
                          // Steps progress text and bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${widget.task.steps.where((s) => s.isCompleted).length}/${widget.task.steps.length} steps completed',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(widget.task.progress * 100).toInt()}%',
                                style: TextStyle(color: isCompleted ? Colors.grey : color, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: widget.task.progress,
                            backgroundColor: Colors.grey[800],
                            valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.grey : color),
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 6,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              children: [
                const Divider(height: 1, color: Colors.grey),
                Container(
                  color: const Color(0xFF161616),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checklist Steps',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      
                      // Checklist items list
                      ...List.generate(widget.task.steps.length, (index) {
                        final step = widget.task.steps[index];
                        final isStepCompleted = widget.showCompletionStatus && step.isCompleted;

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final hasTimer = widget.isInteractive && step.timerDuration != null && !isStepCompleted;

                            bool fitsOnOneLine = true;
                            if (hasTimer) {
                              final isTimerExpired = step.isTimerExpired() || step.getSecondsRemaining() <= 0;
                              final timerWidth = isTimerExpired ? 250.0 : 134.0;
                              final checkboxWidth = widget.showCompletionStatus ? 36.0 : 44.0;
                              final textWidth = step.name.length * 8.5;
                              final totalEstimatedWidth = checkboxWidth + textWidth + timerWidth + 16.0;
                              fitsOnOneLine = totalEstimatedWidth <= constraints.maxWidth;
                            }

                            if (fitsOnOneLine) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (widget.showCompletionStatus)
                                      Checkbox(
                                        value: isStepCompleted,
                                        activeColor: color,
                                        checkColor: Colors.black,
                                        onChanged: widget.isInteractive
                                            ? (val) => _toggleStepCompletion(index, val!)
                                            : null,
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.only(left: 12.0, right: 16.0),
                                        child: Icon(Icons.fiber_manual_record, size: 8, color: color),
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        step.name,
                                        style: TextStyle(
                                          color: isStepCompleted ? Colors.grey : Colors.white,
                                          decoration: isStepCompleted ? TextDecoration.lineThrough : null,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (hasTimer) ...[
                                      const SizedBox(width: 8),
                                      StepTimerWidget(
                                        task: widget.task,
                                        stepIndex: index,
                                        step: step,
                                        repository: widget.repository,
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        if (widget.showCompletionStatus)
                                          Checkbox(
                                            value: isStepCompleted,
                                            activeColor: color,
                                            checkColor: Colors.black,
                                            onChanged: widget.isInteractive
                                                ? (val) => _toggleStepCompletion(index, val!)
                                                : null,
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          )
                                        else
                                          Padding(
                                            padding: const EdgeInsets.only(left: 12.0, right: 16.0),
                                            child: Icon(Icons.fiber_manual_record, size: 8, color: color),
                                          ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            step.name,
                                            style: TextStyle(
                                              color: isStepCompleted ? Colors.grey : Colors.white,
                                              decoration: isStepCompleted ? TextDecoration.lineThrough : null,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasTimer) ...[
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: widget.showCompletionStatus ? 36.0 : 44.0,
                                        ),
                                        child: StepTimerWidget(
                                          task: widget.task,
                                          stepIndex: index,
                                          step: step,
                                          repository: widget.repository,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }
                          },
                        );
                      }),
                      
                      // Action buttons
                      if (widget.isInteractive) ...[
                        if (!isCompleted) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.task.isAllStepsCompleted
                                    ? color
                                    : Colors.grey[800],
                                foregroundColor: widget.task.isAllStepsCompleted
                                    ? Colors.black
                                    : Colors.grey[500],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: widget.task.isAllStepsCompleted
                                  ? _completeTask
                                  : null,
                              icon: const Icon(Icons.done_all, size: 20),
                              label: const Text(
                                'Complete Task',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color.withValues(alpha: 0.15),
                                foregroundColor: color,
                                side: BorderSide(color: color.withValues(alpha: 0.3)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _resetTask,
                              icon: const Icon(Icons.refresh, size: 20),
                              label: const Text(
                                'Reset / Restart Task',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
