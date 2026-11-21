import 'dart:typed_data';

import 'package:drift/drift.dart'
    show DatabaseConnection, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/image_sharer.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/share/share_card.dart';
import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/features/activities/activity_detail_screen.dart';
import 'package:fitapp/features/share/share_card_view.dart';
import 'package:fitapp/features/share/share_preview_screen.dart';
import 'package:fitapp/features/workout/widgets/finish_summary_sheet.dart';
import 'package:fitapp/features/workout/workout_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../data/helpers.dart';
import 'snow_test_data.dart';

class _FakeHaptics implements Haptics {
  @override
  void tick() {}
  @override
  void success() {}
  @override
  void warning() {}
}

class _FakeSharer implements ImageSharer {
  new({this.fail = false});

  final bool fail;
  final calls = <({Uint8List bytes, String fileName, String? text})>[];

  @override
  Future<void> sharePng(
    Uint8List bytes, {
    required String fileName,
    String? text,
  }) async {
    if (fail) throw Exception('no share sheet');
    calls.add((bytes: bytes, fileName: fileName, text: text));
  }
}

const _runId = '00000000-0000-4000-8000-0000000000b1';
const _pilatesId = '00000000-0000-4000-8000-0000000000b2';

void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }

  void bigView(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    AppDatabase? database,
    ImageSharer? sharer,
  }) async {
    bigView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database ?? db),
          hapticsProvider.overrideWithValue(_FakeHaptics()),
          imageSharerProvider.overrideWithValue(sharer ?? _FakeSharer()),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> addRun() => db
      .into(db.activities)
      .insert(
        ActivitiesCompanion.insert(
          id: _runId,
          updatedAt: DateTime.utc(2026, 3, 7, 10),
          typeId: 'running',
          startedAt: DateTime.utc(2026, 3, 7, 9),
          durationMinutes: const Value(30),
          distanceMeters: const Value(5000),
          source: const Value('gps'),
          movingSeconds: const Value(1700),
          route: Value(
            encodePolyline([
              for (var i = 0; i < 20; i++)
                (lat: 32.0 + i * 0.001, lon: 34.8 + (i.isEven ? 0.0005 : 0)),
            ]),
          ),
          splits: const Value('[300,290]'),
        ),
      );

  Future<void> addPilates() => db
      .into(db.activities)
      .insert(
        ActivitiesCompanion.insert(
          id: _pilatesId,
          updatedAt: DateTime.utc(2026, 3, 8, 10),
          typeId: 'pilates',
          startedAt: DateTime.utc(2026, 3, 8, 9),
          durationMinutes: const Value(45),
        ),
      );

  Future<ActivityRow> rowOf(WidgetTester tester, String id) async {
    final r = await tester.runAsync(
      () =>
          (db.select(db.activities)..where((a) => a.id.equals(id))).getSingle(),
    );
    return r!;
  }

  Future<void> pumpCard(WidgetTester tester, ShareCardData data) async {
    bigView(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(child: ShareCardView(data: data)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  group('ShareCardView', () {
    testWidgets('route card renders without overflow', (tester) async {
      await tester.runAsync(addRun);
      final data = shareCardOfActivity(await rowOf(tester, _runId));
      expect(data.layout, ShareLayout.route);
      await pumpCard(tester, data);
      expect(find.text('Running'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('snow card renders without overflow', (tester) async {
      await tester.runAsync(() => addSnowDay(db));
      final rows = await tester.runAsync(() => db.select(db.activities).get());
      final data = shareCardOfActivity(rows!.single);
      expect(data.layout, ShareLayout.snow);
      await pumpCard(tester, data);
      expect(find.textContaining('Ride'), findsWidgets);
      expect(find.textContaining('Lift'), findsWidgets);
      expect(find.textContaining('Rest'), findsWidgets);
      await unmount(tester);
    });

    for (final (count, height, columns) in [
      (8, 450.0, 1),
      (11, 540.0, 1),
      (20, 610.0, 2),
      (40, 640.0, 2),
    ]) {
      testWidgets('strength card lists all $count exercises', (tester) async {
        final data = workoutShareCard(
          WorkoutShareInput(
            name: 'Big day',
            startedAt: DateTime.utc(2026, 3, 7, 9),
            endedAt: DateTime.utc(2026, 3, 7, 10, 15),
            exercises: [
              for (var i = 1; i <= count; i++)
                ShareExercise(
                  name: 'Exercise number $i',
                  sets: const [(60, 8), (60, 8), (60, 8)],
                ),
            ],
          ),
        );
        await pumpCard(tester, data);
        final layout = ShareCardView.listLayout(count);
        expect(layout.cardHeight, closeTo(height, 1));
        expect(layout.columns, columns);
        expect(
          tester.getSize(find.byType(ShareCardView)).height,
          closeTo(height, 1),
        );
        for (var i = 1; i <= count; i++) {
          expect(find.text('Exercise number $i'), findsOneWidget);
        }
        expect(find.textContaining('more exercise'), findsNothing);
        await unmount(tester);
      });
    }

    testWidgets('basic card with no stats says Logged in FitApp', (
      tester,
    ) async {
      final data = activityShareCard(
        ActivityShareInput(
          typeId: 'pilates',
          startedAt: DateTime.utc(2026, 3, 8, 9),
        ),
      );
      expect(data.stats, isEmpty);
      await pumpCard(tester, data);
      expect(find.text('Logged in FitApp'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('basic pilates card shows 45 min', (tester) async {
      await tester.runAsync(addPilates);
      final data = shareCardOfActivity(await rowOf(tester, _pilatesId));
      await pumpCard(tester, data);
      expect(find.text('45 min'), findsWidgets);
      await unmount(tester);
    });
  });

  group('SharePreviewScreen', () {
    testWidgets('Share image hands a PNG to the sharer', (tester) async {
      await tester.runAsync(addRun);
      final sharer = _FakeSharer();
      await pump(
        tester,
        const SharePreviewScreen(subject: ShareSubject.activity, id: _runId),
        sharer: sharer,
      );
      expect(find.text('SHARE IMAGE'), findsOneWidget);
      await tester.tap(find.text('SHARE IMAGE'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(sharer.calls, hasLength(1));
      final c = sharer.calls.single;
      expect(c.bytes, isNotEmpty);
      expect(c.bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(
        c.fileName,
        matches(RegExp(r'^fitapp-running-\d{4}-\d{2}-\d{2}\.png$')),
      );
      expect(c.text, startsWith('Running'));
      await unmount(tester);
    });

    testWidgets(
      'gym share sends the image only and ignores later database writes',
      (tester) async {
        final h = Harness();
        addTearDown(h.close);
        await tester.runAsync(h.plan);
        final session = await tester.runAsync(
          () => h.session(const [(20, 10), (20, 10)]),
        );
        final sharer = _FakeSharer();
        await pump(
          tester,
          SharePreviewScreen(subject: ShareSubject.workout, id: session!.$1),
          database: h.db,
          sharer: sharer,
        );
        expect(find.byType(ShareCardView), findsOneWidget);
        final before = tester.widget<ShareCardView>(find.byType(ShareCardView));
        // Sync-like churn after finishing: writes keep re-emitting the
        // workout stream while the preview is open.
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(
            () => h.db.customStatement('UPDATE workouts SET dirty = 0'),
          );
          await tester.pump();
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        final after = tester.widget<ShareCardView>(find.byType(ShareCardView));
        expect(identical(after.data, before.data), isTrue);
        await tester.tap(find.text('SHARE IMAGE'));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump();
        expect(sharer.calls, hasLength(1));
        expect(sharer.calls.single.text, isNull);
        expect(sharer.calls.single.bytes.sublist(0, 4), [
          0x89,
          0x50,
          0x4E,
          0x47,
        ]);
        await unmount(tester);
      },
    );

    testWidgets('a failing sharer shows the error snackbar', (tester) async {
      await tester.runAsync(addRun);
      await pump(
        tester,
        const SharePreviewScreen(subject: ShareSubject.activity, id: _runId),
        sharer: _FakeSharer(fail: true),
      );
      await tester.tap(find.text('SHARE IMAGE'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Could not share the image.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a missing id shows Nothing to share', (tester) async {
      await pump(
        tester,
        const SharePreviewScreen(
          subject: ShareSubject.activity,
          id: 'does-not-exist',
        ),
      );
      expect(find.text('Nothing to share'), findsOneWidget);
      expect(find.text('SHARE IMAGE'), findsNothing);
      await unmount(tester);
    });
  });

  group('entry points', () {
    testWidgets('activity detail offers Share in the overflow menu', (
      tester,
    ) async {
      await tester.runAsync(addRun);
      await pump(tester, const ActivityDetailScreen(activityId: _runId));
      expect(find.byTooltip('Share activity'), findsNothing);
      expect(find.byIcon(Icons.adaptive.share), findsNothing);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Share'), findsOneWidget);
      expect(find.byIcon(Icons.adaptive.share), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('finished workout offers Share in the overflow menu', (
      tester,
    ) async {
      final h = Harness();
      addTearDown(h.close);
      await tester.runAsync(h.plan);
      final session = await tester.runAsync(
        () => h.session(const [(20, 10), (20, 10)]),
      );
      await pump(tester, WorkoutScreen(workoutId: session!.$1), database: h.db);
      expect(find.byTooltip('Share workout'), findsNothing);
      await tester.tap(find.byTooltip('Workout options'));
      await tester.pumpAndSettle();
      expect(find.text('Share'), findsOneWidget);
      expect(find.byIcon(Icons.adaptive.share), findsOneWidget);
      await unmount(tester);
    });
  });

  group('finish summary', () {
    testWidgets('Share workout resolves to FinishChoice.share', (tester) async {
      FinishChoice? choice;
      bigView(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  choice = await showFinishSummary(
                    context,
                    const FinishResult(outcomes: [], discarded: false),
                  );
                },
                child: const Text('Open summary'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open summary'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SHARE WORKOUT'));
      await tester.pumpAndSettle();
      expect(choice, FinishChoice.share);
    });
  });
}
