import 'dart:async';

import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/domain/start_guard.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/features/activities/activity_sheet.dart';
import 'package:fitapp/features/start/start_actions.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

/// Start a gym workout from the template [templateId] (feature 031).
final class TemplateChoice extends HubChoice {
  const new(this.templateId);
  final String templateId;
}

/// Open Gym Templates to create the first template (feature 031).
final class CreateTemplateChoice extends HubChoice {
  const new();
}

/// Opens the Go hub (features 011, 031) and carries out the choice.
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
    case TemplateChoice(:final templateId):
      await actions.startTemplate(context, templateId);
    case CreateTemplateChoice():
      unawaited(GoRouter.of(context).push(Routes.templates));
  }
}

/// The Go hub's content: "Start now" (continue, gym templates, GPS and logged
/// types) and "Earlier".
class StartHubSheet extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void pick(HubChoice choice) => Navigator.of(context).pop(choice);
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionInProgressProvider);
    final templates = ref.watch(templatesProvider).value ?? const [];
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
            Text('Go', style: text.titleLarge),
            Group(
              header: 'Start now',
              children: [
                if (session != null)
                  GroupRow(
                    title: session.continueLabel,
                    subtitle: 'In progress',
                    leading: session.kind == SessionKind.gym
                        ? _icon(gymWorkoutIcon, accent: true)
                        : _activityIcon(session.typeId!, accent: true),
                    showChevron: true,
                    onTap: () => pick(ContinueChoice(session)),
                  ),
                if (templates.isEmpty)
                  GroupRow(
                    title: 'Create a gym template',
                    leading: _icon(Icons.add),
                    showChevron: true,
                    onTap: () => pick(const CreateTemplateChoice()),
                  )
                else
                  for (final t in templates)
                    Semantics(
                      button: true,
                      label: 'Start ${t.name} template',
                      excludeSemantics: true,
                      onTap: () => pick(TemplateChoice(t.id)),
                      child: GroupRow(
                        title: t.name,
                        subtitle: t.exercises.map((e) => e.name).join(' · '),
                        leading: _icon(gymWorkoutIcon),
                        onTap: () => pick(TemplateChoice(t.id)),
                      ),
                    ),
                for (final t in live)
                  GroupRow(
                    title: t.label,
                    subtitle: 'Live GPS',
                    leading: _activityIcon(t.id),
                    onTap: () => pick(TrackChoice(t.id)),
                  ),
                for (final t in other)
                  GroupRow(
                    title: t.label,
                    subtitle: 'Log for today',
                    leading: _activityIcon(t.id),
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

  static Widget _activityIcon(String typeId, {bool accent = false}) =>
      ActivityIcon(
        typeId,
        color: accent ? AppColors.accent : AppColors.textSecondary,
      );

  static Widget _icon(IconData icon, {bool accent = false}) =>
      Icon(icon, color: accent ? AppColors.accent : AppColors.textSecondary);
}
