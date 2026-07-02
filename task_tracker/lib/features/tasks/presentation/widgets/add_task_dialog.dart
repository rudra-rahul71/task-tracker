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
  const AddTaskDialog({super.key});

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

  // Checklist steps
  final List<Map<String, dynamic>> _stepsList = [
    {'name': '', 'hasTimer': false, 'minutes': 10}
  ];

  bool _isLoading = false;
  List<TaskGroupModel> _groups = [];

  final List<String> _daysOfWeekNames = const [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _loadGroups();
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
        SnackbarService(context).showErrorSnackbar(message: 'Error: User not authenticated');
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
        daysOfWeek: _scheduleType == 'monthly' ? [] : _selectedDays,
        dayOfMonth: _scheduleType == 'monthly' ? _dayOfMonth : 1,
        startDate: _scheduleType == 'bi_weekly' ? _startDate : null,
      );
    } else if (_scheduleSetting == 'none') {
      taskSchedule = TaskSchedule(type: 'none');
    }
    // Note: If scheduleSetting is 'inherit', task.schedule will remain null,
    // thereby letting the task inherit its group schedule during execution.

    // Map step lists to TaskStep objects
    final taskSteps = _stepsList.map((stepMap) {
      final stepName = stepMap['name'] as String;
      final hasTimer = stepMap['hasTimer'] as bool;
      final minutes = stepMap['minutes'] as int;
      final durationSeconds = hasTimer ? minutes * 60 : null;

      return TaskStep(
        name: stepName,
        isCompleted: false,
        timerDuration: durationSeconds,
        timerSecondsRemaining: durationSeconds,
      );
    }).toList();

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

    try {
      await _repository.addTask(newTask);
      navigator.pop();
      if (mounted) {
        SnackbarService(context).showSuccessSnackbar(message: 'Task created successfully');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SnackbarService(context).showErrorSnackbar(message: 'Failed to create task: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupOptions = _groups.map((g) {
      final hasGroupSched = g.schedule != null && g.schedule!.type != 'none';
      final schedText = hasGroupSched ? ' (${g.schedule!.type})' : ' (no schedule)';
      return DropdownMenuItem<String>(
        value: g.id,
        child: Text(
          g.name + schedText,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }).toList();

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
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
                        'Create Task',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
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
                            decoration: InputDecoration(
                              labelText: 'Task Name',
                              hintText: 'e.g. Do Laundry, Take Vitamins',
                              labelStyle: const TextStyle(color: Colors.grey),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Enter task name' : null,
                            onSaved: (val) => _name = val!.trim(),
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Description (Optional)',
                              hintText: 'Add details or instructions...',
                              labelStyle: const TextStyle(color: Colors.grey),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                            maxLines: 2,
                            onSaved: (val) => _description = val?.trim() ?? '',
                          ),
                          const SizedBox(height: 16),

                          // Group Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: _selectedGroupId,
                            decoration: InputDecoration(
                              labelText: 'Task Group (Optional)',
                              labelStyle: const TextStyle(color: Colors.grey),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                            ),
                            dropdownColor: const Color(0xFF1E1E1E),
                            style: const TextStyle(color: Colors.white),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('No Group', style: TextStyle(color: Colors.white)),
                              ),
                              ...groupOptions,
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedGroupId = val;
                                // Automatically update schedule choices based on group selection
                                if (_selectedGroupId != null) {
                                  final group = _groups.firstWhere((g) => g.id == _selectedGroupId);
                                  if (group.schedule != null && group.schedule!.type != 'none') {
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
                          const Text(
                            'Task Schedule',
                            style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              segments: [
                                const ButtonSegment<String>(
                                  value: 'none',
                                  label: Text('No Schedule'),
                                  icon: Icon(Icons.block),
                                ),
                                if (_selectedGroupId != null &&
                                    _groups.any((g) => g.id == _selectedGroupId && g.schedule != null && g.schedule!.type != 'none'))
                                  const ButtonSegment<String>(
                                    value: 'inherit',
                                    label: Text('Inherit Group'),
                                    icon: Icon(Icons.folder_shared_outlined),
                                  ),
                                const ButtonSegment<String>(
                                  value: 'custom',
                                  label: Text('Custom'),
                                  icon: Icon(Icons.edit_calendar_outlined),
                                ),
                              ],
                              selected: {_scheduleSetting},
                              onSelectionChanged: (newSelection) {
                                setState(() {
                                  _scheduleSetting = newSelection.first;
                                });
                              },
                              style: SegmentedButton.styleFrom(
                                selectedBackgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                selectedForegroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),

                          if (_scheduleSetting == 'custom') ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _scheduleType,
                              decoration: InputDecoration(
                                labelText: 'Schedule Frequency',
                                labelStyle: const TextStyle(color: Colors.grey),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.grey),
                                ),
                              ),
                              dropdownColor: const Color(0xFF1E1E1E),
                              style: const TextStyle(color: Colors.white),
                              items: const [
                                DropdownMenuItem(value: 'weekly', child: Text('Weekly', style: TextStyle(color: Colors.white))),
                                DropdownMenuItem(value: 'bi_weekly', child: Text('Bi-Weekly', style: TextStyle(color: Colors.white))),
                                DropdownMenuItem(value: 'monthly', child: Text('Monthly', style: TextStyle(color: Colors.white))),
                              ],
                              onChanged: (val) => setState(() {
                                _scheduleType = val!;
                                _selectedDays = [];
                              }),
                            ),
                            const SizedBox(height: 12),
                            
                            // Weekly & Bi-Weekly Days Picker
                            if (_scheduleType == 'weekly' || _scheduleType == 'bi_weekly') ...[
                              const Text('Days of the Week', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: List.generate(7, (index) {
                                  final dayVal = index + 1; // 1-7
                                  final isSelected = _selectedDays.contains(dayVal);
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
                                    selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.white,
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
                                title: const Text('Start Date / Anchor Week', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                subtitle: Text(
                                  '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
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
                                  labelStyle: const TextStyle(color: Colors.grey),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.grey),
                                  ),
                                ),
                                dropdownColor: const Color(0xFF1E1E1E),
                                style: const TextStyle(color: Colors.white),
                                items: List.generate(31, (index) => index + 1)
                                    .map((day) => DropdownMenuItem(
                                          value: day,
                                          child: Text('Day $day', style: const TextStyle(color: Colors.white)),
                                        ))
                                    .toList(),
                                onChanged: (val) => setState(() => _dayOfMonth = val!),
                              ),
                            ],
                          ],
                          
                          const Divider(height: 32, thickness: 1.5, color: Colors.grey),
                          
                          // Task Checklist Steps
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Checklist Steps',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
                                onPressed: _addStepField,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Step', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _stepsList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final stepData = _stepsList[index];
                              return Card(
                                color: const Color(0xFF262626),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              decoration: InputDecoration(
                                                hintText: 'e.g. Wash clothes, Add Detergent',
                                                hintStyle: const TextStyle(color: Colors.grey),
                                                border: InputBorder.none,
                                                labelText: 'Step ${index + 1}',
                                                labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                              ),
                                              initialValue: stepData['name'],
                                              style: const TextStyle(color: Colors.white, fontSize: 14),
                                              onChanged: (val) => stepData['name'] = val,
                                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                            ),
                                          ),
                                          if (_stepsList.length > 1)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                              onPressed: () => _removeStepField(index),
                                            ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Text('Has Timer?', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                              Checkbox(
                                                value: stepData['hasTimer'],
                                                onChanged: (val) {
                                                  setState(() {
                                                    stepData['hasTimer'] = val!;
                                                  });
                                                },
                                                activeColor: Theme.of(context).colorScheme.primary,
                                                checkColor: Colors.black,
                                              ),
                                            ],
                                          ),
                                          if (stepData['hasTimer'])
                                            SizedBox(
                                              width: 140,
                                              child: TextFormField(
                                                decoration: const InputDecoration(
                                                  labelText: 'Duration (min)',
                                                  labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                                                  border: UnderlineInputBorder(),
                                                ),
                                                initialValue: stepData['minutes'].toString(),
                                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                                keyboardType: TextInputType.number,
                                                onChanged: (val) {
                                                  final num = int.tryParse(val);
                                                  if (num != null) stepData['minutes'] = num;
                                                },
                                                validator: (val) {
                                                  if (stepData['hasTimer']) {
                                                    if (val == null || val.trim().isEmpty) return 'Enter minutes';
                                                    final num = int.tryParse(val);
                                                    if (num == null || num <= 0) return 'Invalid';
                                                  }
                                                  return null;
                                                },
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
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: _submit,
                        child: const Text('Create Task', style: TextStyle(fontWeight: FontWeight.bold)),
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
