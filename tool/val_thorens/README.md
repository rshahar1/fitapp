# Val Thorens simulated session (feature 019)

A generated snowboarding session on real Val Thorens geography, used by the tests and by the
dev-only GPS simulation (`--dart-define=SIMULATE_GPS=true`). It is **not a recording**: no
person's GPS data is in it.

## Sources, licences and attribution

| Data | Source | Licence | Attribution |
|---|---|---|---|
| Lift lines and pistes (way geometry) | OpenStreetMap via the Overpass API | [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/) | © OpenStreetMap contributors, <https://www.openstreetmap.org/copyright> |
| Terrain elevation, every 12 m along the ways | IGN RGE ALTI via the Géoplateforme altimetry service (`data.geopf.fr/altimetrie`) | [Licence Ouverte / Open Licence 2.0](https://www.etalab.gouv.fr/licence-ouverte-open-licence/) | IGN – RGE ALTI® |

`geometry.json` is a derived database of OpenStreetMap data and stays under ODbL 1.0; the
generated session (`lib/data/tracking/sim/val_thorens_session.dart`) is a produced work from it
and carries the same attribution in its header. The session data is only referenced by tests
and behind the compile-time `kSimulateGps` switch, so release builds do not contain it.

## The legs (OSM way ids)

| Leg | Ways | Height |
|---|---|---|
| Boismint chairlift | 22463109 | 2075 → 2664 m |
| Run 1: Blanchot link, Boismint, Boulevard Boismint | 47829378 (to the Boismint start), 104703255, 104703259, 104703252, 1463415343, 729236076, 47829377, 107201711 | 2664 → 2103 m |
| Caron gondola | 22462907 | 2103 → 2315 m |
| Cime Caron cable car | 22462908 | 2316 → 3178 m |
| Run 2: Col de l'Audzin, Gentiane | 1222284611, 256848047, 23455204, 31091703 | 3178 → 2075 m |

The session adds rests (base, top station, a break at the Caron base, a walk at the Caron mid
station, the Cime Caron summit, one stop mid-run, the base at the end), slope-dependent speed
with carved turns, steady lift speeds with station slow-downs, a cable-car altitude that follows
the cable, and slowly drifting GPS noise (σ 3 m horizontal, 4 m vertical, correlated over
about 100 s). Heights are above sea level; phones report ellipsoid heights, which does not
matter because detection only uses differences.

## Rebuilding

```bash
# Only when the geometry should be refreshed (network; public coordinates only, generic UA):
dart run tool/val_thorens/fetch_geometry.dart
# Offline and deterministic (same bytes every run):
dart run tool/gen_val_thorens_session.dart
```

The generator prints the legs and the reference totals and writes them into the CSV metadata
(`reference_runs`, `reference_ride_s`, `reference_lift_s`, `reference_rest_s`,
`reference_drop_m`, `reference_ride_m`, `reference_max_speed_mps`, `legs`). They are computed
from the noise-free truth, so tests compare the detector against what really happened.

## Watching it in the app

```bash
flutter run --dart-define-from-file=env/dev.json --dart-define=SIMULATE_GPS=true
```

Start → Snowboarding: an orange **SIMULATED GPS** bar shows on the setup and live screens. The
GPS is parked at the Boismint base until you tap Start, then the session replays; the 1× 5× 10×
30× chips change the speed at any time. Elapsed time and every stored timestamp follow the
simulation's virtual clock, so nothing is distorted by the speed-up. Notes:

- The saved activity is a normal activity (and syncs if cloud backup is signed in): delete it
  afterwards.
- After an accelerated replay the app's clock is ahead of the wall clock by the time saved
  (about 40 min at 30×) until the app restarts. It never goes backwards.
- A release build ignores the define (`kSimulateGps` is `false` when `kReleaseMode`).

## Android emulator route playback (1× platform check)

`dart run tool/gen_val_thorens_session.dart --gpx /tmp/val_thorens.gpx` writes the session as
GPX. In the emulator: Extended controls → Location → Routes / Import GPX → Play route at 1×.
This exercises the real geolocator plugin and foreground service, but the emulator speeds up
positions without speeding up time, so use only 1× (at 5× fixes exceed the 45 m/s limit and are
rejected), and it gives no control over accuracy or Doppler speed.
