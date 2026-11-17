import 'package:fitapp/data/tracking/sim/val_thorens_session.dart';
import 'package:fitapp/data/tracking/track_csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1, 9);

  test('parses metadata, header, blanks, offsets and empty fields', () {
    const text = '''
# a=1 b=x
# c=2.5

t_ms,lat,lon,alt,accuracy,speed
0,45.1,6.5,2000.5,5.0,1.5

2500,45.2,6.6,,8.0,
''';
    final csv = parseTrackCsv(text, start: start);
    expect(csv.meta, {'a': '1', 'b': 'x', 'c': '2.5'});
    expect(csv.samples, hasLength(2));
    final a = csv.samples[0];
    expect(a.t, start);
    expect(a.lat, 45.1);
    expect(a.lon, 6.5);
    expect(a.alt, 2000.5);
    expect(a.accuracy, 5.0);
    expect(a.speed, 1.5);
    final b = csv.samples[1];
    expect(b.t, start.add(const Duration(milliseconds: 2500)));
    expect(b.alt, isNull);
    expect(b.speed, isNull);
  });

  test('number parses a value and throws for a missing key', () {
    final csv = parseTrackCsv('# a=1\n', start: start);
    expect(csv.number('a'), 1.0);
    expect(() => csv.number('zzz'), throwsArgumentError);
  });

  group('bundled Val Thorens session', () {
    final csv = parseTrackCsv(valThorensSessionCsv, start: start);

    test('sample count matches the last leg', () {
      final legs = csv.meta['legs']!.split(',');
      final last = legs.last.split(':');
      expect(csv.samples.length, int.parse(last[2]) + 1);
    });

    test('all fixes are accurate', () {
      expect(csv.samples.every((s) => s.accuracy <= 20), isTrue);
    });

    test('has the reference metadata', () {
      for (final k in [
        'reference_runs',
        'reference_ride_s',
        'reference_lift_s',
        'reference_rest_s',
        'reference_drop_m',
        'reference_ride_m',
        'reference_max_speed_mps',
      ]) {
        expect(csv.meta, contains(k));
        expect(csv.number(k), isNonNegative);
      }
    });
  });
}
