import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/domain/tracking/snow_review.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/features/tracking/map_style.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:fitapp/features/tracking/widgets/snow_route_spans.dart';
import 'package:fitapp/features/tracking/widgets/snow_time_bar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:material_ui/material_ui.dart';

void main() {
  group('MapStyle', () {
    test('tile urls use the MapTiler map id and format', () {
      expect(MapStyle.dark.urlTemplate, contains('/maps/dataviz-dark/256/'));
      expect(MapStyle.dark.urlTemplate, contains('{y}.png?key='));
      expect(MapStyle.winter.urlTemplate, contains('/maps/winter-v2/256/'));
      expect(MapStyle.satellite.urlTemplate, contains('/maps/satellite/256/'));
      expect(MapStyle.satellite.urlTemplate, contains('{y}.jpg?key='));
      expect(
        [for (final s in MapStyle.values) s.label],
        ['Dark', 'Winter', 'Satellite'],
      );
    });

    test('parse falls back to dark', () {
      expect(MapStyle.parse('winter'), MapStyle.winter);
      expect(MapStyle.parse('satellite'), MapStyle.satellite);
      expect(MapStyle.parse(null), MapStyle.dark);
      expect(MapStyle.parse('neon'), MapStyle.dark);
    });
  });

  group('mapStyleProvider', () {
    late AppDatabase db;
    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    });
    tearDown(() => db.close());

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      return c..listen(mapStyleProvider, (_, _) {});
    }

    test('starts dark, remembers the choice across restarts', () async {
      final a = container();
      expect(a.read(mapStyleProvider), MapStyle.dark);
      await a.read(mapStyleProvider.notifier).choose(MapStyle.satellite);
      expect(a.read(mapStyleProvider), MapStyle.satellite);
      expect(await SettingsRepository(db).readFlag(mapStyleKey), 'satellite');

      final b = container();
      expect(b.read(mapStyleProvider), MapStyle.dark);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(b.read(mapStyleProvider), MapStyle.satellite);
    });

    test('is not part of the synced settings', () async {
      final c = container();
      await c.read(mapStyleProvider.notifier).choose(MapStyle.winter);
      final synced = await SettingsRepository(db).syncedSettings();
      expect(synced.keys, isNot(contains(mapStyleKey)));
    });
  });

  group('route spans', () {
    const parts = [
      SnowRoutePart(kind: SnowKind.rest, offset: 0, count: 2),
      SnowRoutePart(kind: SnowKind.lift, offset: 2, count: 3),
      SnowRoutePart(
        kind: SnowKind.run,
        offset: 5,
        count: 6,
        speedsKmh: [0, 5, 28, 29, 45, 50],
      ),
      SnowRoutePart(kind: SnowKind.lift, offset: 11, count: 1),
      // Damaged: speeds do not match the points.
      SnowRoutePart(
        kind: SnowKind.run,
        offset: 12,
        count: 4,
        speedsKmh: [10, 20],
      ),
    ];

    test('lifts are muted; single-point lifts are skipped', () {
      expect(snowLiftSpans(parts), [
        const RouteSpan(2, 4, AppColors.routeLift),
      ]);
    });

    test('runs are split where the speed colour changes', () {
      // Scale 0..50 in five buckets of 10 km/h; a stretch takes the colour
      // of its faster end: 5 | 28 29 | 45 50.
      expect(snowHeatSpans(parts, 50), [
        RouteSpan(5, 6, AppColors.heat[0]),
        RouteSpan(6, 8, AppColors.heat[2]),
        RouteSpan(8, 10, AppColors.heat[4]),
      ]);
    });

    test('a run of one colour is one span; nothing without runs', () {
      const one = [
        SnowRoutePart(
          kind: SnowKind.run,
          offset: 0,
          count: 3,
          speedsKmh: [20, 22, 25],
        ),
      ];
      expect(snowHeatSpans(one, 50), [RouteSpan(0, 2, AppColors.heat[2])]);
      expect(snowHeatSpans(const [], 50), isEmpty);
    });

    test('spanPoints guards against ranges outside the route', () {
      const route = [LatLng(0, 0), LatLng(0, 1), LatLng(0, 2)];
      const c = AppColors.accent;
      expect(spanPoints(route, const RouteSpan(0, 2, c)), route);
      expect(spanPoints(route, const RouteSpan(1, 2, c)), route.sublist(1));
      expect(spanPoints(route, const RouteSpan(1, 3, c)), isEmpty);
      expect(spanPoints(route, const RouteSpan(-1, 2, c)), isEmpty);
      expect(spanPoints(route, const RouteSpan(2, 2, c)), isEmpty);
      expect(
        const RouteSpan(1, 2, c).hashCode,
        const RouteSpan(1, 2, c).hashCode,
      );
    });
  });

  group('RouteMap', () {
    const route = [
      LatLng(46, 7),
      LatLng(46.001, 7),
      LatLng(46.002, 7.001),
      LatLng(46.003, 7.001),
    ];
    const spans = [RouteSpan(1, 3, AppColors.routeLift)];

    Future<void> pump(
      WidgetTester tester, {
      required bool tiles,
      MapStyle style = MapStyle.dark,
      List<LatLng>? fitTo,
    }) async {
      final onError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.exceptionAsString().contains('overflowed')) {
          onError?.call(details);
        }
      };
      addTearDown(() => FlutterError.onError = onError);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mapTilesEnabledProvider.overrideWithValue(tiles)],
          child: MaterialApp(
            home: SizedBox(
              width: 300,
              height: 300,
              child: RouteMap(
                route: route,
                spans: spans,
                style: style,
                fitTo: fitTo,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('tile map draws spans over the base line in their colour', (
      tester,
    ) async {
      await pump(tester, tiles: true, style: MapStyle.winter);
      final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(layer.polylines, hasLength(2));
      expect(layer.polylines[0].color, AppColors.accent);
      expect(layer.polylines[0].points, route);
      expect(layer.polylines[1].color, AppColors.routeLift);
      expect(layer.polylines[1].points, route.sublist(1));
      // Light tiles get an edge around the line.
      expect(layer.polylines[0].borderStrokeWidth, greaterThan(0));
      final tile = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(tile.urlTemplate, MapStyle.winter.urlTemplate);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('dark tiles keep the plain line; fitTo frames the camera', (
      tester,
    ) async {
      await pump(tester, tiles: true, fitTo: route.sublist(0, 2));
      final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(layer.polylines[0].borderStrokeWidth, 0);
      final camera = MapCamera.of(tester.element(find.byType(TileLayer)));
      expect(camera.center.latitude, closeTo(46.0005, 1e-4));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('without tiles the painter draws the route and spans', (
      tester,
    ) async {
      await pump(tester, tiles: false);
      expect(find.byType(TileLayer), findsNothing);
      await expectLater(
        find.byType(RouteMap),
        paints
          ..path(color: AppColors.accent)
          ..path(color: AppColors.routeLift),
      );
      // Framing a part of the route still paints, clipped to the box.
      await pump(tester, tiles: false, fitTo: route.sublist(0, 2));
      await expectLater(
        find.byType(RouteMap),
        paints
          ..clipRect()
          ..path(color: AppColors.accent),
      );
    });
  });

  group('SnowTimeBar', () {
    Future<void> pump(WidgetTester tester, int ride, int lift, int rest) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: SnowTimeBar(
                  rideSeconds: ride,
                  liftSeconds: lift,
                  restSeconds: rest,
                ),
              ),
            ),
          ),
        );

    testWidgets('legend and proportional parts', (tester) async {
      await pump(tester, 3600, 1800, 600);
      expect(find.text('Ride 1h 0m'), findsOneWidget);
      expect(find.text('Lift 30m'), findsOneWidget);
      expect(find.text('Rest 10m'), findsOneWidget);
      final flexes = [
        for (final e in tester.widgetList<Expanded>(
          find.descendant(
            of: find.byType(ClipRRect),
            matching: find.byType(Expanded),
          ),
        ))
          e.flex,
      ];
      expect(flexes, [3600, 1800, 600]);
      // The coloured parts fill the bar's height.
      final part = find
          .descendant(
            of: find.byType(ClipRRect),
            matching: find.byType(ColoredBox),
          )
          .first;
      expect(tester.getSize(part).height, greaterThan(5));
      expect(tester.getSize(part).width, closeTo(320 * 0.6, 1));
      expect(
        tester.getSemantics(find.byType(SnowTimeBar)).label,
        'Time split: Ride 1h 0m, Lift 30m, Rest 10m',
      );
    });

    testWidgets('zero parts are left out; an empty day shows a blank bar', (
      tester,
    ) async {
      await pump(tester, 120, 0, 60);
      expect(
        find.descendant(
          of: find.byType(ClipRRect),
          matching: find.byType(Expanded),
        ),
        findsNWidgets(2),
      );
      await pump(tester, 0, 0, 0);
      expect(
        find.descendant(
          of: find.byType(ClipRRect),
          matching: find.byType(Expanded),
        ),
        findsNothing,
      );
      expect(find.text('Ride <1m'), findsOneWidget);
    });
  });
}
