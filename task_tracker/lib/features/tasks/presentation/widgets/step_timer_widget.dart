import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:get_it/get_it.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_step.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';

class StepTimerWidget extends StatefulWidget {
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
  State<StepTimerWidget> createState() => _StepTimerWidgetState();
}

class _StepTimerWidgetState extends State<StepTimerWidget> {
  int get _notificationId => ('${widget.task.id}_${widget.stepIndex}').hashCode;

  void _scheduleDeviceNotification(int seconds) {
    if (seconds <= 0) return;
    if (GetIt.I.isRegistered<NotificationService>()) {
      GetIt.I<NotificationService>().scheduleNotification(
        id: _notificationId,
        title: 'Timer Complete!',
        body:
            'Timer for "${widget.step.name}" in task "${widget.task.name}" has finished.',
        duration: Duration(seconds: seconds),
      );
    }
  }

  void _cancelDeviceNotification() {
    if (GetIt.I.isRegistered<NotificationService>()) {
      GetIt.I<NotificationService>().cancelNotification(_notificationId);
    }
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

    if (isExpired && !widget.step.isCompleted) {
      // Glow and display Extend / Confirm controls
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Timer Done!',
              child: Icon(
                Icons.timer_off_outlined,
                color: colorScheme.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.replay, color: colorScheme.error, size: 18),
              tooltip: 'Restart Timer',
              onPressed: _restartTimer,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.timer_outlined,
                color: colorScheme.secondary,
                size: 18,
              ),
              tooltip: '+5 min',
              onPressed: _extendTimer,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isRunning
              ? Icons.hourglass_top_rounded
              : Icons.hourglass_empty_rounded,
          color: isRunning ? colorScheme.primary : colorScheme.onSurfaceVariant,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          _formatDuration(secondsRemaining),
          style: TextStyle(
            color: isRunning
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier', // Monospaced look
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _toggleTimer,
          child: CircleAvatar(
            backgroundColor: isRunning
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
            radius: 14,
            child: Icon(
              isRunning ? Icons.pause : Icons.play_arrow,
              color: isRunning
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
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
      ],
    );
  }
}
