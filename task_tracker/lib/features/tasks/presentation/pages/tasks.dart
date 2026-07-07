import 'package:get_it/get_it.dart';
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

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final TaskRepository _repository = getIt<TaskRepository>();
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
    if (task.schedule != null) {
      if (task.schedule!.type != 'none' || task.schedule!.startDate != null) {
        return task.schedule!.isDueOnDate(now);
      }
    } else {
      // 2. Task inherits its group schedule
      if (task.groupId != null) {
        final group = groups.firstWhere(
          (g) => g.id == task.groupId,
          orElse: () => TaskGroupModel(id: '', userId: '', name: '', colorValue: 0, createdAt: DateTime.now()),
        );
        if (group.id.isNotEmpty && group.schedule != null) {
          if (group.schedule!.type != 'none' || group.schedule!.startDate != null) {
            return group.schedule!.isDueOnDate(now);
          }
        }
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

  bool _isTaskRecurring(TaskModel task, List<TaskGroupModel> groups) {
    if (task.schedule != null) {
      return task.schedule!.type != 'none';
    }
    if (task.groupId != null) {
      final group = groups.firstWhere(
        (g) => g.id == task.groupId,
        orElse: () => TaskGroupModel(id: '', userId: '', name: '', colorValue: 0, createdAt: DateTime.now()),
      );
      if (group.id.isNotEmpty && group.schedule != null) {
        return group.schedule!.type != 'none';
      }
    }
    return false;
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
    
    if (task.groupId != null) {
      final g = groups.firstWhere(
        (g) => g.id == task.groupId,
        orElse: () => TaskGroupModel(id: '', userId: '', name: '', colorValue: 0, createdAt: DateTime.now()),
      );
      if (g.id.isNotEmpty && g.schedule != null) {
        if (g.schedule!.type == 'none' && g.schedule!.startDate != null) {
          final sDate = g.schedule!.startDate!;
          return DateTime(sDate.year, sDate.month, sDate.day).isBefore(today);
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final userId = GetIt.instance<AuthRepository>().currentUser?.uid;

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
                ChoiceChip(
                  label: const Text('Completed'),
                  selected: _activeFilter == 'completed',
                  onSelected: (selected) {
                    if (selected) setState(() => _activeFilter = 'completed');
                  },
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _activeFilter == 'completed'
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

                      // Apply filtering and sorting
                      
                      // Sort helper
                      int sortTasks(TaskModel a, TaskModel b) {
                        bool aIsScheduled = false;
                        DateTime? aStartDate;
                        if (a.schedule != null) {
                          aIsScheduled = a.schedule!.type != 'none';
                          aStartDate = a.schedule!.startDate;
                        } else if (a.groupId != null) {
                          final g = groups.firstWhere((g) => g.id == a.groupId, orElse: () => TaskGroupModel(id: '', userId: '', name: '', colorValue: 0, createdAt: DateTime.now()));
                          if (g.id.isNotEmpty && g.schedule != null) {
                            aIsScheduled = g.schedule!.type != 'none';
                            aStartDate = g.schedule!.startDate;
                          }
                        }

                        bool bIsScheduled = false;
                        DateTime? bStartDate;
                        if (b.schedule != null) {
                          bIsScheduled = b.schedule!.type != 'none';
                          bStartDate = b.schedule!.startDate;
                        } else if (b.groupId != null) {
                          final g = groups.firstWhere((g) => g.id == b.groupId, orElse: () => TaskGroupModel(id: '', userId: '', name: '', colorValue: 0, createdAt: DateTime.now()));
                          if (g.id.isNotEmpty && g.schedule != null) {
                            bIsScheduled = g.schedule!.type != 'none';
                            bStartDate = g.schedule!.startDate;
                          }
                        }

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
                        if (t.status != 'completed' || t.lastCompletedAt == null) return false;
                        final now = DateTime.now();
                        return t.lastCompletedAt!.year == now.year &&
                               t.lastCompletedAt!.month == now.month &&
                               t.lastCompletedAt!.day == now.day;
                      }

                      if (_activeFilter == 'due') {
                        final dueTasks = tasks
                            .where((t) {
                              final isDue = _isTaskDueToday(t, groups);
                              return isDue && (t.status == 'pending' || isCompletedToday(t));
                            })
                            .toList();

                        return _buildTaskList(
                          dueTasks,
                          groups,
                          'No tasks due today!',
                          isInteractive: true,
                          showCompletionStatus: true,
                        );
                      } else if (_activeFilter == 'completed') {
                        final completedTasks = tasks
                            .where((t) => t.status == 'completed' && !_isTaskRecurring(t, groups))
                            .toList();
                        
                        completedTasks.sort((a, b) {
                          if (a.lastCompletedAt != null && b.lastCompletedAt != null) {
                            return b.lastCompletedAt!.compareTo(a.lastCompletedAt!); // Descending
                          }
                          return 0;
                        });

                        return _buildTaskList(
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
                          return _buildTaskList(
                            allOrGroupTasks,
                            groups,
                            'No tasks created yet!',
                            isInteractive: false,
                            showCompletionStatus: false,
                          );
                        } else {
                          // Group sorting/categorizing
                          return _buildGroupedTasksView(allOrGroupTasks, groups);
                        }
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

  Widget _buildTaskListLayout(List<TaskModel> tasks, List<TaskGroupModel> groups, bool isInteractive, bool showCompletionStatus) {
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
      );
    } else {
      return Column(
        children: tasks.map((task) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TaskCard(
                task: task,
                groups: groups,
                repository: _repository,
                isInteractive: isInteractive,
                showCompletionStatus: showCompletionStatus,
              ),
            )).toList(),
      );
    }
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

    final upcoming = <TaskModel>[];
    final overdue = <TaskModel>[];

    for (var t in taskList) {
      if (_isTaskOverdueOneOff(t, groups)) {
        overdue.add(t);
      } else {
        upcoming.add(t);
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overdue.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Overdue Tasks',
                style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _buildTaskListLayout(overdue, groups, true, true),
          ],
          
          if (upcoming.isNotEmpty) ...[
            if (overdue.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.grey),
              const SizedBox(height: 16),
            ],
            _buildTaskListLayout(upcoming, groups, isInteractive, showCompletionStatus),
          ],
        ],
      ),
    );
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

          final upcomingTasks = <TaskModel>[];
          final overdueTasks = <TaskModel>[];

          for (var t in groupTasks) {
            if (_isTaskOverdueOneOff(t, groups)) {
              overdueTasks.add(t);
            } else {
              upcomingTasks.add(t);
            }
          }

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
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...upcomingTasks.map((task) {
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
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),

        // 3. Print tasks without a group
        if (groupedMap.containsKey(null) && groupedMap[null]!.isNotEmpty) ...[
          Builder(
            builder: (context) {
              final unassignedTasks = groupedMap[null]!;
              final upcomingTasks = <TaskModel>[];
              final overdueTasks = <TaskModel>[];

              for (var t in unassignedTasks) {
                if (_isTaskOverdueOneOff(t, groups)) {
                  overdueTasks.add(t);
                } else {
                  upcomingTasks.add(t);
                }
              }

              return Theme(
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
                        '(${unassignedTasks.length})',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...upcomingTasks.map((task) {
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
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
        ],
      ],
    );
  }
}
