import 'package:get_it/get_it.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/core/utils/snackbar.dart';
import 'package:task_tracker/core/widgets/loading_overlay.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/models/task_schedule.dart';
import 'package:task_tracker/features/tasks/data/models/task_step.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';

class AddTaskDialog extends StatefulWidget {
  final TaskModel? task;

  const AddTaskDialog({super.key, this.task});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _repository = getIt<TaskRepository>();
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  String _description = '';
  String? _selectedGroupId;

  // Schedule settings
  String _scheduleSetting = 'none'; // 'none', 'inherit', 'custom'
  String _scheduleType = 'weekly'; // 'weekly', 'bi_weekly', 'monthly'
  List<int> _selectedDays = [];
  int _dayOfMonth = 1;
  DateTime _startDate = DateTime.now();
  DateTime _targetDate = DateTime.now();

  // Checklist steps
  final List<Map<String, dynamic>> _stepsList = [
    {'name': '', 'hasTimer': false, 'minutes': 10},
  ];

  bool _isLoading = false;
  List<TaskGroupModel> _groups = [];

  final List<String> _daysOfWeekNames = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    _loadGroups();

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

  void _loadGroups() {
    final userId = GetIt.instance<AuthRepository>().currentUser?.uid;
    if (userId == null) return;

    _repository.getGroups(userId).first.then((groupsList) {
      if (mounted) {
        setState(() {
          _groups = groupsList;
        });
      }
    });
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

    final userId = GetIt.instance<AuthRepository>().currentUser?.uid;
    final navigator = Navigator.of(context);

    if (userId == null) {
      if (mounted) {
        SnackbarService(
          context,
        ).showErrorSnackbar(message: 'Error: User not authenticated');
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
          SnackbarService(
            context,
          ).showSuccessSnackbar(message: 'Task updated successfully');
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
          SnackbarService(
            context,
          ).showSuccessSnackbar(message: 'Task created successfully');
        }
      }
      navigator.pop();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SnackbarService(
          context,
        ).showErrorSnackbar(message: 'Failed to save task: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final groupOptions = _groups.map((g) {
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
                                    _groups.any(
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
                                // Automatically update schedule choices based on group selection
                                if (_selectedGroupId != null) {
                                  final group = _groups.firstWhere(
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

                          // Scheduling Section
                          Text(
                            'Task Schedule',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final hasGroupSchedule =
                                  _selectedGroupId != null &&
                                  _groups.any(
                                    (g) =>
                                        g.id == _selectedGroupId &&
                                        g.schedule != null &&
                                        g.schedule!.type != 'none',
                                  );

                              return SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<String>(
                                  showSelectedIcon: false,
                                  segments: [
                                    ButtonSegment<String>(
                                      value: 'none',
                                      label: Text(
                                        hasGroupSchedule ? 'None' : 'No Schedule',
                                      ),
                                      icon: const Icon(Icons.block, size: 18),
                                    ),
                                    if (hasGroupSchedule)
                                      const ButtonSegment<String>(
                                        value: 'inherit',
                                        label: Text('Inherit'),
                                        icon: Icon(
                                          Icons.folder_shared_outlined,
                                          size: 18,
                                        ),
                                      ),
                                    const ButtonSegment<String>(
                                      value: 'custom',
                                      label: Text('Custom'),
                                      icon: Icon(
                                        Icons.edit_calendar_outlined,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                  selected: {_scheduleSetting},
                                  onSelectionChanged: (newSelection) {
                                    setState(() {
                                      _scheduleSetting = newSelection.first;
                                    });
                                  },
                                  style: SegmentedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 8,
                                    ),
                                    selectedBackgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: 0.15),
                                    selectedForegroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              );
                            },
                          ),

                          if (_scheduleSetting == 'inherit') ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Inherits recurring schedule from group.',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (_scheduleSetting == 'none') ...[
                            const SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Target Completion Date',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                '${_targetDate.year}-${_targetDate.month.toString().padLeft(2, '0')}-${_targetDate.day.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 15,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.calendar_month,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    onPressed: () async {
                                      final now = DateTime.now();
                                      final today = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                      );
                                      final initialDate =
                                          _targetDate.isBefore(today)
                                          ? today
                                          : _targetDate;
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: initialDate,
                                        firstDate: today,
                                        lastDate: today.add(
                                          const Duration(days: 365 * 5),
                                        ),
                                      );
                                      if (picked != null) {
                                        setState(() => _targetDate = picked);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (_scheduleSetting == 'custom') ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _scheduleType,
                              decoration: InputDecoration(
                                labelText: 'Schedule Frequency',
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
                              items:
                                  const [
                                        ('daily', 'Daily'),
                                        ('weekly', 'Weekly'),
                                        ('bi_weekly', 'Bi-Weekly'),
                                        ('monthly', 'Monthly'),
                                      ]
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e.$1,
                                          child: Text(
                                            e.$2,
                                            style: TextStyle(
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) => setState(() {
                                _scheduleType = val!;
                                _selectedDays = [];
                              }),
                            ),
                            const SizedBox(height: 12),

                            // Weekly & Bi-Weekly Days Picker
                            if (_scheduleType == 'weekly' ||
                                _scheduleType == 'bi_weekly') ...[
                              Text(
                                'Days of the Week',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: List.generate(7, (index) {
                                  final dayVal = index + 1; // 1-7
                                  final isSelected = _selectedDays.contains(
                                    dayVal,
                                  );
                                  return ChoiceChip(
                                    label: Text(_daysOfWeekNames[index]),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedDays.add(dayVal);
                                        } else {
                                          _selectedDays.remove(dayVal);
                                        }
                                      });
                                    },
                                    selectedColor: colorScheme.primary
                                        .withValues(alpha: 0.2),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.onSurface,
                                      fontSize: 12,
                                    ),
                                  );
                                }),
                              ),
                            ],

                            // Bi-weekly Start Anchor date picker
                            if (_scheduleType == 'bi_weekly') ...[
                              const SizedBox(height: 12),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Start Date / Anchor Week',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 15,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.calendar_month,
                                    color: colorScheme.primary,
                                  ),
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    final today = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                    );
                                    final initialDate =
                                        _startDate.isBefore(today)
                                        ? today
                                        : _startDate;
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: initialDate,
                                      firstDate: today,
                                      lastDate: today.add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      setState(() => _startDate = picked);
                                    }
                                  },
                                ),
                              ),
                            ],

                            // Monthly Day of Month picker
                            if (_scheduleType == 'monthly') ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                initialValue: _dayOfMonth,
                                decoration: InputDecoration(
                                  labelText: 'Day of Month',
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
                                items: List.generate(31, (index) => index + 1)
                                    .map(
                                      (day) => DropdownMenuItem(
                                        value: day,
                                        child: Text(
                                          'Day $day',
                                          style: TextStyle(
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _dayOfMonth = val!),
                              ),
                            ],
                          ],

                          Divider(
                            height: 32,
                            thickness: 1.5,
                            color: colorScheme.outline,
                          ),

                          // Task Checklist Steps
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Checklist Steps',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.primary,
                                ),
                                onPressed: _addStepField,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text(
                                  'Add Step',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _stepsList.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final stepData = _stepsList[index];
                              return Card(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              decoration: InputDecoration(
                                                hintText:
                                                    'e.g. Wash clothes, Add Detergent',
                                                hintStyle: TextStyle(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                border: InputBorder.none,
                                                labelText: 'Step ${index + 1}',
                                                labelStyle: TextStyle(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              initialValue: stepData['name'],
                                              style: TextStyle(
                                                color: colorScheme.onSurface,
                                                fontSize: 14,
                                              ),
                                              onChanged: (val) =>
                                                  stepData['name'] = val,
                                              validator: (val) =>
                                                  val == null ||
                                                      val.trim().isEmpty
                                                  ? 'Required'
                                                  : null,
                                            ),
                                          ),
                                          if (_stepsList.length > 1)
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: colorScheme.error,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  _removeStepField(index),
                                            ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Has Timer?',
                                                style: TextStyle(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Checkbox(
                                                value: stepData['hasTimer'],
                                                onChanged: (val) {
                                                  setState(() {
                                                    stepData['hasTimer'] = val!;
                                                  });
                                                },
                                                activeColor:
                                                    colorScheme.primary,
                                                checkColor:
                                                    colorScheme.onPrimary,
                                              ),
                                            ],
                                          ),
                                          if (stepData['hasTimer'])
                                            Flexible(
                                              child: SizedBox(
                                                width: 110,
                                                child: TextFormField(
                                                  decoration: InputDecoration(
                                                    labelText: 'Duration (min)',
                                                    labelStyle: TextStyle(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                      fontSize: 12,
                                                    ),
                                                    border:
                                                        const UnderlineInputBorder(),
                                                  ),
                                                  initialValue:
                                                      stepData['minutes']
                                                          .toString(),
                                                  style: TextStyle(
                                                    color: colorScheme.onSurface,
                                                    fontSize: 14,
                                                  ),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  onChanged: (val) {
                                                    final num = int.tryParse(val);
                                                    if (num != null) {
                                                      stepData['minutes'] = num;
                                                    }
                                                  },
                                                  validator: (val) {
                                                    if (stepData['hasTimer']) {
                                                      if (val == null ||
                                                          val.trim().isEmpty) {
                                                        return 'Enter minutes';
                                                      }
                                                      final num = int.tryParse(
                                                        val,
                                                      );
                                                      if (num == null ||
                                                          num <= 0) {
                                                        return 'Invalid';
                                                      }
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
