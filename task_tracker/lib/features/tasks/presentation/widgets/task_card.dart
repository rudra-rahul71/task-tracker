import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:dynamic_backend_bridge/src/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_step.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/add_task_dialog.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/step_timer_widget.dart';

class TaskCard extends ConsumerStatefulWidget {
  final TaskModel task;
  final List<TaskGroupModel> groups;
  final TaskRepository repository;
  final bool isInteractive;
  final bool showCompletionStatus;
  final bool showEditAction;
  final bool showDeleteAction;

  const TaskCard({
    super.key,
    required this.task,
    required this.groups,
    required this.repository,
    this.isInteractive = true,
    this.showCompletionStatus = true,
    this.showEditAction = true,
    this.showDeleteAction = true,
  });

  @override
  ConsumerState<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<TaskCard> {
  bool _isExpanded = false;

  final List<String> _daysOfWeekNames = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  TaskGroupModel? _getGroup() {
    if (widget.task.groupId == null) return null;
    for (final g in widget.groups) {
      if (g.id == widget.task.groupId) return g;
    }
    return null;
  }

  Widget _buildActionIconButton({
    required VoidCallback onTap,
    required String tooltip,
    required IconData icon,
    required Color color,
    double size = 20,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildReminderBadge(DateTime notificationTime, ColorScheme colorScheme) {
    final timeOfDay = TimeOfDay.fromDateTime(notificationTime);
    final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
    final formattedTime = '$hour:$minute $period';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_active,
            size: 13,
            color: Color(0xFFD4AF37),
          ),
          const SizedBox(width: 4),
          Text(
            formattedTime,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLeading(
    int index,
    bool isStepCompleted,
    Color color,
    ColorScheme colorScheme,
  ) {
    if (widget.showCompletionStatus) {
      return Checkbox(
        value: isStepCompleted,
        activeColor: color,
        checkColor: colorScheme.onPrimary,
        onChanged: widget.isInteractive
            ? (val) => _toggleStepCompletion(index, val!)
            : null,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 16.0),
      child: Icon(Icons.fiber_manual_record, size: 8, color: color),
    );
  }

  Widget _buildStepTitle(
    String name,
    bool isStepCompleted,
    ColorScheme colorScheme,
  ) {
    return Expanded(
      child: Text(
        name,
        style: TextStyle(
          color: isStepCompleted
              ? colorScheme.onSurfaceVariant
              : colorScheme.onSurface,
          decoration: isStepCompleted ? TextDecoration.lineThrough : null,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFullWidthButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    BorderSide? side,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
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
    if (group != null &&
        group.schedule != null &&
        group.schedule!.type != 'none') {
      return '${group.schedule!.type.replaceAll('_', ' ').toUpperCase()} (Inherited)';
    }
    return 'One-off Task';
  }

  String _formatSchedule(dynamic schedule) {
    if (schedule.type == 'daily') {
      return 'Daily';
    }
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

    // Cancel pending notification for this step if checked complete
    if (isCompleted) {
      final notifId = ('${widget.task.id}_$index').hashCode;
      try {
        ref.read(notificationServiceProvider).cancelNotification(notifId);
      } catch (_) {}
    }

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
    await widget.repository.updateTask(
      updatedTask,
      oldStatus: widget.task.status,
    );
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
      await widget.repository.updateTask(
        updatedTask,
        oldStatus: widget.task.status,
      );
      if (mounted) {
        AppBannerService.showSuccess(
          context,
          'Task "${widget.task.name}" checklist reset.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppBannerService.showError(context, 'Failed to reset task: $e');
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
      await widget.repository.updateTask(
        updatedTask,
        oldStatus: widget.task.status,
      );
      if (mounted) {
        AppBannerService.showSuccess(
          context,
          'Task "${widget.task.name}" completed!',
        );
      }
      setState(() {
        _isExpanded = false;
      });
    } catch (e) {
      if (mounted) {
        AppBannerService.showError(context, 'Failed to complete task: $e');
      }
    }
  }

  void _deleteTask() async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Delete Task?',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.task.name}"?',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
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
          AppBannerService.showSuccess(context, 'Task deleted');
        }
      } catch (e) {
        if (mounted) {
          AppBannerService.showError(context, 'Failed to delete task: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final group = _getGroup();
    final color = group != null ? Color(group.colorValue) : colorScheme.primary;
    final isCompleted =
        widget.showCompletionStatus && (widget.task.status == 'completed');

    return Card(
      color: colorScheme.surface,
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
                color: isCompleted ? colorScheme.outline : color,
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double nameWidth = widget.task.name.length * 11.0;
                      double actionsWidth = 32.0; // chevron (with padding)

                      final bool hasAnyProgress =
                          isCompleted ||
                          widget.task.steps.any((s) => s.isCompleted);
                      final bool showResetAction =
                          widget.isInteractive && hasAnyProgress;

                      if (showResetAction) {
                        actionsWidth += 32.0; // refresh button
                      }

                      if (widget.showEditAction &&
                          !widget.showCompletionStatus &&
                          !isCompleted) {
                        actionsWidth += 32.0; // edit button
                      }

                      if (widget.showDeleteAction &&
                          (!widget.isInteractive || !isCompleted)) {
                        actionsWidth += 32.0; // delete button
                      }

                      final totalEstimatedWidth =
                          nameWidth + actionsWidth + 32.0;
                      final bool fitsOnOneLine =
                          totalEstimatedWidth <= constraints.maxWidth;

                      final Widget titleText = Text(
                        widget.task.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      );

                      final Widget descriptionText =
                          widget.task.description.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                widget.task.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : const SizedBox.shrink();

                      final Widget actionsAndChevron = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showResetAction)
                            _buildActionIconButton(
                              onTap: _resetTask,
                              tooltip: isCompleted
                                  ? 'Reset Task'
                                  : 'Reset Checklist',
                              icon: Icons.refresh,
                              color: colorScheme.onSurfaceVariant,
                              size: isCompleted ? 20 : 18,
                            ),
                          if (widget.showEditAction &&
                              !widget.showCompletionStatus &&
                              !isCompleted)
                            _buildActionIconButton(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      AddTaskDialog(task: widget.task),
                                );
                              },
                              tooltip: 'Edit Task',
                              icon: Icons.edit_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          if (widget.showDeleteAction &&
                              (!widget.isInteractive || !isCompleted))
                            _buildActionIconButton(
                              onTap: _deleteTask,
                              tooltip: 'Delete Task',
                              icon: Icons.delete_outline,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ),
                        ],
                      );

                      if (fitsOnOneLine) {
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [titleText, descriptionText],
                              ),
                            ),
                            const SizedBox(width: 16),
                            actionsAndChevron,
                          ],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleText,
                            descriptionText,
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [actionsAndChevron],
                            ),
                          ],
                        );
                      }
                    },
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
                            if (group != null)
                              _buildTagChip(
                                group.name,
                                color,
                                color.withValues(alpha: 0.15),
                              ),
                            _buildTagChip(
                              _getScheduleText(),
                              colorScheme.onSurfaceVariant,
                              colorScheme.onSurface.withValues(alpha: 0.05),
                            ),
                            if (widget.task.notificationTime != null)
                              _buildReminderBadge(
                                widget.task.notificationTime!,
                                colorScheme,
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
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(widget.task.progress * 100).toInt()}%',
                                style: TextStyle(
                                  color: isCompleted
                                      ? colorScheme.onSurfaceVariant
                                      : color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: widget.task.progress,
                            backgroundColor: colorScheme.onSurface.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCompleted
                                  ? colorScheme.onSurfaceVariant
                                  : color,
                            ),
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
                Divider(height: 1, color: colorScheme.outline),
                Container(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checklist Steps',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Checklist items list
                      ...List.generate(widget.task.steps.length, (index) {
                        final step = widget.task.steps[index];
                        final isStepCompleted =
                            widget.showCompletionStatus && step.isCompleted;

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final hasTimer =
                                widget.isInteractive &&
                                step.timerDuration != null &&
                                !isStepCompleted;

                            bool fitsOnOneLine = true;
                            if (hasTimer) {
                              const timerWidth = 134.0;
                              final checkboxWidth = widget.showCompletionStatus
                                  ? 36.0
                                  : 44.0;
                              final textWidth = step.name.length * 8.5;
                              final totalEstimatedWidth =
                                  checkboxWidth + textWidth + timerWidth + 16.0;
                              fitsOnOneLine =
                                  totalEstimatedWidth <= constraints.maxWidth;
                            }

                            final leadingWidget = _buildStepLeading(
                              index,
                              isStepCompleted,
                              color,
                              colorScheme,
                            );
                            final titleWidget = _buildStepTitle(
                              step.name,
                              isStepCompleted,
                              colorScheme,
                            );
                            final timerWidget = StepTimerWidget(
                              task: widget.task,
                              stepIndex: index,
                              step: step,
                              repository: widget.repository,
                            );

                            if (fitsOnOneLine) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    leadingWidget,
                                    const SizedBox(width: 8),
                                    titleWidget,
                                    if (hasTimer) ...[
                                      const SizedBox(width: 8),
                                      timerWidget,
                                    ],
                                  ],
                                ),
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        leadingWidget,
                                        const SizedBox(width: 8),
                                        titleWidget,
                                      ],
                                    ),
                                    if (hasTimer) ...[
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: widget.showCompletionStatus
                                              ? 36.0
                                              : 44.0,
                                        ),
                                        child: timerWidget,
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
                        const SizedBox(height: 16),
                        if (!isCompleted)
                          _buildFullWidthButton(
                            onPressed: widget.task.isAllStepsCompleted
                                ? _completeTask
                                : null,
                            icon: Icons.done_all,
                            label: 'Complete Task',
                            backgroundColor: widget.task.isAllStepsCompleted
                                ? color
                                : colorScheme.surfaceContainerHighest,
                            foregroundColor: widget.task.isAllStepsCompleted
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                          )
                        else
                          _buildFullWidthButton(
                            onPressed: _resetTask,
                            icon: Icons.refresh,
                            label: 'Reset / Restart Task',
                            backgroundColor: color.withValues(alpha: 0.15),
                            foregroundColor: color,
                            side: BorderSide(
                              color: color.withValues(alpha: 0.3),
                            ),
                          ),
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
