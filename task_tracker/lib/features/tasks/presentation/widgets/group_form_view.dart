import 'package:flutter/material.dart';

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

/// Form view for creating and editing a task group.
class GroupFormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool isEdit;
  final String initialName;
  final ValueChanged<String> onNameSaved;
  final int selectedColor;
  final ValueChanged<int> onColorChanged;
  final bool hasSchedule;
  final ValueChanged<bool> onHasScheduleChanged;
  final String scheduleType;
  final ValueChanged<String> onScheduleTypeChanged;
  final List<int> selectedDays;
  final ValueChanged<List<int>> onSelectedDaysChanged;
  final int dayOfMonth;
  final ValueChanged<int> onDayOfMonthChanged;
  final DateTime startDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  static const List<String> _daysOfWeekNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  const GroupFormView({
    super.key,
    required this.formKey,
    required this.isEdit,
    required this.initialName,
    required this.onNameSaved,
    required this.selectedColor,
    required this.onColorChanged,
    required this.hasSchedule,
    required this.onHasScheduleChanged,
    required this.scheduleType,
    required this.onScheduleTypeChanged,
    required this.selectedDays,
    required this.onSelectedDaysChanged,
    required this.dayOfMonth,
    required this.onDayOfMonthChanged,
    required this.startDate,
    required this.onStartDateChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEdit ? 'Edit Group' : 'Add New Group',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: initialName,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Group Name',
                        hintText: 'e.g. Chores, Morning Routine',
                        labelStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.primary),
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Enter group name'
                          : null,
                      onSaved: (val) => onNameSaved(val!.trim()),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Group Color',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: GroupPresetColor.values.map((preset) {
                        final isSelected = selectedColor == preset.value;
                        return GestureDetector(
                          onTap: () => onColorChanged(preset.value),
                          child: CircleAvatar(
                            backgroundColor: preset.color,
                            radius: 16,
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: colorScheme.onPrimary,
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
                      title: Text(
                        'Set Recurrence Schedule',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'All tasks in this group will inherit this schedule by default',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      value: hasSchedule,
                      onChanged: onHasScheduleChanged,
                      activeThumbColor: colorScheme.primary,
                    ),

                    if (hasSchedule) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: scheduleType,
                        decoration: InputDecoration(
                          labelText: 'Schedule Type',
                          labelStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                        ),
                        dropdownColor: colorScheme.surface,
                        style: TextStyle(color: colorScheme.onSurface),
                        items:
                            const [
                                  ('daily', 'Daily'),
                                  ('weekly', 'Weekly'),
                                  ('bi_weekly', 'Bi-Weekly'),
                                  ('monthly', 'Monthly'),
                                ]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.$1,
                                    child: Text(
                                      e.$2,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            onScheduleTypeChanged(val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Weekly & Bi-Weekly Days Picker
                      if (scheduleType == 'weekly' ||
                          scheduleType == 'bi_weekly') ...[
                        Text(
                          'Days of the Week',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: List.generate(7, (index) {
                            final dayVal = index + 1; // 1-7
                            final isSelected = selectedDays.contains(dayVal);
                            return ChoiceChip(
                              label: Text(_daysOfWeekNames[index]),
                              selected: isSelected,
                              onSelected: (selected) {
                                final updatedDays = List<int>.from(
                                  selectedDays,
                                );
                                if (selected) {
                                  updatedDays.add(dayVal);
                                } else {
                                  updatedDays.remove(dayVal);
                                }
                                onSelectedDaysChanged(updatedDays);
                              },
                              selectedColor: colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                                fontSize: 12,
                              ),
                            );
                          }),
                        ),
                      ],

                      // Bi-weekly Start Anchor date picker
                      if (scheduleType == 'bi_weekly') ...[
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Start Date / Anchor Week',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 15,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.calendar_month,
                              color: colorScheme.primary,
                            ),
                            onPressed: () async {
                              final now = DateTime.now();
                              final today = DateTime(
                                now.year,
                                now.month,
                                now.day,
                              );
                              final initialDate = startDate.isBefore(today)
                                  ? today
                                  : startDate;
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: initialDate,
                                firstDate: today,
                                lastDate: today.add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                onStartDateChanged(picked);
                              }
                            },
                          ),
                        ),
                      ],

                      // Monthly Day of Month picker
                      if (scheduleType == 'monthly') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: dayOfMonth,
                          decoration: InputDecoration(
                            labelText: 'Day of Month',
                            labelStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.outline,
                              ),
                            ),
                          ),
                          dropdownColor: colorScheme.surface,
                          style: TextStyle(color: colorScheme.onSurface),
                          items: List.generate(31, (index) => index + 1)
                              .map(
                                (day) => DropdownMenuItem(
                                  value: day,
                                  child: Text(
                                    'Day $day',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              onDayOfMonthChanged(val);
                            }
                          },
                        ),
                      ],
                    ],

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.onSurfaceVariant,
                              side: BorderSide(color: colorScheme.outline),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: onCancel,
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
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: onSubmit,
                            child: Text(
                              isEdit ? 'Edit Group' : 'Create Group',
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
