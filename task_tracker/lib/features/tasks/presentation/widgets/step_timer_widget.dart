import 'dart:async';
import 'package:flutter/material.dart';
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
  Timer? _timer;
  late int _secondsRemaining;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _initTimerState();
  }

  @override
  void didUpdateWidget(StepTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize timer if the step properties from parent change
    if (widget.step.timerStartedAt != oldWidget.step.timerStartedAt ||
        widget.step.timerPausedAt != oldWidget.step.timerPausedAt ||
        widget.step.timerSecondsRemaining !=
            oldWidget.step.timerSecondsRemaining ||
        widget.step.timerDuration != oldWidget.step.timerDuration) {
      _initTimerState();
    }
  }

  void _initTimerState() {
    _timer?.cancel();
    _secondsRemaining = widget.step.getSecondsRemaining();
    _isExpired = widget.step.isTimerExpired() || _secondsRemaining <= 0;

    if (widget.step.isTimerRunning() && !_isExpired) {
      _startLocalTimer();
    }
  }

  void _startLocalTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        final rem = widget.step.getSecondsRemaining();
        _secondsRemaining = rem;
        if (_secondsRemaining <= 0) {
          _isExpired = true;
          _timer?.cancel();
          // Update database state when timer expires
          _triggerTimerExpiration();
        }
      });
    });
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
    _timer?.cancel();
    final duration = widget.step.timerDuration ?? 0;
    await _updateCurrentStep(
      (step) => step.copyWith(
        clearTimerStartedAt: true,
        clearTimerPausedAt: true,
        timerSecondsRemaining: step.timerDuration,
        isTimerConfirmed: false,
      ),
    );

    if (mounted) {
      setState(() {
        _secondsRemaining = duration;
        _isExpired = false;
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRunning = widget.step.isTimerRunning();

    if (_isExpired && !widget.step.isCompleted) {
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
          _formatDuration(_secondsRemaining),
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
