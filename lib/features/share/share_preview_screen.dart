import 'dart:ui' as ui;

import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/image_sharer.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/share/share_card.dart';
import 'package:fitapp/features/share/share_card_view.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// What a share preview shows.
enum ShareSubject { workout, activity }

/// Card data for a stored activity.
ShareCardData shareCardOfActivity(ActivityRow a) => activityShareCard(
  ActivityShareInput(
    typeId: a.typeId,
    startedAt: a.startedAt,
    source: a.source,
    durationMinutes: a.durationMinutes,
    distanceMeters: a.distanceMeters,
    movingSeconds: a.movingSeconds,
    elevationGainMeters: a.elevationGainMeters,
    route: a.route,
    splits: a.splits,
    maxSpeedMps: a.maxSpeedMps,
    verticalDropMeters: a.verticalDropMeters,
    runCount: a.runCount,
    liftSeconds: a.liftSeconds,
    restSeconds: a.restSeconds,
    segments: a.segments,
  ),
);

/// Card data for a finished gym workout.
ShareCardData shareCardOfWorkout(WorkoutDetail d) => workoutShareCard(
  WorkoutShareInput(
    name: d.workout.name,
    startedAt: d.workout.startedAt,
    endedAt: d.workout.endedAt,
    exercises: [
      for (final e in d.exercises)
        ShareExercise(
          name: e.exercise.name,
          perHand: e.exercise.isPerHand,
          sets: [for (final s in e.sets) (s.weight, s.reps)],
        ),
    ],
  ),
);

/// Preview of the share image of a finished workout or an activity, with a
/// button that hands the PNG to the system share sheet (feature 027).
class SharePreviewScreen extends ConsumerStatefulWidget {
  const new({required this.subject, required this.id, super.key});

  final ShareSubject subject;
  final String id;

  @override
  ConsumerState<SharePreviewScreen> createState() => _SharePreviewState();
}

class _SharePreviewState extends ConsumerState<SharePreviewScreen> {
  final _boundary = GlobalKey();
  bool _busy = false;

  /// The card, or null while loading or when there is nothing to share.
  AsyncValue<ShareCardData?> _card() => switch (widget.subject) {
    ShareSubject.activity =>
      ref
          .watch(activityProvider(widget.id))
          .whenData((a) => a == null ? null : shareCardOfActivity(a)),
    ShareSubject.workout =>
      ref
          .watch(workoutDetailProvider(widget.id))
          .whenData(
            (d) => d == null || !d.isFinished ? null : shareCardOfWorkout(d),
          ),
  };

  Future<void> _share(ShareCardData data) async {
    final messenger = ScaffoldMessenger.of(context);
    final sharer = ref.read(imageSharerProvider);
    setState(() => _busy = true);
    try {
      final boundary =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: ShareCardSize.pixelRatio,
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await sharer.sharePng(
        bytes!.buffer.asUint8List(),
        fileName: shareFileName(data.typeId, data.startedAt),
        text: shareCaption(data),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not share the image.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card();
    final data = card.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.subject == ShareSubject.workout
              ? 'Share workout'
              : 'Share activity',
        ),
      ),
      body: card.hasError
          ? const Center(child: Text('Could not load this session.'))
          : data == null
          ? (card.isLoading
                ? const Center(child: CircularProgressIndicator())
                : EmptyState(
                    icon: Icons.adaptive.share,
                    title: 'Nothing to share',
                    message:
                        'This session no longer exists or is not finished.',
                  ))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Space.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          child: Semantics(
                            label: 'Preview of the image to share',
                            image: true,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(Radii.card),
                              child: RepaintBoundary(
                                key: _boundary,
                                child: ShareCardView(data: data),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.m),
                    AppButton(
                      label: _busy ? 'Preparing…' : 'Share image',
                      icon: Icons.adaptive.share,
                      expand: true,
                      onPressed: _busy ? null : () => _share(data),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
