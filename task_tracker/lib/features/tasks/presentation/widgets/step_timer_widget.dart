import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_backend_bridge/src/providers/core_providers.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_step.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';

class StepTimerWidget extends ConsumerStatefulWidget {
  final TaskModel task;
  final int stepIndex;
  final TaskStep step;
  final TaskRepository repository;

  const StepTimerWidget({
    super.key,
    required this.task,
    required this.stepIndex,
    required this.step,
    required this.repository,
  });

  @override
  ConsumerState<StepTimerWidget> createState() => _StepTimerWidgetState();
}

class _StepTimerWidgetState extends ConsumerState<StepTimerWidget> {
  int get _notificationId => ('${widget.task.id}_${widget.stepIndex}').hashCode;

  void _scheduleDeviceNotification(int seconds) {
    if (seconds <= 0) return;
    try {
      ref
          .read(notificationServiceProvider)
          .scheduleNotification(
            id: _notificationId,
            title: 'Timer Complete!',
            body:
                'Timer for "${widget.step.name}" in task "${widget.task.name}" has finished.',
            duration: Duration(seconds: seconds),
          );
    } catch (_) {}
  }

  void _cancelDeviceNotification() {
    try {
      ref.read(notificationServiceProvider).cancelNotification(_notificationId);
    } catch (_) {}
  }

  Future<void> _updateCurrentStep(
    TaskStep Function(TaskStep step) transform,
  ) async {
    final updatedSteps = List<TaskStep>.from(widget.task.steps);
    updatedSteps[widget.stepIndex] = transform(updatedSteps[widget.stepIndex]);
    final updatedTask = widget.task.copyWith(steps: updatedSteps);
    await widget.repository.updateTask(
      updatedTask,
      oldStatus: widget.task.status,
    );
  }

  void _triggerTimerExpiration() async {
    // Avoid double updates
    if (widget.step.timerPausedAt == null &&
        widget.step.timerSecondsRemaining == 0) {
      return;
    }
    await _updateCurrentStep(
      (step) =>
          step.copyWith(timerSecondsRemaining: 0, clearTimerPausedAt: true),
    );
  }

  void _toggleTimer() async {
    final isRunning = widget.step.isTimerRunning();
    final now = DateTime.now();

    if (isRunning) {
      _cancelDeviceNotification();
    } else {
      final rem =
          widget.step.timerSecondsRemaining ?? widget.step.timerDuration ?? 600;
      _scheduleDeviceNotification(rem);
    }

    await _updateCurrentStep((step) {
      if (isRunning) {
        return step.copyWith(
          timerSecondsRemaining: step.getSecondsRemaining(),
          clearTimerStartedAt: true,
          timerPausedAt: now,
        );
      }
      final rem = step.timerSecondsRemaining ?? step.timerDuration ?? 600;
      return step.copyWith(
        timerStartedAt: now,
        clearTimerPausedAt: true,
        timerSecondsRemaining: rem,
      );
    });
  }

  void _extendTimer() async {
    const extendSec = 300;
    final currentRem = widget.step.getSecondsRemaining();
    final newRem = currentRem + extendSec;
    _scheduleDeviceNotification(newRem);

    await _updateCurrentStep((step) {
      final currentRem = step.getSecondsRemaining();
      return step.copyWith(
        timerStartedAt: DateTime.now(),
        clearTimerPausedAt: true,
        timerSecondsRemaining: currentRem + extendSec,
        timerDuration: (step.timerDuration ?? 600) + extendSec,
        isTimerConfirmed: false,
      );
    });
  }

  void _restartTimer() async {
    _cancelDeviceNotification();
    await _updateCurrentStep(
      (step) => step.copyWith(
        clearTimerStartedAt: true,
        clearTimerPausedAt: true,
        timerSecondsRemaining: step.timerDuration,
        isTimerConfirmed: false,
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = widget.step.isTimerRunning();

    if (!isRunning) {
      final secondsRemaining = widget.step.getSecondsRemaining();
      final isExpired =
          (widget.step.isTimerExpired() || secondsRemaining <= 0) &&
          (widget.step.timerStartedAt != null ||
              (widget.step.timerSecondsRemaining == 0 &&
                  widget.step.timerDuration != null));
      return _buildContent(
        context,
        secondsRemaining,
        isRunning: false,
        isExpired: isExpired,
      );
    }

    return StreamBuilder<int>(
      key: ValueKey(
        '${widget.task.id}_${widget.stepIndex}_${widget.step.timerStartedAt}',
      ),
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) => widget.step.getSecondsRemaining(),
      ),
      initialData: widget.step.getSecondsRemaining(),
      builder: (context, snapshot) {
        final secondsRemaining =
            snapshot.data ?? widget.step.getSecondsRemaining();
        final isExpired = secondsRemaining <= 0;

        if (isExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerTimerExpiration();
          });
        }

        return _buildContent(
          context,
          secondsRemaining,
          isRunning: true,
          isExpired: isExpired,
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    int secondsRemaining, {
    required bool isRunning,
    required bool isExpired,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final showExpiredState = isExpired && !widget.step.isCompleted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          showExpiredState
              ? Icons.hourglass_bottom_rounded
              : (isRunning
                    ? (secondsRemaining % 2 == 0
                          ? Icons.hourglass_top_rounded
                          : Icons.hourglass_bottom_rounded)
                    : Icons.hourglass_empty_rounded),
          color: showExpiredState
              ? colorScheme.error
              : (isRunning
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant),
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          _formatDuration(secondsRemaining),
          style: TextStyle(
            color: showExpiredState
                ? colorScheme.error
                : (isRunning
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant),
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier', // Monospaced look
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: showExpiredState
              ? '+5 min'
              : (isRunning ? 'Pause' : 'Start'),
          child: GestureDetector(
            onTap: showExpiredState ? _extendTimer : _toggleTimer,
            child: CircleAvatar(
              backgroundColor: showExpiredState
                  ? colorScheme.secondary.withValues(alpha: 0.15)
                  : (isRunning
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
              radius: 14,
              child: Icon(
                showExpiredState
                    ? Icons.timer_outlined
                    : (isRunning ? Icons.pause : Icons.play_arrow),
                color: showExpiredState
                    ? colorScheme.secondary
                    : (isRunning
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant),
                size: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Restart',
          child: GestureDetector(
            onTap: _restartTimer,
            child: CircleAvatar(
              backgroundColor: colorScheme.onSurfaceVariant.withValues(
                alpha: 0.1,
              ),
              radius: 14,
              child: Icon(
                Icons.replay,
                color: colorScheme.onSurfaceVariant,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
