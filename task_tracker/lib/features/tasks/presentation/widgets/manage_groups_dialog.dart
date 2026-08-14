import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:dynamic_backend_bridge/src/providers/core_providers.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/core/widgets/loading_overlay.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_schedule.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';
import 'group_list_item.dart';
import 'group_form_view.dart';

/// Modal dialog for managing task groups (viewing, adding, editing, and deleting).
class ManageGroupsDialog extends ConsumerStatefulWidget {
  const ManageGroupsDialog({super.key});

  @override
  ConsumerState<ManageGroupsDialog> createState() => _ManageGroupsDialogState();
}

class _ManageGroupsDialogState extends ConsumerState<ManageGroupsDialog> {
  TaskRepository get _repository => ref.read(taskRepositoryProvider);
  final _formKey = GlobalKey<FormState>();

  String? get _userId => ref.read(authRepositoryProvider).currentUser?.uid;

  String _currentView = 'list'; // 'list', 'add', 'edit'
  String? _editingGroupId;
  DateTime? _editingGroupCreatedAt;

  String _name = '';
  int _selectedColor = GroupPresetColor.gold.value;

  // Schedule fields
  bool _hasSchedule = false;
  String _scheduleType = 'weekly';
  List<int> _selectedDays = [];
  int _dayOfMonth = 1;
  DateTime _startDate = DateTime.now();

  bool _isLoading = false;
  List<TaskGroupModel>? _groups;
  StreamSubscription<List<TaskGroupModel>>? _groupsSubscription;

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
        AppBannerService.showSuccess(
          context,
          isEdit ? 'Group updated successfully' : 'Group created successfully',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        AppBannerService.showError(context, 'Failed to save group: $e');
      }
    }
  }

  void _deleteGroup(String groupId) async {
    final userId = _userId;
    if (userId == null) return;
    final colorScheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Delete Group?',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Tasks inside this group will not be deleted, but they will no longer belong to this group or inherit its schedule.',
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
      setState(() {
        _isLoading = true;
      });
      try {
        await _repository.deleteGroup(userId, groupId);
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          AppBannerService.showSuccess(context, 'Group deleted successfully');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          AppBannerService.showError(context, 'Failed to delete group: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userId = _userId;
    if (userId == null) return const SizedBox.shrink();

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
                      'Manage Groups',
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

                if (_currentView == 'list') _buildListView(colorScheme),
                if (_currentView == 'add' || _currentView == 'edit')
                  GroupFormView(
                    formKey: _formKey,
                    isEdit: _currentView == 'edit',
                    initialName: _name,
                    onNameSaved: (val) => _name = val,
                    selectedColor: _selectedColor,
                    onColorChanged: (val) => setState(() => _selectedColor = val),
                    hasSchedule: _hasSchedule,
                    onHasScheduleChanged: (val) => setState(() => _hasSchedule = val),
                    scheduleType: _scheduleType,
                    onScheduleTypeChanged: (val) => setState(() {
                      _scheduleType = val;
                      _selectedDays = [];
                    }),
                    selectedDays: _selectedDays,
                    onSelectedDaysChanged: (val) => setState(() => _selectedDays = val),
                    dayOfMonth: _dayOfMonth,
                    onDayOfMonthChanged: (val) => setState(() => _dayOfMonth = val),
                    startDate: _startDate,
                    onStartDateChanged: (val) => setState(() => _startDate = val),
                    onCancel: () => setState(() => _currentView = 'list'),
                    onSubmit: _submitGroup,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(ColorScheme colorScheme) {
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
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: groups.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: colorScheme.outline),
                  itemBuilder: (context, index) {
                    final g = groups[index];
                    return GroupListItem(
                      group: g,
                      onEdit: () => _openEditView(g),
                      onDelete: () => _deleteGroup(g.id),
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
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
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
}
