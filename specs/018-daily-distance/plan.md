# Plan: 018-daily-distance
- `StepSource`: add `distanceAccess()`, `requestDistanceAccess()`, `distanceBetween()` (metres);
  `requestAccess()` asks for steps + distance. Health Connect impl uses
  `getHealthIntervalDataFromTypes(DISTANCE_DELTA)` (aggregate => deduped), summed.
- Manifest: `READ_DISTANCE`.
- Providers: `todayDistanceProvider`, `dayDistance` family, `distanceAccessProvider`.
- `formatKm` in `core/format.dart`; Steps card and History `_DaySteps` show it.
- Update privacy/intro copy; fakes + tests.
