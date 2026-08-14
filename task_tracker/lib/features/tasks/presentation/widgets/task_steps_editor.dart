import 'package:flutter/material.dart';

/// Sub-widget responsible for editing checklist steps and per-step timer durations.
class TaskStepsEditor extends StatelessWidget {
  final List<Map<String, dynamic>> stepsList;
  final VoidCallback onAddStep;
  final ValueChanged<int> onRemoveStep;
  final VoidCallback onStepsChanged;

  const TaskStepsEditor({
    super.key,
    required this.stepsList,
    required this.onAddStep,
    required this.onRemoveStep,
    required this.onStepsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
              onPressed: onAddStep,
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add Step',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stepsList.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final stepData = stepsList[index];
            return Card(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                              hintText: 'e.g. Wash clothes, Add Detergent',
                              hintStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                              labelText: 'Step ${index + 1}',
                              labelStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            initialValue: stepData['name'],
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 14,
                            ),
                            onChanged: (val) {
                              stepData['name'] = val;
                              onStepsChanged();
                            },
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                        if (stepsList.length > 1)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: colorScheme.error,
                              size: 20,
                            ),
                            onPressed: () => onRemoveStep(index),
                          ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Has Timer?',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            Checkbox(
                              value: stepData['hasTimer'],
                              onChanged: (val) {
                                stepData['hasTimer'] = val ?? false;
                                onStepsChanged();
                              },
                              activeColor: colorScheme.primary,
                              checkColor: colorScheme.onPrimary,
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
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  border: const UnderlineInputBorder(),
                                ),
                                initialValue: stepData['minutes'].toString(),
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  final num = int.tryParse(val);
                                  if (num != null) {
                                    stepData['minutes'] = num;
                                    onStepsChanged();
                                  }
                                },
                                validator: (val) {
                                  if (stepData['hasTimer']) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Enter minutes';
                                    }
                                    final num = int.tryParse(val);
                                    if (num == null || num <= 0) {
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
    );
  }
}
