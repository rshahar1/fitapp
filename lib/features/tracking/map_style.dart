import 'package:fitapp/data/providers.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local setting key of the chosen map style (not synced).
const mapStyleKey = 'map_style';

/// The map style chosen on this device (feature 017). Starts dark and
/// switches to the stored choice once it is read.
class MapStyleController extends Notifier<MapStyle> {
  @override
  MapStyle build() {
    Future<void>(() async {
      final stored = await ref
          .read(settingsRepositoryProvider)
          .readFlag(mapStyleKey);
      if (ref.mounted && stored != null) state = MapStyle.parse(stored);
    });
    return MapStyle.dark;
  }

  /// Switches to [style] and remembers it.
  Future<void> choose(MapStyle style) async {
    state = style;
    await ref
        .read(settingsRepositoryProvider)
        .writeFlag(mapStyleKey, style.name);
  }
}

final mapStyleProvider = NotifierProvider<MapStyleController, MapStyle>(
  MapStyleController.new,
);
