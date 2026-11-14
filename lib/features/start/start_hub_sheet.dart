import 'dart:async';

import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/domain/start_guard.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/features/activities/activity_sheet.dart';
import 'package:fitapp/features/start/start_actions.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// What the user picked in the hub. The sheet closes first and the caller
/// acts with its own context (research R3).
sealed class HubChoice {
  const new();
}

/// Open the session in progress.
final class ContinueChoice extends HubChoice {
  const new(this.session);
  final SessionInProgress session;
}

/// Open the GPS setup for [typeId].
final class TrackChoice extends HubChoice {
  const new(this.typeId);
  final String typeId;
}

/// Open the past-session form, optionally with [typeId] preselected.
final class LogPastChoice extends HubChoice {
  const new({this.typeId});
  final String? typeId;
}

/// Opens the Start/Log hub (feature 011) and carries out the choice.
Future<void> showStartHub(BuildContext context) async {
  final choice = await showModalBottomSheet<HubChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const StartHubSheet(),
  );
  if (choice == null || !context.mounted) return;
  final actions = ProviderScope.containerOf(context).read(startActionsProvider);
  switch (choice) {
    case ContinueChoice(:final session):
      actions.open(context, session);
    case TrackChoice(:final typeId):
      await actions.startTracking(context, typeId);
    case LogPastChoice(:final typeId):
      unawaited(showActivitySheet(context, initialTypeId: typeId));
  }
}

/// The hub's content: "Start now" and "Earlier".
class StartHubSheet extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void pick(HubChoice choice) => Navigator.of(context).pop(choice);
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionInProgressProvider);
    final live = [
      for (final t in activityTypes)
        if (t.hasLiveTracking) t,
    ];
    final other = [
      for (final t in activityTypes)
        if (!t.hasLiveTracking) t,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Start or log', style: text.titleLarge),
            Group(
              header: 'Start now',
              children: [
                if (session != null)
                  GroupRow(
                    title: session.continueLabel,
                    subtitle: 'In progress',
                    leading: _icon(
                      session.kind == SessionKind.gym
                          ? gymWorkoutIcon
                          : activityIcon(session.typeId!),
                      accent: true,
                    ),
                    showChevron: true,
                    onTap: () => pick(ContinueChoice(session)),
                  ),
                for (final t in live)
                  GroupRow(
                    title: t.label,
                    subtitle: 'Live GPS',
                    leading: _icon(activityIcon(t.id)),
                    onTap: () => pick(TrackChoice(t.id)),
                  ),
                for (final t in other)
                  GroupRow(
                    title: t.label,
                    subtitle: 'Log for today',
                    leading: _icon(activityIcon(t.id)),
                    onTap: () => pick(LogPastChoice(typeId: t.id)),
                  ),
              ],
            ),
            Group(
              header: 'Earlier',
              children: [
                GroupRow(
                  title: 'Log a past session',
                  leading: _icon(Icons.history),
                  showChevron: true,
                  onTap: () => pick(const LogPastChoice()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _icon(IconData icon, {bool accent = false}) =>
      Icon(icon, color: accent ? AppColors.accent : AppColors.textSecondary);
}
