import 'package:drift/drift.dart' show Value;
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/repositories/tracking_repository.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';

import '../domain/tracking/snow_fixtures.dart';

/// Three runs of clearly different speed, length and drop: run 1 has the
/// most vertical, run 2 is the fastest, run 3 is the longest.
const threeRunDay = [
  SnowLeg.stand(60),
  SnowLeg.lift(420),
  SnowLeg.stand(40),
  SnowLeg.run(240, speed: 8),
  SnowLeg.stand(120),
  SnowLeg.lift(300),
  SnowLeg.stand(40),
  SnowLeg.run(150, speed: 18, vertical: 2),
  SnowLeg.stand(120),
  SnowLeg.lift(300),
  SnowLeg.stand(40),
  SnowLeg.run(300, speed: 11, vertical: 1),
  SnowLeg.stand(60),
];

/// The stored form of the synthetic day made of [legs].
SnowSummary snowSummaryOf(List<SnowLeg> legs) => TrackingRepository.snowSummary(
  buildSnowDay(legs).samples,
  startedAt: snowStart,
);

/// Inserts a tracked snowboarding day made of [legs] the way
/// `TrackingRepository.finish` stores it, and returns its id.
Future<String> addSnowDay(
  AppDatabase db, {
  List<SnowLeg> legs = threeRunDay,
  String id = '00000000-0000-4000-8000-0000000000a1',
  String? notes,
}) async {
  final f = buildSnowDay(legs);
  final s = TrackingRepository.snowSummary(f.samples, startedAt: snowStart);
  await db
      .into(db.activities)
      .insert(
        ActivitiesCompanion.insert(
          id: id,
          typeId: 'snowboarding',
          startedAt: snowStart,
          durationMinutes: Value((f.samples.length / 60).round()),
          distanceMeters: Value(s.rideMeters),
          notes: Value(notes),
          source: const Value('gps'),
          movingSeconds: Value(s.rideSeconds),
          route: Value(s.route),
          verticalDropMeters: Value(s.dropMeters),
          runCount: Value(s.runCount),
          maxSpeedMps: Value(s.maxSpeedMps),
          liftSeconds: Value(s.liftSeconds),
          restSeconds: Value(s.restSeconds),
          segments: Value(encodeSnowRecords(s.records)),
          updatedAt: db.now(),
        ),
      );
  return id;
}
