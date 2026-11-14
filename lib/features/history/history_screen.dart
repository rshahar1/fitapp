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
                  icon: Icons.history,
                  title: 'Nothing logged yet',
                  message: 'Finished workouts and activities show up here.',
                )
              : _HistoryList(items: items),
        ),
      ),
    );
  }
}

enum _HistoryView { list, calendar }

class _HistoryList extends StatefulWidget {
  const new({required this.items});

  final List<HistoryEntry> items;

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  _HistoryView _view = _HistoryView.list;

  @override
  Widget build(BuildContext context) {
    final months = <String, List<HistoryEntry>>{};
    if (_view == _HistoryView.list) {
      for (final item in widget.items) {
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
        SegmentedButton<_HistoryView>(
          segments: const [
            ButtonSegment(
              value: _HistoryView.list,
              icon: Icon(Icons.view_list),
              label: Text('List'),
            ),
            ButtonSegment(
              value: _HistoryView.calendar,
              icon: Icon(Icons.calendar_month),
              label: Text('Calendar'),
            ),
          ],
          selected: {_view},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _view = s.first),
        ),
        if (_view == _HistoryView.calendar)
          HistoryCalendar(entries: widget.items)
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
