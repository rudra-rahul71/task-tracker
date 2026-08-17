import 'package:flutter/material.dart';

enum TrackerIndicatorType {
  completion,
  slipUp,
}

class CalendarTaskData {
  final String name;
  final int? groupColorValue;
  final bool isCompleted;

  const CalendarTaskData({
    required this.name,
    this.groupColorValue,
    required this.isCompleted,
  });

  Color resolveColor(ColorScheme colorScheme) {
    if (groupColorValue != null) {
      return Color(groupColorValue!);
    }
    return colorScheme.primary;
  }
}

class CalendarDayData {
  final List<TrackerIndicatorType> trackerIndicators;
  final List<CalendarTaskData> tasks;

  const CalendarDayData({
    this.trackerIndicators = const [],
    this.tasks = const [],
  });
}

class CalendarWidget extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Map<String, CalendarDayData> eventsMap;
  final Function(DateTime) onMonthChanged;
  final Function(DateTime) onDaySelected;

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  const CalendarWidget({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.eventsMap,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final year = focusedMonth.year;
    final month = focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final emptySlots = firstDay.weekday % 7; // Sunday is index 0
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final totalCells = emptySlots + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cellAspectRatio = cardWidth >= 520 ? 0.95 : 0.65;
        final isBounded = constraints.maxHeight != double.infinity;

        final content = Column(
          children: [
            // Calendar Header Month / Year & Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    onMonthChanged(
                      DateTime(focusedMonth.year, focusedMonth.month - 1),
                    );
                  },
                ),
                Text(
                  '${_months[focusedMonth.month - 1]} ${focusedMonth.year}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    onMonthChanged(
                      DateTime(focusedMonth.year, focusedMonth.month + 1),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Weekday Grid Labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _weekdays.map((w) {
                return Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // Days Grid
            if (isBounded)
              Expanded(
                child: Column(
                  children: List.generate(totalRows, (row) {
                    return Expanded(
                      child: Row(
                        children: List.generate(7, (col) {
                          final index = row * 7 + col;
                          if (index < emptySlots || index >= totalCells) {
                            return const Expanded(child: SizedBox.shrink());
                          }
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: row < totalRows - 1 ? 8.0 : 0.0,
                                right: col < 6 ? 8.0 : 0.0,
                              ),
                              child: _buildDayCell(
                                context,
                                index,
                                emptySlots,
                                focusedMonth,
                                selectedDay,
                                eventsMap,
                                onDaySelected,
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: cellAspectRatio,
                ),
                itemCount: totalCells,
                itemBuilder: (context, index) {
                  return _buildDayCell(
                    context,
                    index,
                    emptySlots,
                    focusedMonth,
                    selectedDay,
                    eventsMap,
                    onDaySelected,
                  );
                },
              ),
          ],
        );

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: isBounded ? content : SingleChildScrollView(child: content),
          ),
        );
      },
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    int index,
    int emptySlots,
    DateTime focusedMonth,
    DateTime selectedDay,
    Map<String, CalendarDayData> eventsMap,
    Function(DateTime) onDaySelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (index < emptySlots) {
      return const SizedBox.shrink();
    }

    final dayNum = index - emptySlots + 1;
    final dayDate = DateTime(focusedMonth.year, focusedMonth.month, dayNum);

    final isSelected =
        selectedDay.year == dayDate.year &&
        selectedDay.month == dayDate.month &&
        selectedDay.day == dayDate.day;

    final today = DateTime.now();
    final isToday =
        today.year == dayDate.year &&
        today.month == dayDate.month &&
        today.day == dayDate.day;

    final dayDateKey = "${dayDate.year}-${dayDate.month}-${dayDate.day}";

    final eventData = eventsMap[dayDateKey] ?? const CalendarDayData();
    final allIndicators = eventData.trackerIndicators;
    final tasksOnDay = eventData.tasks;

    final List<Widget> taskBanners = [];

    if (tasksOnDay.isNotEmpty) {
      final displayLimit = 2;
      final showMore = tasksOnDay.length > displayLimit;
      final count = showMore ? displayLimit - 1 : tasksOnDay.length;

      for (int i = 0; i < count; i++) {
        final t = tasksOnDay[i];
        final isCompleted = t.isCompleted;
        final color = t.resolveColor(colorScheme);

        final isLightColor =
            ThemeData.estimateBrightnessForColor(color) == Brightness.light;
        final textColor = isCompleted
            ? (isLightColor ? Colors.black87 : Colors.white70)
            : (isLightColor ? color.withValues(alpha: 0.9) : color);

        taskBanners.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 2.0),
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: isCompleted
                  ? color.withValues(alpha: 0.85)
                  : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: isCompleted
                  ? null
                  : Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
            ),
            child: Text(
              t.name,
              style: TextStyle(
                fontSize: 8.0,
                fontWeight: FontWeight.bold,
                color: isCompleted
                    ? (isLightColor ? Colors.black : Colors.white)
                    : textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      if (showMore) {
        final remainingCount = tasksOnDay.length - count;
        taskBanners.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 2.0),
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+$remainingCount more',
              style: TextStyle(
                fontSize: 7.5,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
    }

    return GestureDetector(
      onTap: () {
        onDaySelected(dayDate);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 56.0),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.25)
              : isToday
              ? colorScheme.onSurface.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : isToday
                ? colorScheme.outline
                : colorScheme.onSurface.withValues(alpha: 0.05),
            width: isSelected || isToday ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$dayNum',
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                       ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  children: taskBanners,
                ),
              ),
              if (allIndicators.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: allIndicators.take(4).map((indicator) {
                        final indicatorColor =
                            indicator == TrackerIndicatorType.slipUp
                                ? colorScheme.error
                                : colorScheme.tertiary;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.0),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
