import 'package:flutter/material.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';

/// Single item row displaying a task group with its color, schedule, and actions.
class GroupListItem extends StatelessWidget {
  final TaskGroupModel group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const GroupListItem({
    super.key,
    required this.group,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasSchedule =
        group.schedule != null && group.schedule!.type != 'none';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(group.colorValue),
        radius: 12,
      ),
      title: Text(
        group.name,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        hasSchedule ? 'Schedule: ${group.schedule!.type}' : 'No Schedule',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
