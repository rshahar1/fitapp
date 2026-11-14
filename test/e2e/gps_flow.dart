import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/app.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:fitapp/features/history/route_thumbnail.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_location_source.dart';

class _NoHaptics implements Haptics {
  @override
  void success() {}
  @override
  void tick() {}
  @override
  void warning() {}
}

/// A generated 5 km run: one fix per second heading north at about 3.3 m/s
/// (5:00 /km) for 25 minutes. Built in code, so it also runs on a device where
/// `test/fixtures` files cannot be read.
List<TrackSample> generatedRun5k(DateTime start) => [
  for (var s = 0; s <= 1500; s++)
    TrackSample(
      t: start.add(Duration(seconds: s)),
      lat: 32.08 + s * 0.00003,
      lon: 34.78,
      accuracy: 5,
    ),
];

/// Shared GPS flow: Train → Log activity → Running → Start live → Start →
/// replay a 5 km run → hold Finish → Save → History shows the GPS activity
/// with a route thumbnail → its detail screen. Used by the widget e2e test
/// and the on-device integration test.
Future<void> runGpsFlow(
  WidgetTester tester, {
  required Future<void> Function() settle,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  final source = FakeLocationSource();
  final start = DateTime.now().toUtc().subtract(const Duration(hours: 1));
  final track = generatedRun5k(start);
  var now = start;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        hapticsProvider.overrideWithValue(_NoHaptics()),
        restAlertsProvider.overrideWithValue(const NoopRestAlerts()),
        locationSourceProvider.overrideWithValue(source),
        clockProvider.overrideWithValue(() => now),
        mapTilesEnabledProvider.overrideWithValue(false),
      ],
      child: const FitApp(),
    ),
  );
  await settle();

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pump();
    await tester.tap(f.first);
    await settle();
  }

  await tap(find.text('LOG ACTIVITY'));
  await tap(find.text('Running'));
  await tap(find.text('START LIVE'));
  expect(find.text('Searching for GPS'), findsOneWidget);

  source.emit(track.first);
  await tester.pump();
  await tap(find.text('START'));
  expect(find.text('TIME'), findsOneWidget);

  for (var i = 1; i < track.length; i++) {
    now = track[i].t;
    source.emit(track[i]);
    if (i % 100 == 0) await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(seconds: 1));

  final gesture = await tester.startGesture(
    tester.getCenter(find.text('FINISH')),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1100));
  await gesture.up();
  await settle();
  expect(find.text('Running summary'), findsOneWidget);

  await tap(find.text('SAVE'));
  expect(find.textContaining('Running · 5'), findsOneWidget);
  expect(find.byType(RouteThumbnail), findsOneWidget);

  await tap(find.byType(RouteThumbnail));
  expect(find.text('SPLITS'), findsOneWidget);
  expect(find.text('AVG PACE'), findsOneWidget);
  expect(find.byType(RouteMap), findsOneWidget);
}
