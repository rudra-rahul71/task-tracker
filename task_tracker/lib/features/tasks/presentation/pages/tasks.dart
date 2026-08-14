import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/core/widgets/page_header.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/add_task_dialog.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/manage_groups_dialog.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/task_card.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  TaskRepository get _repository => ref.read(taskRepositoryProvider);
  String _activeFilter =
      'due'; // 'due' (Due Today), 'all' (All Tasks), 'group' (By Group)
  String? _currentUserId;
  Stream<List<TaskGroupModel>>? _groupsStream;
  Stream<List<TaskModel>>? _tasksStream;

  void _initStreamsForUser(String userId) {
    if (_currentUserId == userId &&
        _groupsStream != null &&
        _tasksStream != null) {
      return;
    }
    _currentUserId = userId;
    _groupsStream = _repository.getGroups(userId);
    _tasksStream = _repository.getTasks(userId);
  }

  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddTaskDialog(),
    );
  }

  void _showManageGroupsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ManageGroupsDialog(),
    );
  }

  Widget _buildFilterChip(String label, String value, ColorScheme colorScheme) {
    final isSelected = _activeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _activeFilter = value);
      },
      selectedColor: colorScheme.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  TaskGroupModel? _findGroup(String? groupId, List<TaskGroupModel> groups) {
    if (groupId == null) return null;
    for (final g in groups) {
      if (g.id == groupId) return g;
    }
    return null;
  }

  (bool, DateTime?) _getScheduleInfo(
    TaskModel task,
    List<TaskGroupModel> groups,
  ) {
    if (task.schedule != null) {
      return (task.schedule!.type != 'none', task.schedule!.startDate);
    }
    final group = _findGroup(task.groupId, groups);
    if (group?.schedule != null) {
      return (group!.schedule!.type != 'none', group.schedule!.startDate);
    }
    return (false, null);
  }

  (List<TaskModel>, List<TaskModel>) _partitionTasksByOverdue(
    List<TaskModel> tasks,
    List<TaskGroupModel> groups,
  ) {
    final upcoming = <TaskModel>[];
    final overdue = <TaskModel>[];
    for (final t in tasks) {
      if (_isTaskOverdueOneOff(t, groups)) {
        overdue.add(t);
      } else {
        upcoming.add(t);
      }
    }
    return (overdue, upcoming);
  }

  bool _isTaskDueToday(TaskModel task, List<TaskGroupModel> groups) {
    final now = DateTime.now();

    // 1. Task has its own schedule
    if (task.schedule != null) {
      if (task.schedule!.type != 'none' || task.schedule!.startDate != null) {
        return task.schedule!.isDueOnDate(now);
      }
    } else {
      // 2. Task inherits its group schedule
      final group = _findGroup(task.groupId, groups);
      if (group?.schedule != null) {
        if (group!.schedule!.type != 'none' ||
            group.schedule!.startDate != null) {
          return group.schedule!.isDueOnDate(now);
        }
      }
    }

    // 3. Unscheduled tasks: show under "Due Today" if they are pending (so they don't get lost)
    // or if they were completed today.
    final completedToday =
        task.status == 'completed' &&
        task.lastCompletedAt != null &&
        task.lastCompletedAt!.year == now.year &&
        task.lastCompletedAt!.month == now.month &&
        task.lastCompletedAt!.day == now.day;
    return task.status == 'pending' || completedToday;
  }

  bool _isTaskRecurring(TaskModel task, List<TaskGroupModel> groups) {
    if (task.schedule != null) {
      return task.schedule!.type != 'none';
    }
    final group = _findGroup(task.groupId, groups);
    return group?.schedule?.type != null && group!.schedule!.type != 'none';
  }

  bool _isTaskOverdueOneOff(TaskModel task, List<TaskGroupModel> groups) {
    if (task.status != 'pending') return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (task.schedule != null) {
      if (task.schedule!.type == 'none' && task.schedule!.startDate != null) {
        final sDate = task.schedule!.startDate!;
        return DateTime(sDate.year, sDate.month, sDate.day).isBefore(today);
      }
      return false;
    }

    final g = _findGroup(task.groupId, groups);
    if (g?.schedule != null) {
      if (g!.schedule!.type == 'none' && g.schedule!.startDate != null) {
        final sDate = g.schedule!.startDate!;
        return DateTime(sDate.year, sDate.month, sDate.day).isBefore(today);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = ref.read(authRepositoryProvider).currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    _initStreamsForUser(userId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<TaskGroupModel>>(
        stream: _groupsStream!,
        builder: (context, groupsSnapshot) {
          if (groupsSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error loading task groups: ${groupsSnapshot.error}',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _groupsStream = null;
                        _tasksStream = null;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (groupsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = groupsSnapshot.data ?? [];

          return StreamBuilder<List<TaskModel>>(
            stream: _tasksStream!,
            builder: (context, tasksSnapshot) {
              if (tasksSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Error loading tasks: ${tasksSnapshot.error}',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _groupsStream = null;
                            _tasksStream = null;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (tasksSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final tasks = tasksSnapshot.data ?? [];

              // Dynamically run the check/reset scheduler logic
              if (tasks.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _repository.checkAndResetScheduledTasks(
                    userId: userId,
                    tasks: tasks,
                    groups: groups,
                  );
                });
              }

              // Apply filtering and sorting

              // Sort helper
              int sortTasks(TaskModel a, TaskModel b) {
                final (aIsScheduled, aStartDate) = _getScheduleInfo(
                  a,
                  groups,
                );
                final (bIsScheduled, bStartDate) = _getScheduleInfo(
                  b,
                  groups,
                );

                if (aIsScheduled && !bIsScheduled) return -1;
                if (!aIsScheduled && bIsScheduled) return 1;

                if (!aIsScheduled && !bIsScheduled) {
                  if (aStartDate != null && bStartDate != null) {
                    return aStartDate.compareTo(bStartDate);
                  }
                  if (aStartDate != null) return -1;
                  if (bStartDate != null) return 1;
                }

                return a.createdAt.compareTo(b.createdAt);
              }

              bool isCompletedToday(TaskModel t) {
                if (t.status != 'completed' ||
                    t.lastCompletedAt == null) {
                  return false;
                }
                final now = DateTime.now();
                return t.lastCompletedAt!.year == now.year &&
                    t.lastCompletedAt!.month == now.month &&
                    t.lastCompletedAt!.day == now.day;
              }

              Widget bodySliver;

              if (_activeFilter == 'due') {
                final dueTasks = tasks.where((t) {
                  final isDue = _isTaskDueToday(t, groups);
                  return isDue &&
                      (t.status == 'pending' || isCompletedToday(t));
                }).toList();

                bodySliver = _buildTaskListSliver(
                  dueTasks,
                  groups,
                  'No tasks due today!',
                  isInteractive: true,
                  showCompletionStatus: true,
                );
              } else if (_activeFilter == 'completed') {
                final completedTasks = tasks
                    .where(
                      (t) =>
                          t.status == 'completed' &&
                          !_isTaskRecurring(t, groups),
                    )
                    .toList();

                completedTasks.sort((a, b) {
                  if (a.lastCompletedAt != null &&
                      b.lastCompletedAt != null) {
                    return b.lastCompletedAt!.compareTo(
                      a.lastCompletedAt!,
                    ); // Descending
                  }
                  return 0;
                });

                bodySliver = _buildTaskListSliver(
                  completedTasks,
                  groups,
                  'No completed tasks yet!',
                  isInteractive: true,
                  showCompletionStatus: true,
                );
              } else {
                // Filter out all completed one-off tasks for 'all' and 'group' views (they move to Completed tab)
                final allOrGroupTasks = tasks.where((t) {
                  if (_isTaskRecurring(t, groups)) return true;
                  return t.status == 'pending';
                }).toList();

                allOrGroupTasks.sort(sortTasks);

                if (_activeFilter == 'all') {
                  bodySliver = _buildTaskListSliver(
                    allOrGroupTasks,
                    groups,
                    'No tasks created yet!',
                    isInteractive: false,
                    showCompletionStatus: false,
                  );
                } else {
                  // Group sorting/categorizing
                  bodySliver = _buildGroupedTasksSliver(
                    allOrGroupTasks,
                    groups,
                  );
                }
              }

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(24.0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PageHeader(
                            header: 'Tasks',
                            sub: 'Checklists with step-level timers and schedules',
                            action: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _showManageGroupsDialog(context),
                                  icon: const Icon(
                                    Icons.folder_open_outlined,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Groups',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colorScheme.primary,
                                    side:
                                        BorderSide(color: colorScheme.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _showAddTaskDialog(context),
                                  icon: const Icon(Icons.add, size: 20),
                                  label: const Text(
                                    'Add Task',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Filter Chips
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _buildFilterChip('Due Today', 'due', colorScheme),
                              _buildFilterChip('All Tasks', 'all', colorScheme),
                              _buildFilterChip('By Group', 'group', colorScheme),
                              _buildFilterChip(
                                'Completed',
                                'completed',
                                colorScheme,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  bodySliver,
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskListLayout(
    List<TaskModel> tasks,
    List<TaskGroupModel> groups,
    bool isInteractive,
    bool showCompletionStatus,
  ) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 850) {
      final leftList = <TaskModel>[];
      final rightList = <TaskModel>[];
      for (int i = 0; i < tasks.length; i++) {
        if (i % 2 == 0) {
          leftList.add(tasks[i]);
        } else {
          rightList.add(tasks[i]);
        }
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: leftList
                  .map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: TaskCard(
                        task: task,
                        groups: groups,
                        repository: _repository,
                        isInteractive: isInteractive,
                        showCompletionStatus: showCompletionStatus,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: rightList
                  .map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: TaskCard(
                        task: task,
                        groups: groups,
                        repository: _repository,
                        isInteractive: isInteractive,
                        showCompletionStatus: showCompletionStatus,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: tasks
            .map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TaskCard(
                  task: task,
                  groups: groups,
                  repository: _repository,
                  isInteractive: isInteractive,
                  showCompletionStatus: showCompletionStatus,
                ),
              ),
            )
            .toList(),
      );
    }
  }

  Widget _buildTaskListSliver(
    List<TaskModel> taskList,
    List<TaskGroupModel> groups,
    String emptyMessage, {
    bool isInteractive = true,
    bool showCompletionStatus = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (taskList.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.checklist_rtl_rounded,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap "Add Task" to start setting up tasks.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final (overdue, upcoming) = _partitionTasksByOverdue(taskList, groups);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (overdue.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Overdue Tasks',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildTaskListLayout(overdue, groups, true, true),
            ],
            if (upcoming.isNotEmpty) ...[
              if (overdue.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(color: colorScheme.outline),
                const SizedBox(height: 16),
              ],
              _buildTaskListLayout(
                upcoming,
                groups,
                isInteractive,
                showCompletionStatus,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSection({
    required String title,
    required Color color,
    required List<TaskModel> groupTasks,
    required List<TaskGroupModel> groups,
    required ColorScheme colorScheme,
  }) {
    final (overdueTasks, upcomingTasks) = _partitionTasksByOverdue(
      groupTasks,
      groups,
    );

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Row(
          children: [
            CircleAvatar(backgroundColor: color, radius: 8),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${groupTasks.length})',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
        children: [
          if (groupTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 28.0, bottom: 12.0),
              child: Text(
                'No tasks in this group.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              child: _buildGroupTaskCards(overdueTasks, upcomingTasks, groups),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupedTasksSliver(
    List<TaskModel> allTasks,
    List<TaskGroupModel> groups,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (allTasks.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.checklist_rtl_rounded,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No tasks created yet!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap "Add Task" to start setting up tasks.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Map<String?, List<TaskModel>> groupedMap = {};
    for (var task in allTasks) {
      groupedMap.putIfAbsent(task.groupId, () => []).add(task);
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Print tasks belonging to groups
            ...groups.map((group) {
              final groupTasks = groupedMap[group.id] ?? [];
              return _buildGroupSection(
                title: group.name,
                color: Color(group.colorValue),
                groupTasks: groupTasks,
                groups: groups,
                colorScheme: colorScheme,
              );
            }),

            // 3. Print tasks without a group
            if (groupedMap.containsKey(null) && groupedMap[null]!.isNotEmpty)
              _buildGroupSection(
                title: 'Unassigned / General Tasks',
                color: colorScheme.onSurfaceVariant,
                groupTasks: groupedMap[null]!,
                groups: groups,
                colorScheme: colorScheme,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTaskCards(
    List<TaskModel> overdueTasks,
    List<TaskModel> upcomingTasks,
    List<TaskGroupModel> groups,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (overdueTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Overdue Tasks',
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildTaskListLayout(overdueTasks, groups, false, false),
        ],
        if (upcomingTasks.isNotEmpty) ...[
          if (overdueTasks.isNotEmpty) ...[
            Divider(color: colorScheme.outline),
            const SizedBox(height: 8),
          ],
          _buildTaskListLayout(upcomingTasks, groups, false, false),
        ],
      ],
    );
  }
}
