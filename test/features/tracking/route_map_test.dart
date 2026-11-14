import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('camera leaves the world view when the first point arrives', (
    tester,
  ) async {
    // The test font makes the attribution text overflow; that is not under
    // test here.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed')) {
        onError?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = onError);
    LatLng? point;
    late StateSetter set;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapTilesEnabledProvider.overrideWithValue(true)],
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return SizedBox(
                width: 300,
                height: 300,
                child: RouteMap(
                  route: const [],
                  current: point,
                  followCurrent: true,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    MapCamera camera() =>
        MapCamera.of(tester.element(find.byType(TileLayer).first));
    expect(camera().zoom, 2);

    set(() => point = const LatLng(32.08, 34.78));
    await tester.pump();
    await tester.pump();
    expect(camera().zoom, 16);
    expect(camera().center.latitude, closeTo(32.08, 1e-6));
    await tester.pumpWidget(const SizedBox());
  });
}
