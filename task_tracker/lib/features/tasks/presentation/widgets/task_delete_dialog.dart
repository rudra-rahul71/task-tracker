import 'package:flutter/material.dart';

/// Modal dialog confirming task deletion.
class TaskDeleteDialog extends StatelessWidget {
  final String taskName;

  const TaskDeleteDialog({super.key, required this.taskName});

  static Future<bool?> show(BuildContext context, {required String taskName}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => TaskDeleteDialog(taskName: taskName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      title: Text(
        'Delete Task?',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'Are you sure you want to delete "$taskName"?',
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
    );
  }
}
