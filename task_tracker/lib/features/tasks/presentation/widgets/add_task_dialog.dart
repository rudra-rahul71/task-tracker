import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/core/widgets/loading_overlay.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_schedule.dart';
import 'package:task_tracker/features/tasks/data/models/task_step.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';
import 'package:task_tracker/features/tasks/presentation/providers/task_providers.dart';
import 'schedule_picker_section.dart';
import 'task_steps_editor.dart';

/// Modal dialog for creating and editing tasks with recurrence schedules and checklist steps.
class AddTaskDialog extends ConsumerStatefulWidget {
  final TaskModel? task;

  const AddTaskDialog({super.key, this.task});

  @override
  ConsumerState<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<AddTaskDialog> {
  TaskRepository get _repository => ref.read(taskRepositoryProvider);
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  String _description = '';
  String? _selectedGroupId;

  // Schedule settings
  String _scheduleSetting = 'none'; // 'none', 'inherit', 'custom'
  String _scheduleType = 'weekly'; // 'daily', 'weekly', 'bi_weekly', 'monthly'
  List<int> _selectedDays = [];
  int _dayOfMonth = 1;
  DateTime _startDate = DateTime.now();
  DateTime _targetDate = DateTime.now();

  // Checklist steps
  final List<Map<String, dynamic>> _stepsList = [
    {'name': '', 'hasTimer': false, 'minutes': 10},
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.task != null) {
      _name = widget.task!.name;
      _description = widget.task!.description;
      _selectedGroupId = widget.task!.groupId;

      if (widget.task!.schedule != null) {
        if (widget.task!.schedule!.type == 'none') {
          _scheduleSetting = 'none';
          _targetDate = widget.task!.schedule!.startDate ?? DateTime.now();
        } else {
          _scheduleSetting = 'custom';
          _scheduleType = widget.task!.schedule!.type;
          _selectedDays = List<int>.from(widget.task!.schedule!.daysOfWeek);
          _dayOfMonth = widget.task!.schedule!.dayOfMonth;
          _startDate = widget.task!.schedule!.startDate ?? DateTime.now();
        }
      } else if (widget.task!.groupId != null) {
        _scheduleSetting = 'inherit';
      }

      if (widget.task!.steps.isNotEmpty) {
        _stepsList.clear();
        for (var step in widget.task!.steps) {
          _stepsList.add({
            'name': step.name,
            'hasTimer': step.timerDuration != null,
            'minutes': step.timerDuration != null
                ? step.timerDuration! ~/ 60
                : 10,
          });
        }
      }
    }
  }

  InputDecoration _buildInputDecoration(
    ColorScheme colorScheme,
    String label, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary),
      ),
    );
  }

  void _addStepField() {
    setState(() {
      _stepsList.add({'name': '', 'hasTimer': false, 'minutes': 10});
    });
  }

  void _removeStepField(int index) {
    if (_stepsList.length <= 1) return;
    setState(() {
      _stepsList.removeAt(index);
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final userId = ref.read(userIdProvider);
    final navigator = Navigator.of(context);

    if (userId == null) {
      if (mounted) {
        AppBannerService.showError(context, 'Error: User not authenticated');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Resolve schedule
    TaskSchedule? taskSchedule;
    if (_scheduleSetting == 'custom') {
      taskSchedule = TaskSchedule(
        type: _scheduleType,
        daysOfWeek: (_scheduleType == 'monthly' || _scheduleType == 'daily')
            ? []
            : _selectedDays,
        dayOfMonth: _scheduleType == 'monthly' ? _dayOfMonth : 1,
        startDate: _scheduleType == 'bi_weekly' ? _startDate : null,
      );
    } else if (_scheduleSetting == 'none') {
      taskSchedule = TaskSchedule(type: 'none', startDate: _targetDate);
    }
    // Note: If scheduleSetting is 'inherit', task.schedule will remain null,
    // thereby letting the task inherit its group schedule during execution.

    final taskSteps = _stepsList.map((stepMap) {
      final stepName = stepMap['name'] as String;
      final hasTimer = stepMap['hasTimer'] as bool;
      final minutes = stepMap['minutes'] as int;
      final durationSeconds = hasTimer ? minutes * 60 : null;

      if (widget.task != null) {
        // Find existing step by name to preserve completion status if possible
        final existingStep = widget.task!.steps
            .where((s) => s.name == stepName)
            .firstOrNull;
        if (existingStep != null) {
          if (!hasTimer) {
            return TaskStep(
              name: stepName,
              isCompleted: existingStep.isCompleted,
            );
          }
          final isDurationChanged =
              existingStep.timerDuration != durationSeconds;
          return TaskStep(
            name: stepName,
            isCompleted: existingStep.isCompleted,
            timerDuration: durationSeconds,
            timerStartedAt: isDurationChanged
                ? null
                : existingStep.timerStartedAt,
            timerPausedAt: isDurationChanged
                ? null
                : existingStep.timerPausedAt,
            timerSecondsRemaining: isDurationChanged
                ? durationSeconds
                : (existingStep.timerSecondsRemaining ?? durationSeconds),
            isTimerConfirmed: isDurationChanged
                ? false
                : existingStep.isTimerConfirmed,
          );
        }
      }

      if (!hasTimer) {
        return TaskStep(name: stepName, isCompleted: false);
      }

      return TaskStep(
        name: stepName,
        isCompleted: false,
        timerDuration: durationSeconds,
        timerSecondsRemaining: durationSeconds,
      );
    }).toList();

    try {
      if (widget.task != null) {
        final updatedTask = TaskModel(
          id: widget.task!.id,
          userId: widget.task!.userId,
          groupId: _selectedGroupId,
          name: _name,
          description: _description,
          schedule: taskSchedule,
          steps: taskSteps,
          status: widget.task!.status,
          lastCompletedAt: widget.task!.lastCompletedAt,
          lastResetAt: widget.task!.lastResetAt,
          createdAt: widget.task!.createdAt,
        );
        await _repository.updateTask(
          updatedTask,
          oldStatus: widget.task!.status,
        );
        if (mounted) {
          AppBannerService.showSuccess(context, 'Task updated successfully');
        }
      } else {
        final newTask = TaskModel(
          id: '',
          userId: userId,
          groupId: _selectedGroupId,
          name: _name,
          description: _description,
          schedule: taskSchedule,
          steps: taskSteps,
          status: 'pending',
          createdAt: DateTime.now(),
        );
        await _repository.addTask(newTask);
        if (mounted) {
          AppBannerService.showSuccess(context, 'Task created successfully');
        }
      }
      navigator.pop();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        AppBannerService.showError(context, 'Failed to save task: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groups = ref.watch(taskGroupsProvider).value ?? [];

    final groupOptions = groups.map((g) {
      final hasGroupSched = g.schedule != null && g.schedule!.type != 'none';
      final schedText = hasGroupSched
          ? ' (${g.schedule!.type})'
          : ' (no schedule)';
      return DropdownMenuItem<String>(
        value: g.id,
        child: Text(
          g.name + schedText,
          style: TextStyle(color: colorScheme.onSurface),
        ),
      );
    }).toList();

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 750),
        child: LoadingOverlay(
          isLoading: _isLoading,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.task != null ? 'Edit Task' : 'Create Task',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Form contents
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Task Name
                          TextFormField(
                            initialValue: _name,
                            decoration: _buildInputDecoration(
                              colorScheme,
                              'Task Name',
                              hint: 'e.g. Do Laundry, Take Vitamins',
                            ),
                            style: TextStyle(color: colorScheme.onSurface),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Enter task name'
                                : null,
                            onSaved: (val) => _name = val!.trim(),
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            initialValue: _description,
                            decoration: _buildInputDecoration(
                              colorScheme,
                              'Description (Optional)',
                              hint: 'Add details or instructions...',
                            ),
                            style: TextStyle(color: colorScheme.onSurface),
                            maxLines: 2,
                            onSaved: (val) => _description = val?.trim() ?? '',
                          ),
                          const SizedBox(height: 16),

                          // Group Dropdown
                          DropdownButtonFormField<String>(
                            initialValue:
                                (_selectedGroupId != null &&
                                    groups.any(
                                      (g) => g.id == _selectedGroupId,
                                    ))
                                ? _selectedGroupId
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Task Group (Optional)',
                              labelStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.outline,
                                ),
                              ),
                            ),
                            dropdownColor: colorScheme.surface,
                            style: TextStyle(color: colorScheme.onSurface),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(
                                  'No Group',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              ...groupOptions,
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedGroupId = val;
                                if (_selectedGroupId != null) {
                                  final group = groups.firstWhere(
                                    (g) => g.id == _selectedGroupId,
                                  );
                                  if (group.schedule != null &&
                                      group.schedule!.type != 'none') {
                                    _scheduleSetting = 'inherit';
                                  } else {
                                    _scheduleSetting = 'none';
                                  }
                                } else {
                                  _scheduleSetting = 'none';
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Extracted Schedule Picker Section
                          SchedulePickerSection(
                            selectedGroupId: _selectedGroupId,
                            groups: groups,
                            scheduleSetting: _scheduleSetting,
                            onScheduleSettingChanged: (val) =>
                                setState(() => _scheduleSetting = val),
                            scheduleType: _scheduleType,
                            onScheduleTypeChanged: (val) =>
                                setState(() => _scheduleType = val),
                            selectedDays: _selectedDays,
                            onSelectedDaysChanged: (val) =>
                                setState(() => _selectedDays = val),
                            dayOfMonth: _dayOfMonth,
                            onDayOfMonthChanged: (val) =>
                                setState(() => _dayOfMonth = val),
                            startDate: _startDate,
                            onStartDateChanged: (val) =>
                                setState(() => _startDate = val),
                            targetDate: _targetDate,
                            onTargetDateChanged: (val) =>
                                setState(() => _targetDate = val),
                          ),

                          Divider(
                            height: 32,
                            thickness: 1.5,
                            color: colorScheme.outline,
                          ),

                          // Extracted Task Steps Editor
                          TaskStepsEditor(
                            stepsList: _stepsList,
                            onAddStep: _addStepField,
                            onRemoveStep: _removeStepField,
                            onStepsChanged: () => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom buttons
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _submit,
                        child: Text(
                          widget.task != null ? 'Save Task' : 'Create Task',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
