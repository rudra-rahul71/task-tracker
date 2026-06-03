import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker/core/widgets/page_header.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';
import 'package:task_tracker/features/tasks/data/models/task_model.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/add_task_dialog.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/manage_groups_dialog.dart';
import 'package:task_tracker/features/tasks/presentation/widgets/task_card.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final TaskRepository _repository = TaskRepository();
  String _activeFilter = 'due'; // 'due' (Due Today), 'all' (All Tasks), 'group' (By Group)
  String? _currentUserId;
  Stream<List<TaskGroupModel>>? _groupsStream;
  Stream<List<TaskModel>>? _tasksStream;

  void _initStreamsForUser(String userId) {
    if (_currentUserId == userId && _groupsStream != null && _tasksStream != null) {
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

  bool _isTaskDueToday(TaskModel task, List<TaskGroupModel> groups) {
    final now = DateTime.now();

    // 1. Task has its own schedule
    if (task.schedule != null && task.schedule!.type != 'none') {
      return task.schedule!.isDueOnDate(now);
    }

    // 2. Task inherits its group schedule
    if (task.groupId != null) {
      final group = groups.firstWhere(
        (g) => g.id == task.groupId,
        orElse: () => TaskGroupModel(id: '', userId: '', name: '', colorValue: 0, createdAt: DateTime.now()),
      );
      if (group.id.isNotEmpty && group.schedule != null && group.schedule!.type != 'none') {
        return group.schedule!.isDueOnDate(now);
      }
    }

    // 3. Unscheduled tasks: show under "Due Today" if they are pending (so they don't get lost)
    // or if they were completed today.
    final completedToday = task.status == 'completed' &&
        task.lastCompletedAt != null &&
        task.lastCompletedAt!.year == now.year &&
        task.lastCompletedAt!.month == now.month &&
        task.lastCompletedAt!.day == now.day;
    return task.status == 'pending' || completedToday;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    _initStreamsForUser(userId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              header: 'Tasks & Chores',
              sub: 'Checklists with step-level timers and schedules',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showManageGroupsDialog(context),
                    icon: const Icon(Icons.folder_open_outlined, size: 20),
                    label: const Text('Groups', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddTaskDialog(context),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                ChoiceChip(
                  label: const Text('Due Today'),
                  selected: _activeFilter == 'due',
                  onSelected: (selected) {
                    if (selected) setState(() => _activeFilter = 'due');
                  },
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _activeFilter == 'due'
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ChoiceChip(
                  label: const Text('All Tasks'),
                  selected: _activeFilter == 'all',
                  onSelected: (selected) {
                    if (selected) setState(() => _activeFilter = 'all');
                  },
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _activeFilter == 'all'
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ChoiceChip(
                  label: const Text('By Group'),
                  selected: _activeFilter == 'group',
                  onSelected: (selected) {
                    if (selected) setState(() => _activeFilter = 'group');
                  },
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _activeFilter == 'group'
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Nested Streams for Tasks and Groups
            Expanded(
              child: StreamBuilder<List<TaskGroupModel>>(
                stream: _groupsStream!,
                builder: (context, groupsSnapshot) {
                  if (groupsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final groups = groupsSnapshot.data ?? [];

                  return StreamBuilder<List<TaskModel>>(
                    stream: _tasksStream!,
                    builder: (context, tasksSnapshot) {
                      if (tasksSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (tasksSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading tasks: ${tasksSnapshot.error}',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                          ),
                        );
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

                      // Apply filtering
                      if (_activeFilter == 'due') {
                        final dueTasks = tasks
                            .where((t) {
                              final isDue = _isTaskDueToday(t, groups);
                              if (t.status == 'completed') {
                                final now = DateTime.now();
                                final completedToday = t.lastCompletedAt != null &&
                                    t.lastCompletedAt!.year == now.year &&
                                    t.lastCompletedAt!.month == now.month &&
                                    t.lastCompletedAt!.day == now.day;
                                return isDue && completedToday;
                              }
                              return isDue;
                            })
                            .toList();

                        return _buildTaskList(
                          dueTasks,
                          groups,
                          'No tasks due today!',
                          isInteractive: true,
                          showCompletionStatus: true,
                        );
                      } else if (_activeFilter == 'all') {
                        return _buildTaskList(
                          tasks,
                          groups,
                          'No tasks created yet!',
                          isInteractive: false,
                          showCompletionStatus: false,
                        );
                      } else {
                        // Group sorting/categorizing
                        return _buildGroupedTasksView(tasks, groups);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(
    List<TaskModel> taskList,
    List<TaskGroupModel> groups,
    String emptyMessage, {
    bool isInteractive = true,
    bool showCompletionStatus = true,
  }) {
    if (taskList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checklist_rtl_rounded,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Task" to start setting up tasks.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    if (width >= 850) {
      final leftList = <TaskModel>[];
      final rightList = <TaskModel>[];
      for (int i = 0; i < taskList.length; i++) {
        if (i % 2 == 0) {
          leftList.add(taskList[i]);
        } else {
          rightList.add(taskList[i]);
        }
      }

      return SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: leftList
                    .map((task) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: TaskCard(
                            task: task,
                            groups: groups,
                            repository: _repository,
                            isInteractive: isInteractive,
                            showCompletionStatus: showCompletionStatus,
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: rightList
                    .map((task) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: TaskCard(
                            task: task,
                            groups: groups,
                            repository: _repository,
                            isInteractive: isInteractive,
                            showCompletionStatus: showCompletionStatus,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      );
    } else {
      return ListView.builder(
        itemCount: taskList.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: TaskCard(
              task: taskList[index],
              groups: groups,
              repository: _repository,
              isInteractive: isInteractive,
              showCompletionStatus: showCompletionStatus,
            ),
          );
        },
      );
    }
  }

  Widget _buildGroupedTasksView(List<TaskModel> allTasks, List<TaskGroupModel> groups) {
    // 1. Group tasks by groupId
    final Map<String?, List<TaskModel>> groupedMap = {};
    for (var task in allTasks) {
      groupedMap.putIfAbsent(task.groupId, () => []).add(task);
    }

    if (allTasks.isEmpty) {
      return Center(
        child: Text(
          'No tasks to group yet!',
          style: TextStyle(color: Colors.grey[500], fontSize: 16, fontStyle: FontStyle.italic),
        ),
      );
    }


    return ListView(
      children: [
        // Print tasks belonging to groups
        ...groups.map((group) {
          final groupTasks = groupedMap[group.id] ?? [];
          final color = Color(group.colorValue);

          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Row(
                children: [
                  CircleAvatar(backgroundColor: color, radius: 8),
                  const SizedBox(width: 10),
                  Text(
                    group.name,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${groupTasks.length})',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
              children: [
                if (groupTasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 28.0, bottom: 12.0),
                    child: Text(
                      'No tasks in this group.',
                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: groupTasks.map((task) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: TaskCard(
                            task: task,
                            groups: groups,
                            repository: _repository,
                            isInteractive: false,
                            showCompletionStatus: false,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        }),

        // 3. Print tasks without a group
        if (groupedMap.containsKey(null) && groupedMap[null]!.isNotEmpty) ...[
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Row(
                children: [
                  const CircleAvatar(backgroundColor: Colors.grey, radius: 8),
                  const SizedBox(width: 10),
                  const Text(
                    'Unassigned / General Tasks',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${groupedMap[null]!.length})',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: groupedMap[null]!.map((task) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TaskCard(
                          task: task,
                          groups: groups,
                          repository: _repository,
                          isInteractive: false,
                          showCompletionStatus: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
