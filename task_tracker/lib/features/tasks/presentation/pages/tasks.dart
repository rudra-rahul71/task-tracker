import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_tracker/main.dart';
import 'package:task_tracker/core/widgets/page_header.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/presentation/providers/task_providers.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/add_task_dialog.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/manage_groups_dialog.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/task_card.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

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

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    String value,
    String activeFilter,
    ColorScheme colorScheme,
  ) {
    final isSelected = activeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(taskFilterProvider.notifier).state = value;
        }
      },
      selectedColor: colorScheme.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = ref.watch(userIdProvider);
    final activeFilter = ref.watch(taskFilterProvider);
    final filteredTasksAsync = ref.watch(filteredTasksProvider);
    final groupsAsync = ref.watch(taskGroupsProvider);

    // Auto-schedule check side-effect via reactive listener
    ref.listen<AsyncValue<List<TaskModel>>>(tasksStreamProvider, (prev, next) {
      next.whenData((tasks) {
        final groups = groupsAsync.value ?? [];
        if (userId != null && tasks.isNotEmpty) {
          ref.read(taskRepositoryProvider).checkAndResetScheduledTasks(
            userId: userId,
            tasks: tasks,
            groups: groups,
          );
        }
      });
    });

    if (userId == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final groups = groupsAsync.value ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
                    onPressed: () => _showManageGroupsDialog(context),
                    icon: const Icon(Icons.folder_open_outlined, size: 20),
                    label: const Text(
                      'Groups',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary),
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
                      style: TextStyle(fontWeight: FontWeight.bold),
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
                _buildFilterChip(
                  context,
                  ref,
                  'Due Today',
                  'due',
                  activeFilter,
                  colorScheme,
                ),
                _buildFilterChip(
                  context,
                  ref,
                  'All Tasks',
                  'all',
                  activeFilter,
                  colorScheme,
                ),
                _buildFilterChip(
                  context,
                  ref,
                  'By Group',
                  'group',
                  activeFilter,
                  colorScheme,
                ),
                _buildFilterChip(
                  context,
                  ref,
                  'Completed',
                  'completed',
                  activeFilter,
                  colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filtered tasks content via AsyncValue
            filteredTasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Error loading tasks: $error',
                  style: TextStyle(color: colorScheme.error, fontSize: 16),
                ),
              ),
              data: (tasks) {
                if (activeFilter == 'due') {
                  return _buildTaskList(
                    context,
                    tasks,
                    groups,
                    'No tasks due today!',
                    isInteractive: true,
                    showCompletionStatus: true,
                  );
                } else if (activeFilter == 'completed') {
                  return _buildTaskList(
                    context,
                    tasks,
                    groups,
                    'No completed tasks yet!',
                    isInteractive: true,
                    showCompletionStatus: true,
                  );
                } else if (activeFilter == 'all') {
                  return _buildTaskList(
                    context,
                    tasks,
                    groups,
                    'No tasks created yet!',
                    isInteractive: false,
                    showCompletionStatus: false,
                  );
                } else {
                  // 'group'
                  return _buildGroupedTasksView(context, tasks, groups);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskListLayout(
    BuildContext context,
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
                  isInteractive: isInteractive,
                  showCompletionStatus: showCompletionStatus,
                ),
              ),
            )
            .toList(),
      );
    }
  }

  Widget _buildTaskList(
    BuildContext context,
    List<TaskModel> taskList,
    List<TaskGroupModel> groups,
    String emptyMessage, {
    bool isInteractive = true,
    bool showCompletionStatus = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (taskList.isEmpty) {
      return Center(
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
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Task" to start setting up tasks.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final (overdue, upcoming) = TaskEvaluationUtils.partitionTasksByOverdue(
      taskList,
      groups,
    );

    return Column(
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
          _buildTaskListLayout(context, overdue, groups, true, true),
        ],

        if (upcoming.isNotEmpty) ...[
          if (overdue.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: colorScheme.outline),
            const SizedBox(height: 16),
          ],
          _buildTaskListLayout(
            context,
            upcoming,
            groups,
            isInteractive,
            showCompletionStatus,
          ),
        ],
      ],
    );
  }

  Widget _buildGroupSection(
    BuildContext context, {
    required String title,
    required Color color,
    required List<TaskModel> groupTasks,
    required List<TaskGroupModel> groups,
    required ColorScheme colorScheme,
  }) {
    final (overdueTasks, upcomingTasks) =
        TaskEvaluationUtils.partitionTasksByOverdue(groupTasks, groups);

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
              child: _buildGroupTaskCards(
                context,
                overdueTasks,
                upcomingTasks,
                groups,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupedTasksView(
    BuildContext context,
    List<TaskModel> allTasks,
    List<TaskGroupModel> groups,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final Map<String?, List<TaskModel>> groupedMap = {};
    for (var task in allTasks) {
      groupedMap.putIfAbsent(task.groupId, () => []).add(task);
    }

    if (allTasks.isEmpty) {
      return Center(
        child: Text(
          'No tasks to group yet!',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...groups.map((group) {
          final groupTasks = groupedMap[group.id] ?? [];
          return _buildGroupSection(
            context,
            title: group.name,
            color: Color(group.colorValue),
            groupTasks: groupTasks,
            groups: groups,
            colorScheme: colorScheme,
          );
        }),
        if (groupedMap.containsKey(null) && groupedMap[null]!.isNotEmpty)
          _buildGroupSection(
            context,
            title: 'Unassigned / General Tasks',
            color: colorScheme.onSurfaceVariant,
            groupTasks: groupedMap[null]!,
            groups: groups,
            colorScheme: colorScheme,
          ),
      ],
    );
  }

  Widget _buildGroupTaskCards(
    BuildContext context,
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
          _buildTaskListLayout(context, overdueTasks, groups, false, false),
        ],
        if (upcomingTasks.isNotEmpty) ...[
          if (overdueTasks.isNotEmpty) ...[
            Divider(color: colorScheme.outline),
            const SizedBox(height: 8),
          ],
          _buildTaskListLayout(context, upcomingTasks, groups, false, false),
        ],
      ],
    );
  }
}
