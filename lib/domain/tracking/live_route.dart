/// The route drawn while tracking, kept small enough to redraw every second
/// over a whole day (feature 017). Pure Dart.
library;

import 'package:fitapp/domain/tracking/geo.dart';

/// A growing route that thins itself: once it holds more than [maxPoints]
/// it drops every other point and from then on only takes points at least
/// [spacingMeters] from the last one, doubling that distance each time.
/// Short tracks keep every point.
class LiveRoute {
  new({this.maxPoints = 2000, this.firstSpacingMeters = 10});

  final int maxPoints;
  final double firstSpacingMeters;

  final List<GeoPoint> _points = [];
  final List<int> _tags = [];
  double _spacing = 0;

  /// The points kept so far, oldest first.
  List<GeoPoint> get points => List.unmodifiable(_points);

  int get length => _points.length;

  /// Minimum distance between new points; 0 until the first thinning.
  double get spacingMeters => _spacing;

  /// Adds [p]. [tag] is any number that grows along the track (e.g. the
  /// fix's index); [spans] maps ranges of it back to point indices.
  void add(GeoPoint p, int tag) {
    if (_points.isNotEmpty && _spacing > 0) {
      final last = _points.last;
      if (haversineMeters(last.lat, last.lon, p.lat, p.lon) < _spacing) return;
    }
    _points.add(p);
    _tags.add(tag);
    if (_points.length <= maxPoints) return;
    // Keep the even positions and always the newest point.
    final keptPoints = <GeoPoint>[];
    final keptTags = <int>[];
    for (var i = 0; i < _points.length; i++) {
      if (i.isEven || i == _points.length - 1) {
        keptPoints.add(_points[i]);
        keptTags.add(_tags[i]);
      }
    }
    _points
      ..clear()
      ..addAll(keptPoints);
    _tags
      ..clear()
      ..addAll(keptTags);
    _spacing = _spacing == 0 ? firstSpacingMeters : _spacing * 2;
  }

  void clear() {
    _points.clear();
    _tags.clear();
    _spacing = 0;
  }

  /// For each tag range (inclusive, in ascending order), the range of point
  /// indices whose tags fall inside it. Ranges covering fewer than two
  /// points are left out.
  List<({int from, int to})> spans(Iterable<({int first, int last})> ranges) {
    final out = <({int from, int to})>[];
    var i = 0;
    for (final r in ranges) {
      while (i < _tags.length && _tags[i] < r.first) {
        i++;
      }
      final from = i;
      var to = i - 1;
      while (i < _tags.length && _tags[i] <= r.last) {
        to = i;
        i++;
      }
      if (to > from) out.add((from: from, to: to));
      // Neighbouring ranges share their boundary fix.
      if (to >= from) i = to;
    }
    return out;
  }
}
