import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/features/history/history_calendar.dart';
import 'package:fitapp/features/history/history_rows.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Finished workouts and activities grouped by month, newest first.
class HistoryScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyEntriesProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Text(
              'Could not load history.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: AppIcons.history,
                  title: 'Nothing logged yet',
                  message: 'Finished workouts and activities show up here.',
                )
              : _HistoryList(items: items),
        ),
      ),
    );
  }
}

/// History screen view: grouped list or month calendar.
enum HistoryView { list, calendar }

/// Which History view is showing; the Home steps card sets it to calendar.
class HistoryViewNotifier extends Notifier<HistoryView> {
  @override
  HistoryView build() => HistoryView.list;

  /// The view being shown.
  HistoryView get view => state;

  /// Shows [value].
  set view(HistoryView value) => state = value;
}

final historyViewProvider = NotifierProvider<HistoryViewNotifier, HistoryView>(
  HistoryViewNotifier.new,
);

class _HistoryList extends ConsumerWidget {
  const new({required this.items});

  final List<HistoryEntry> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(historyViewProvider);
    final months = <String, List<HistoryEntry>>{};
    if (view == HistoryView.list) {
      for (final item in items) {
        months
            .putIfAbsent(formatMonth(_startedAt(item).toLocal()), () => [])
            .add(item);
      }
    }
    return ListView(
      padding: const EdgeInsets.all(Space.m),
      children: [
        Semantics(
          header: true,
          child: Text(
            'History',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        const SizedBox(height: Space.s),
        SegmentedButton<HistoryView>(
          segments: const [
            ButtonSegment(
              value: HistoryView.list,
              icon: Icon(AppIcons.list),
              label: Text('List'),
            ),
            ButtonSegment(
              value: HistoryView.calendar,
              icon: Icon(AppIcons.calendar),
              label: Text('Calendar'),
            ),
          ],
          selected: {view},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              ref.read(historyViewProvider.notifier).view = s.first,
        ),
        if (view == HistoryView.calendar)
          HistoryCalendar(entries: items)
        else
          for (final entry in months.entries) ...[
            SectionHeader(entry.key),
            Group(
              children: [
                for (final item in entry.value) HistoryEntryRow(entry: item),
              ],
            ),
          ],
      ],
    );
  }
}

DateTime _startedAt(HistoryEntry e) => switch (e) {
  WorkoutHistoryEntry(:final workout) => workout.startedAt,
  ActivityHistoryEntry(:final activity) => activity.startedAt,
};
