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
        widget.step.timerSecondsRemaining != oldWidget.step.timerSecondsRemaining) {
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
          // Update Firestore state when timer expires
          _triggerExpirationInFirestore();
        }
      });
    });
  }

  void _triggerExpirationInFirestore() async {
    // Avoid double updates
    if (widget.step.timerPausedAt == null && widget.step.timerSecondsRemaining == 0) return;

    final updatedSteps = List<TaskStep>.from(widget.task.steps);
    final currentStep = updatedSteps[widget.stepIndex];
    
    updatedSteps[widget.stepIndex] = currentStep.copyWith(
      timerSecondsRemaining: 0,
      clearTimerPausedAt: true,
    );

    final updatedTask = widget.task.copyWith(steps: updatedSteps);
    await widget.repository.updateTask(updatedTask);
  }

  void _toggleTimer() async {
    final updatedSteps = List<TaskStep>.from(widget.task.steps);
    final currentStep = updatedSteps[widget.stepIndex];
    final isRunning = currentStep.isTimerRunning();
    final now = DateTime.now();

    TaskStep newStep;
    if (isRunning) {
      // Pause: Save current remaining seconds and clear startedAt
      final rem = currentStep.getSecondsRemaining();
      newStep = currentStep.copyWith(
        timerSecondsRemaining: rem,
        clearTimerStartedAt: true,
        timerPausedAt: now,
      );
    } else {
      // Resume/Start: Set startedAt to now, carry over previous remaining, clear pausedAt
      final rem = currentStep.timerSecondsRemaining ?? currentStep.timerDuration ?? 600;
      newStep = currentStep.copyWith(
        timerStartedAt: now,
        clearTimerPausedAt: true,
        timerSecondsRemaining: rem,
      );
    }

    updatedSteps[widget.stepIndex] = newStep;
    final updatedTask = widget.task.copyWith(steps: updatedSteps);
    await widget.repository.updateTask(updatedTask);
  }

  void _extendTimer() async {
    final updatedSteps = List<TaskStep>.from(widget.task.steps);
    final currentStep = updatedSteps[widget.stepIndex];
    
    // Add 5 minutes (300 seconds)
    const extendSec = 300;
    final currentRem = currentStep.getSecondsRemaining();
    final newRem = currentRem + extendSec;

    final newStep = currentStep.copyWith(
      timerStartedAt: DateTime.now(),
      clearTimerPausedAt: true,
      timerSecondsRemaining: newRem,
      timerDuration: (currentStep.timerDuration ?? 600) + extendSec,
      isTimerConfirmed: false,
    );

    updatedSteps[widget.stepIndex] = newStep;
    final updatedTask = widget.task.copyWith(steps: updatedSteps);
    await widget.repository.updateTask(updatedTask);
  }

  void _confirmComplete() async {
    final updatedSteps = List<TaskStep>.from(widget.task.steps);
    final currentStep = updatedSteps[widget.stepIndex];

    final newStep = currentStep.copyWith(
      isCompleted: true,
      isTimerConfirmed: true,
      clearTimerStartedAt: true,
      clearTimerPausedAt: true,
    );

    updatedSteps[widget.stepIndex] = newStep;
    final updatedTask = widget.task.copyWith(steps: updatedSteps);
    await widget.repository.updateTask(updatedTask);
  }

  void _restartTimer() async {
    _timer?.cancel();
    final updatedSteps = List<TaskStep>.from(widget.task.steps);
    final currentStep = updatedSteps[widget.stepIndex];

    final newStep = currentStep.copyWith(
      clearTimerStartedAt: true,
      clearTimerPausedAt: true,
      timerSecondsRemaining: currentStep.timerDuration,
      isTimerConfirmed: false,
    );

    updatedSteps[widget.stepIndex] = newStep;
    final updatedTask = widget.task.copyWith(steps: updatedSteps);
    await widget.repository.updateTask(updatedTask);
    
    if (mounted) {
      setState(() {
        _secondsRemaining = currentStep.timerDuration ?? 0;
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
    final isRunning = widget.step.isTimerRunning();

    if (_isExpired && !widget.step.isCompleted) {
      // Glow and display Extend / Confirm controls
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_off_outlined, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Timer Done!',
                  style: TextStyle(color: Colors.redAccent[100], fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.replay, color: Colors.redAccent[100], size: 18),
                  tooltip: 'Restart Timer',
                  onPressed: _restartTimer,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _extendTimer,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orangeAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('+5 min', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: _confirmComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isRunning ? Icons.hourglass_top_rounded : Icons.hourglass_empty_rounded,
          color: isRunning ? Theme.of(context).colorScheme.primary : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          _formatDuration(_secondsRemaining),
          style: TextStyle(
            color: isRunning ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier', // Monospaced look
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _toggleTimer,
          child: CircleAvatar(
            backgroundColor: isRunning
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.15),
            radius: 14,
            child: Icon(
              isRunning ? Icons.pause : Icons.play_arrow,
              color: isRunning ? Theme.of(context).colorScheme.primary : Colors.grey,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _restartTimer,
          child: CircleAvatar(
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            radius: 14,
            child: const Icon(
              Icons.replay,
              color: Colors.grey,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }
}
