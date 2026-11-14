# Proposal: Live GPS / Sensor Tracking (Running, Cycling, Snowboarding)

**Status**: Phase A (running/cycling) approved 2026-11-14 and implemented in feature 010 (`specs/010-live-gps-tracking/`); map: MapTiler (OpenStreetMap), raw points not kept, Health Connect not now; snowboarding pending a separate session | **Date**: 2026-11-14 | **Author**: Claude (for the owner)

**Context**: Feature 009 adds manual distance for running/cycling. This document answers whether
live tracking fits FitApp's current architecture, what it would take, and how it should look.
Building it requires an owner decision and a constitution amendment (Principle VII currently keeps
"tracking modules, routes" out of scope).

---

## 1. Verdict

| Question | Answer |
|---|---|
| Live GPS for running & cycling | **Feasible, moderate effort.** The architecture already has the three things it needs: an offline drift DB as source of truth, a crash-safe "live session" pattern (feature 007), and a platform-interface pattern for OS services (`RestAlerts` + `NoopRestAlerts`). |
| Live tracking for snowboarding | **Feasible, higher effort and lower accuracy.** Needs barometer fusion for vertical, a run/lift detector, and a battery-aware sampling profile for 6–8 h days. Works fully offline. |
| Auto-append to the app | Yes: a finished tracked session is saved as a normal `activities` row (with `distance_meters`, `duration_minutes` from 009) plus summary metrics and a simplified route, so History, week stats and streaks keep working unchanged. |

Nothing in the stack blocks it. The real work is (a) Android foreground-service plumbing and OEM
battery killers, (b) a pure-Dart signal-processing domain with fixture tests, and (c) data volume.

---

## 2. Platform & packages

| Need | Choice | Notes |
|---|---|---|
| Location stream | `geolocator` | Position stream with `AndroidSettings(foregroundNotificationConfig: …)` → runs as an Android foreground service with a persistent notification; iOS `AppleSettings(allowBackgroundLocationUpdates: true, showBackgroundLocationIndicator: true)`. Free, maintained. (Avoid `flutter_background_geolocation`: paid licence for Android release builds.) |
| Barometer (snowboard vertical) | `sensors_plus` barometer events | Relative altitude from pressure deltas; most mid/high-end Android phones have one. Fall back to smoothed GPS altitude when absent. |
| Map display | **None in phase A** — route drawn with `CustomPainter` on the dark theme | Keeps 100% offline and no third-party tile server receiving the user's location (constitution I, VI). Optional later: `flutter_map` + tiles behind an explicit opt-in. |
| Wake / notification | existing `flutter_local_notifications` not needed; geolocator's foreground notification carries live stats | |

**Android manifest**: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_LOCATION` (Android 14+), service `foregroundServiceType="location"`.
Because tracking is always started by the user from a visible screen, **"while in use" permission
is enough — no `ACCESS_BACKGROUND_LOCATION`**, which avoids the strict Play Store background-location
review. `POST_NOTIFICATIONS` is already declared.

**iOS**: `NSLocationWhenInUseUsageDescription`, `UIBackgroundModes: location`.

**Known risk**: Samsung/Xiaomi/Huawei battery managers can kill foreground services. Mitigation:
crash-safe persistence (below) + a one-time "Allow unrestricted battery" prompt via the existing
`app_settings` package.

---

## 3. Data model (schema v6 sketch)

```text
tracking_sessions        one row per live session (also the crash-recovery anchor)
  id, activity_type_id, state (active|paused|finished|discarded),
  started_at, ended_at?, paused_ms, profile (run|ride|snow), updated_at, dirty

track_points             raw samples, appended in batches every ~5 s (crash-safe)
  session_id, seq, t, lat, lon, alt_gps?, alt_baro?, accuracy_m, speed_mps?, is_paused

activities (+ columns)   the saved result — stays the single thing History/stats read
  source ('manual'|'gps'), moving_seconds?, elevation_gain_m?, max_speed_mps?,
  run_count?, vertical_drop_m?, route_polyline? (encoded, simplified), tracking_session_id?
```

- On **Finish**: in one transaction, compute the summary, write the `activities` row, store a
  Douglas-Peucker-simplified encoded polyline (~10–40 KB for a long ride), and delete the raw
  `track_points` (or keep them behind a "keep raw GPS" setting for GPX export later).
- Volume: 1 Hz × 1 h ≈ 3,600 points (~150 KB raw). A snowboard day with a 5 m distance filter is
  ~10–25k points — fine for SQLite, deleted after finish.
- All new tables keep UUIDs, `updated_at`, `dirty` (constitution I, Phase 2 sync-ready).

---

## 4. Domain (pure Dart, `lib/domain/tracking/`) — the core of the feature

A **replayable reducer**: `TrackState accumulate(TrackState s, TrackSample p)`. Because it is pure,
it is unit-tested with recorded GPX/CSV fixtures and is also the crash-recovery mechanism
(replay persisted points → identical state).

| Module | Purpose |
|---|---|
| `filter` | Drop fixes with accuracy > 20 m; reject impossible jumps (speed > per-sport max: run 12 m/s, ride 30 m/s, snow 35 m/s); light smoothing. |
| `distance` | Haversine sum of accepted segments. |
| `autopause` | Speed < threshold for N s ⇒ paused (moving time vs elapsed time). |
| `pace/speed` | Rolling 30 s current pace; average pace; per-km splits (running). |
| `elevation` | Gain/loss with 3 m hysteresis; baro-relative altitude when available, anchored to GPS. |
| `snow_runs` | State machine `lift ↔ descent ↔ idle` from vertical speed and duration: a **run** = continuous descent with drop > 30 m and mean vertical speed < −0.3 m/s; a **lift** = steady ascent. Produces run count, per-run drop/max speed/distance. |

---

## 5. Snowboarding specifics

**Trackable metrics**: run count, total vertical drop (sum of descents), max speed, average run
speed, total descent distance, ride time vs lift time, peak altitude, longest run.

**Resort / offline realities**:

| Factor | Impact | Mitigation |
|---|---|---|
| No mobile data | GPS still works (it never needs data); without A-GPS the **first fix is slower** (30 s – few min). | Pre-start "Acquiring GPS" state with accuracy indicator; allow "Start anyway". |
| No map tiles offline | Base map unavailable. | Route sketch via `CustomPainter` (no tiles) — already the phase-A design. |
| GPS altitude noise (±10–20 m) | Inflated vertical. | Barometer deltas + hysteresis; GPS-only phones get a "vertical is approximate" note. |
| Gondolas / trees / valleys | Lost or bad fixes; enclosed gondola cabins confuse lift detection. | Accuracy filter; treat gaps as non-moving; lift detection on altitude trend, not speed alone. |
| Cold | Li-ion capacity drops sharply below 0 °C; phones shut down early. | Battery profile: `LocationAccuracy.high` (not navigation), 5 m distance filter, ~1 sample / 2–5 s; low-battery warning; points are persisted so a dead phone loses at most a few seconds. |
| Max-speed spikes | Single bad fix → "142 km/h". | Use Doppler speed when accuracy is good; require ≥ 3 consecutive samples; cap per profile. |

Expect vertical/run count to be close to dedicated ski apps on barometer phones and noticeably
rougher on phones without one. Manual correction (merge/delete a run) is a later nicety.

---

## 6. UX design

### 6.1 Entry — one place, two modes

Keep the single **Log activity** entry on the Train tab. After picking a type:

- **Pilates / Functional** → manual sheet as today.
- **Running / Cycling / Snowboarding** → the sheet shows two actions:
  **Start live** (primary, accent) and **Log manually** (secondary; the current sheet with
  duration + distance). No new tab, no extra navigation for people who only log after the fact.

### 6.2 Flow

```text
Train ─▶ Log activity sheet ─▶ pick type
            │                       │
            │ (manual)              │ (Start live)
            ▼                       ▼
   Manual form (009)      /track/new?type=running   ── permission rationale ─▶ OS prompt
   Save ─▶ History                 │ Acquiring GPS  (accuracy chip: Searching / Weak / Good)
                                   │ [Start]  ·  "Start anyway"
                                   ▼
                         /track/:sessionId  (full-screen, like /workout)
                           live metrics · route sketch · Pause/Resume · Lock · Finish
                                   │  (app killed? reopen → resumes here from DB)
                                   ▼
                         Finish summary sheet: metrics, splits/runs, route, type, note
                           [Save] ─▶ activities row (source=gps) ─▶ History
                           [Discard] (confirm)
```

### 6.3 Live screen layout (portrait, one-handed, always dark)

| Area | Running | Cycling | Snowboarding |
|---|---|---|---|
| Hero metric | Elapsed time | Current speed | Vertical drop today |
| Tiles (2×2) | Distance · current pace · avg pace · last km split | Distance · avg speed · elapsed · elevation gain | Runs · max speed · current speed · ride time |
| Middle | Route sketch | Route sketch | Altitude sparkline + current state (Lift / Riding) |
| Footer (fixed) | **Pause/Resume** (one big tap) · **Finish** (hold 1 s) · **Lock** |

Constitution V fits naturally: fixed footer (no layout shift), 56 dp controls, Finish requires a hold
(destructive-ish), Lock prevents pocket taps, one accent colour, a fixed colour per metric,
tabular figures. The persistent notification mirrors 2–3 metrics so the phone can stay locked.

### 6.4 After saving

- History row: type icon + small GPS glyph; subtitle reuses 009's `distance · duration · pace|speed`.
- Tapping a GPS activity opens a read-only **Activity detail** screen (route, splits / runs list,
  elevation), with Edit (type, date, note — not GPS metrics) and Delete (confirm). Manual entries
  keep opening the 009 sheet.
- Only **one live session at a time** across gym workouts and tracked activities; Train shows an
  "In progress" banner (like the active workout) to jump back in.

---

## 7. State management (Riverpod, matching current layering)

```text
features/tracking/          TrackSetupScreen, LiveTrackScreen, FinishSheet, ActivityDetailScreen
        │ ref.watch(trackingControllerProvider.select(...))   ← slices keep rebuilds cheap
        ▼
data/tracking/
  TrackingController  (Notifier<TrackingUiState>)
      sealed state: Idle | Acquiring(accuracy) | Active(metrics) | Paused(metrics) | Finishing
      - subscribes to LocationSource / AltitudeSource streams
      - folds samples through the pure reducer (domain)
      - batches points to TrackingRepository every ~5 s / 20 points
  TrackingRepository  (all writes, one transaction on finish/discard)
  LocationSource      (interface)  ← GeolocatorLocationSource | FakeLocationSource (tests)
  AltitudeSource      (interface)  ← SensorsPlusBarometer | NoBarometer
        ▼
domain/tracking/      reducer, filters, autopause, splits, elevation, snow_runs  (pure, 100% tested)
```

- Mirrors `RestAlerts`/`NoopRestAlerts`: the platform is behind an interface, overridden in tests
  with a fake stream (e.g. replaying a GPX fixture at 100×) — widget and integration tests need
  no device GPS.
- **Crash recovery**: on launch, an `active|paused` `tracking_sessions` row ⇒ replay its points
  through the reducer and reopen `/track/:id` (same pattern as feature 007's `LiveSession`).
- The Dart isolate stays alive while the foreground service runs, so the controller can live in
  the main isolate; no separate background isolate is needed for phase A.

---

## 8. Alternative / complement: import from Health Connect / HealthKit

If the user already wears a watch, importing finished runs/rides (distance, duration, sometimes
route) via the `health` package gives better data with less battery cost and less code than live
GPS. It does not replace live tracking for phone-only users, but is a cheap phase worth weighing.

---

## 9. Suggested phasing

| Phase | Scope | Rough size |
|---|---|---|
| 009 (done in this change) | Pilates; manual distance for running/cycling | S |
| 010 Live run/ride | Permissions, foreground service, reducer (distance, autopause, pace, splits, elevation), live screen, finish sheet, crash recovery, detail screen, route sketch | L (≈ 2–3 features' worth) |
| 011 Snowboard tracking | Barometer source, run/lift detector, snow profile, snow live/summary layout | M–L |
| Later (opt-in) | Map tiles, GPX export, Health Connect import, miles setting | S–M each |

## 10. Decisions needed from the owner

1. Approve live tracking in scope (constitution VII → MINOR amendment) and in which phase order.
2. Map tiles: none (offline route sketch only) vs. opt-in online map.
3. Keep raw GPS points after finishing (enables GPX export) or keep only the simplified route.
4. Health Connect import: now, later, or never.
