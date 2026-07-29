import 'dart:async';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/core/utils/snackbar.dart';
import 'package:task_tracker/core/widgets/loading_overlay.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_schedule.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';

enum GroupPresetColor {
  gold(0xFFD4AF37),
  coral(0xFFEF5350),
  emerald(0xFF26A69A),
  blue(0xFF42A5F5),
  purple(0xFFAB47BC),
  rose(0xFFEC407A),
  orange(0xFFFF7043);

  final int value;
  const GroupPresetColor(this.value);

  Color get color => Color(value);
}

class ManageGroupsDialog extends StatefulWidget {
  const ManageGroupsDialog({super.key});

  @override
  State<ManageGroupsDialog> createState() => _ManageGroupsDialogState();
}

class _ManageGroupsDialogState extends State<ManageGroupsDialog> {
  final _repository = getIt<TaskRepository>();
  final _formKey = GlobalKey<FormState>();

  String? get _userId => getIt<AuthRepository>().currentUser?.uid;

  String _currentView = 'list'; // 'list', 'add', 'edit'
  String? _editingGroupId;
  DateTime? _editingGroupCreatedAt;

  String _name = '';
  int _selectedColor = GroupPresetColor.gold.value; // Default gold

  // Schedule fields
  bool _hasSchedule = false;
  String _scheduleType = 'weekly'; // 'weekly', 'bi_weekly', 'monthly'
  List<int> _selectedDays = []; // 1-7
  int _dayOfMonth = 1;
  DateTime _startDate = DateTime.now();

  bool _isLoading = false;
  List<TaskGroupModel>? _groups;
  StreamSubscription<List<TaskGroupModel>>? _groupsSubscription;

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
    final userId = _userId;
    if (userId != null) {
      _groupsSubscription = _repository.getGroups(userId).listen((groups) {
        if (mounted) {
          setState(() {
            _groups = groups;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    super.dispose();
  }

  void _openAddView() {
    setState(() {
      _currentView = 'add';
      _editingGroupId = null;
      _editingGroupCreatedAt = null;
      _name = '';
      _selectedColor = GroupPresetColor.gold.value;
      _hasSchedule = false;
      _scheduleType = 'weekly';
      _selectedDays = [];
      _dayOfMonth = 1;
      _startDate = DateTime.now();
    });
  }

  void _openEditView(TaskGroupModel group) {
    setState(() {
      _currentView = 'edit';
      _editingGroupId = group.id;
      _editingGroupCreatedAt = group.createdAt;
      _name = group.name;
      _selectedColor = group.colorValue;
      if (group.schedule != null && group.schedule!.type != 'none') {
        _hasSchedule = true;
        _scheduleType = group.schedule!.type;
        _selectedDays = List.from(group.schedule!.daysOfWeek);
        _dayOfMonth = group.schedule!.dayOfMonth;
        _startDate = group.schedule!.startDate ?? DateTime.now();
      } else {
        _hasSchedule = false;
        _scheduleType = 'weekly';
        _selectedDays = [];
        _dayOfMonth = 1;
        _startDate = DateTime.now();
      }
    });
  }

  void _submitGroup() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final userId = _userId;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    TaskSchedule? schedule;
    if (_hasSchedule) {
      schedule = TaskSchedule(
        type: _scheduleType,
        daysOfWeek: (_scheduleType == 'monthly' || _scheduleType == 'daily')
            ? []
            : _selectedDays,
        dayOfMonth: _scheduleType == 'monthly' ? _dayOfMonth : 1,
        startDate: _scheduleType == 'bi_weekly' ? _startDate : null,
      );
    }

    final isEdit = _currentView == 'edit';
    final groupData = TaskGroupModel(
      id: isEdit ? _editingGroupId! : '',
      userId: userId,
      name: _name,
      colorValue: _selectedColor,
      schedule: schedule,
      createdAt: isEdit
          ? (_editingGroupCreatedAt ?? DateTime.now())
          : DateTime.now(),
    );

    try {
      if (isEdit) {
        await _repository.updateGroup(groupData);
      } else {
        await _repository.addGroup(groupData);
      }

      setState(() {
        _isLoading = false;
        _currentView = 'list';
      });
      if (mounted) {
        SnackbarService(context).showSuccessSnackbar(
          message: isEdit
              ? 'Group updated successfully'
              : 'Group created successfully',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SnackbarService(
          context,
        ).showErrorSnackbar(message: 'Failed to save group: $e');
      }
    }
  }

  void _deleteGroup(String groupId) async {
    final userId = _userId;
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete Group?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tasks inside this group will not be deleted, but they will no longer belong to this group or inherit its schedule.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _repository.deleteGroup(userId, groupId);
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          SnackbarService(
            context,
          ).showSuccessSnackbar(message: 'Group deleted successfully');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          SnackbarService(
            context,
          ).showErrorSnackbar(message: 'Failed to delete group: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    if (userId == null) return const SizedBox.shrink();

    String headerTitle = 'Manage Groups';

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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: LoadingOverlay(
          isLoading: _isLoading,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      headerTitle,
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

                if (_currentView == 'list') _buildListView(),
                if (_currentView == 'add' || _currentView == 'edit')
                  _buildFormView(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                if (_groups == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final groups = _groups!;
                if (groups.isEmpty) {
                  return Center(
                    child: Text(
                      'No groups created yet.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: groups.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Colors.grey),
                  itemBuilder: (context, index) {
                    final g = groups[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(g.colorValue),
                        radius: 12,
                      ),
                      title: Text(
                        g.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        g.schedule != null && g.schedule!.type != 'none'
                            ? 'Schedule: ${g.schedule!.type}'
                            : 'No Schedule',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () => _openEditView(g),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _deleteGroup(g.id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _openAddView,
              child: const Text(
                'Add Group',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentView == 'edit' ? 'Edit Group' : 'Add New Group',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: _name,
                      decoration: InputDecoration(
                        labelText: 'Group Name',
                        hintText: 'e.g. Chores, Morning Routine',
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Enter group name'
                          : null,
                      onSaved: (val) => _name = val!.trim(),
                    ),
                    const SizedBox(height: 16),

                    // Color picker
                    const Text(
                      'Group Color',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: GroupPresetColor.values.map((preset) {
                        final isSelected = _selectedColor == preset.value;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColor = preset.value),
                          child: CircleAvatar(
                            backgroundColor: preset.color,
                            radius: 16,
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Group Recurrence Schedule Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Set Recurrence Schedule',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'All tasks in this group will inherit this schedule by default',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      value: _hasSchedule,
                      onChanged: (val) => setState(() => _hasSchedule = val),
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                    ),

                    if (_hasSchedule) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _scheduleType,
                        decoration: InputDecoration(
                          labelText: 'Schedule Type',
                          labelStyle: const TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                        ),
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text(
                              'Daily',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text(
                              'Weekly',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'bi_weekly',
                            child: Text(
                              'Bi-Weekly',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text(
                              'Monthly',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        onChanged: (val) => setState(() {
                          _scheduleType = val!;
                          _selectedDays = [];
                        }),
                      ),
                      const SizedBox(height: 12),

                      // Weekly & Bi-Weekly Days Picker
                      if (_scheduleType == 'weekly' ||
                          _scheduleType == 'bi_weekly') ...[
                        const Text(
                          'Days of the Week',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
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
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
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
                          title: const Text(
                            'Start Date / Anchor Week',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.calendar_month,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () async {
                              final now = DateTime.now();
                              final today = DateTime(
                                now.year,
                                now.month,
                                now.day,
                              );
                              final initialDate = _startDate.isBefore(today)
                                  ? today
                                  : _startDate;
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: initialDate,
                                firstDate: today,
                                lastDate: today.add(const Duration(days: 365)),
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
                              .map(
                                (day) => DropdownMenuItem(
                                  value: day,
                                  child: Text(
                                    'Day $day',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _dayOfMonth = val!),
                        ),
                      ],
                    ],

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              setState(() {
                                _currentView = 'list';
                              });
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _submitGroup,
                            child: Text(
                              _currentView == 'edit'
                                  ? 'Edit Group'
                                  : 'Create Group',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
