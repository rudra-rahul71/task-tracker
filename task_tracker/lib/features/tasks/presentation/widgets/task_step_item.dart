import 'package:flutter/material.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_step.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';
import 'step_timer_widget.dart';

/// Single item row representing a checklist step within a task card, with optional timer.
class TaskStepItem extends StatelessWidget {
  final TaskModel task;
  final int stepIndex;
  final TaskStep step;
  final TaskRepository repository;
  final Color color;
  final bool isInteractive;
  final bool showCompletionStatus;
  final void Function(int index, bool isCompleted) onToggleStepCompletion;

  const TaskStepItem({
    super.key,
    required this.task,
    required this.stepIndex,
    required this.step,
    required this.repository,
    required this.color,
    required this.isInteractive,
    required this.showCompletionStatus,
    required this.onToggleStepCompletion,
  });

  Widget _buildLeading(BuildContext context, bool isStepCompleted) {
    final colorScheme = Theme.of(context).colorScheme;
    if (showCompletionStatus) {
      return Checkbox(
        value: isStepCompleted,
        activeColor: color,
        checkColor: colorScheme.onPrimary,
        onChanged: isInteractive
            ? (val) => onToggleStepCompletion(stepIndex, val ?? false)
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

  Widget _buildTitle(BuildContext context, bool isStepCompleted) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Text(
        step.name,
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

  @override
  Widget build(BuildContext context) {
    final isStepCompleted = showCompletionStatus && step.isCompleted;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasTimer = isInteractive &&
            step.timerDuration != null &&
            !isStepCompleted;

        bool fitsOnOneLine = true;
        if (hasTimer) {
          const timerWidth = 134.0;
          final checkboxWidth = showCompletionStatus ? 36.0 : 44.0;
          final textWidth = step.name.length * 8.5;
          final totalEstimatedWidth = checkboxWidth + textWidth + timerWidth + 16.0;
          fitsOnOneLine = totalEstimatedWidth <= constraints.maxWidth;
        }

        final leadingWidget = _buildLeading(context, isStepCompleted);
        final titleWidget = _buildTitle(context, isStepCompleted);
        final timerWidget = StepTimerWidget(
          task: task,
          stepIndex: stepIndex,
          step: step,
          repository: repository,
        );

        if (fitsOnOneLine) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
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
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                      left: showCompletionStatus ? 36.0 : 44.0,
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
  }
}
