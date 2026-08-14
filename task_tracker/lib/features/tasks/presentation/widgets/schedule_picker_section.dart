import 'package:flutter/material.dart';
import 'package:task_tracker/features/tasks/data/models/task_group.dart';

/// Sub-widget responsible for configuring recurrence and schedule parameters for a task.
class SchedulePickerSection extends StatelessWidget {
  final String? selectedGroupId;
  final List<TaskGroupModel> groups;
  final String scheduleSetting;
  final ValueChanged<String> onScheduleSettingChanged;
  final String scheduleType;
  final ValueChanged<String> onScheduleTypeChanged;
  final List<int> selectedDays;
  final ValueChanged<List<int>> onSelectedDaysChanged;
  final int dayOfMonth;
  final ValueChanged<int> onDayOfMonthChanged;
  final DateTime startDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final DateTime targetDate;
  final ValueChanged<DateTime> onTargetDateChanged;

  static const List<String> _daysOfWeekNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  const SchedulePickerSection({
    super.key,
    required this.selectedGroupId,
    required this.groups,
    required this.scheduleSetting,
    required this.onScheduleSettingChanged,
    required this.scheduleType,
    required this.onScheduleTypeChanged,
    required this.selectedDays,
    required this.onSelectedDaysChanged,
    required this.dayOfMonth,
    required this.onDayOfMonthChanged,
    required this.startDate,
    required this.onStartDateChanged,
    required this.targetDate,
    required this.onTargetDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasGroupSchedule =
        selectedGroupId != null &&
        groups.any(
          (g) =>
              g.id == selectedGroupId &&
              g.schedule != null &&
              g.schedule!.type != 'none',
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Task Schedule',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment<String>(
                value: 'none',
                label: Text(hasGroupSchedule ? 'None' : 'No Schedule'),
                icon: const Icon(Icons.block, size: 18),
              ),
              if (hasGroupSchedule)
                const ButtonSegment<String>(
                  value: 'inherit',
                  label: Text('Inherit'),
                  icon: Icon(Icons.folder_shared_outlined, size: 18),
                ),
              const ButtonSegment<String>(
                value: 'custom',
                label: Text('Custom'),
                icon: Icon(Icons.edit_calendar_outlined, size: 18),
              ),
            ],
            selected: {scheduleSetting},
            onSelectionChanged: (newSelection) {
              onScheduleSettingChanged(newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              selectedBackgroundColor: colorScheme.primary.withValues(
                alpha: 0.15,
              ),
              selectedForegroundColor: colorScheme.primary,
            ),
          ),
        ),

        if (scheduleSetting == 'inherit') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Inherits recurring schedule from group.',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (scheduleSetting == 'none') ...[
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Target Completion Date',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}',
              style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
            ),
            trailing: IconButton(
              icon: Icon(Icons.calendar_month, color: colorScheme.primary),
              onPressed: () async {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final initialDate = targetDate.isBefore(today) ? today : targetDate;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: today,
                  lastDate: today.add(const Duration(days: 365 * 5)),
                );
                if (picked != null) {
                  onTargetDateChanged(picked);
                }
              },
            ),
          ),
        ],

        if (scheduleSetting == 'custom') ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: scheduleType,
            decoration: InputDecoration(
              labelText: 'Schedule Frequency',
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
            ),
            dropdownColor: colorScheme.surface,
            style: TextStyle(color: colorScheme.onSurface),
            items: const [
              ('daily', 'Daily'),
              ('weekly', 'Weekly'),
              ('bi_weekly', 'Bi-Weekly'),
              ('monthly', 'Monthly'),
            ].map((e) => DropdownMenuItem(
              value: e.$1,
              child: Text(e.$2, style: TextStyle(color: colorScheme.onSurface)),
            )).toList(),
            onChanged: (val) {
              if (val != null) {
                onScheduleTypeChanged(val);
              }
            },
          ),
          const SizedBox(height: 12),

          // Weekly & Bi-Weekly Days Picker
          if (scheduleType == 'weekly' || scheduleType == 'bi_weekly') ...[
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
                    final updatedDays = List<int>.from(selectedDays);
                    if (selected) {
                      updatedDays.add(dayVal);
                    } else {
                      updatedDays.remove(dayVal);
                    }
                    onSelectedDaysChanged(updatedDays);
                  },
                  selectedColor: colorScheme.primary.withValues(alpha: 0.2),
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
                style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
              ),
              trailing: IconButton(
                icon: Icon(Icons.calendar_month, color: colorScheme.primary),
                onPressed: () async {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final initialDate = startDate.isBefore(today) ? today : startDate;
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
                labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
              ),
              dropdownColor: colorScheme.surface,
              style: TextStyle(color: colorScheme.onSurface),
              items: List.generate(31, (index) => index + 1).map((day) => DropdownMenuItem(
                value: day,
                child: Text('Day $day', style: TextStyle(color: colorScheme.onSurface)),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  onDayOfMonthChanged(val);
                }
              },
            ),
          ],
        ],
      ],
    );
  }
}
