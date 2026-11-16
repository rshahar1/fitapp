import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/calendar.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/features/history/history_rows.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Month calendar of logged sessions with a per-day session list.
class HistoryCalendar extends ConsumerStatefulWidget {
  /// Creates the calendar for [entries].
  const new({super.key, required this.entries});

  /// All history entries (any order).
  final List<HistoryEntry> entries;

  @override
  ConsumerState<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends ConsumerState<HistoryCalendar> {
  DateTime? _anchor;
  DateTime? _selected;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref
        ..invalidate(stepAccessProvider)
        ..invalidate(daySteps),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  DateTime get _today => dateOnly(ref.read(clockProvider)().toLocal());

  DateTime get _anchorDay => _anchor ?? _today;
  DateTime get _selectedDay => _selected ?? _today;

  bool get _canGoNext {
    final t = _today;
    final a = _anchorDay;
    return DateTime(a.year, a.month).isBefore(DateTime(t.year, t.month));
  }

  void _step(int delta) {
    final a = _anchorDay;
    setState(() {
      _anchor = addMonths(a, delta);
    });
  }

  void _goToday() => setState(() {
    _anchor = _today;
    _selected = _today;
  });

  Future<void> _pickMonth() async {
    final today = _today;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthYearDialog(initial: _anchorDay, today: today),
    );
    if (picked == null) return;
    setState(() {
      final sameMonth =
          picked.year == today.year && picked.month == today.month;
      _anchor = sameMonth ? today : picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <String, List<HistoryEntry>>{};
    for (final e in widget.entries) {
      byDay.putIfAbsent(dayKey(e.startedAt.toLocal()), () => []).add(e);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    }
    final today = _today;
    final anchor = _anchorDay;
    final selected = _selectedDay;
    final weeks = monthGrid(anchor.year, anchor.month);
    final dayEntries = byDay[dayKey(selected)] ?? const <HistoryEntry>[];
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.s),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              constraints: const BoxConstraints(
                minWidth: Sizes.tap,
                minHeight: Sizes.tap,
              ),
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _step(-1),
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Choose month and year',
                excludeSemantics: true,
                child: InkWell(
                  onTap: _pickMonth,
                  borderRadius: BorderRadius.circular(Radii.chip),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Sizes.tap),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          DateFormat('MMMM y').format(anchor),
                          style: text.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              constraints: const BoxConstraints(
                minWidth: Sizes.tap,
                minHeight: Sizes.tap,
              ),
              icon: const Icon(Icons.chevron_right),
              onPressed: _canGoNext ? () => _step(1) : null,
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(Sizes.tap, Sizes.tap),
                padding: const EdgeInsets.symmetric(horizontal: Space.s),
              ),
              onPressed: _goToday,
              child: const Text('Today'),
            ),
          ],
        ),
        Row(
          children: [
            for (final d in weekDays(today))
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('E').format(d),
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.xs),
        for (final week in weeks)
          Row(
            children: [
              for (final day in week)
                Expanded(
                  child: _DayCell(
                    day: day,
                    entries: byDay[dayKey(day)] ?? const [],
                    inMonth: day.month == anchor.month,
                    isToday: day == today,
                    isSelected: day == selected,
                    onTap: () => setState(() => _selected = day),
                  ),
                ),
            ],
          ),
        const SizedBox(height: Space.m),
        SectionHeader(
          DateFormat('EEEE d MMMM').format(selected),
          trailing: _DaySteps(day: selected),
        ),
        if (dayEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Space.m),
            child: Text(
              'No training',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          Group(
            children: [for (final e in dayEntries) HistoryEntryRow(entry: e)],
          ),
      ],
    );
  }
}

/// Plain-text step total for [day]; hidden while loading or unavailable.
class _DaySteps extends ConsumerWidget {
  const new({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref.watch(daySteps(day)).value;
    if (steps == null) return const SizedBox.shrink();
    final label = formatSteps(steps);
    return Semantics(
      container: true,
      label: 'Steps on ${DateFormat('EEEE d MMMM').format(day)}: $label',
      excludeSemantics: true,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.textSecondary, fontFeatures: tabular),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const new({
    required this.day,
    required this.entries,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final List<HistoryEntry> entries;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = entries.length;
    final fg = isSelected
        ? AppColors.onAccent
        : inMonth
        ? AppColors.textPrimary
        : AppColors.textTertiary;
    final iconColor = isSelected
        ? AppColors.onAccent
        : inMonth
        ? AppColors.accent
        : AppColors.textTertiary;
    final label =
        '${DateFormat('EEEE d MMMM').format(day)}, '
        '${n == 0
            ? 'no training'
            : n == 1
            ? '1 session'
            : '$n sessions'}';
    final icon = n == 0
        ? null
        : switch (entries.first) {
            WorkoutHistoryEntry() => gymWorkoutIcon,
            ActivityHistoryEntry(:final activity) => activityIcon(
              activity.typeId,
            ),
          };
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(Space.xxs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.chip),
          child: Container(
            height: Sizes.tap + Space.xs,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : null,
              borderRadius: BorderRadius.circular(Radii.chip),
              border: isToday && !isSelected
                  ? Border.all(color: AppColors.accent)
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${day.day}',
                    style: text.bodyMedium?.copyWith(
                      color: fg,
                      fontFeatures: tabular,
                    ),
                  ),
                  if (icon != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: iconColor),
                        if (n > 1)
                          Text(
                            '+${n - 1}',
                            style: text.labelSmall?.copyWith(color: fg),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthYearDialog extends StatefulWidget {
  const new({required this.initial, required this.today});

  final DateTime initial;
  final DateTime today;

  @override
  State<_MonthYearDialog> createState() => _MonthYearDialogState();
}

class _MonthYearDialogState extends State<_MonthYearDialog> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final minYear = widget.today.year - 5;
    final maxYear = widget.today.year;
    return AlertDialog(
      title: Row(
        children: [
          IconButton(
            tooltip: 'Previous year',
            icon: const Icon(Icons.chevron_left),
            onPressed: _year > minYear ? () => setState(() => _year--) : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$_year',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next year',
            icon: const Icon(Icons.chevron_right),
            onPressed: _year < maxYear ? () => setState(() => _year++) : null,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: Space.xs,
          crossAxisSpacing: Space.xs,
          childAspectRatio: 1.6,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var m = 1; m <= 12; m++)
              _MonthButton(
                month: m,
                selected:
                    _year == widget.initial.year && m == widget.initial.month,
                enabled: _year < widget.today.year || m <= widget.today.month,
                onTap: () => Navigator.of(context).pop(DateTime(_year, m)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  const new({
    required this.month,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int month;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = DateFormat('MMM').format(DateTime(2000, month));
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: DateFormat('MMMM').format(DateTime(2000, month)),
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.chip),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(Radii.chip),
          child: Center(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: !enabled
                    ? AppColors.textTertiary
                    : selected
                    ? AppColors.accent
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
