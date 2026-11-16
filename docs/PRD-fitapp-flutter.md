# FitApp: Product Requirements Document (Flutter)

| | |
|---|---|
| **Version** | 2.9, 16 Nov 2026 (see the changelog in section 17) |
| **Platform** | Android first (APK), iOS later |
| **Framework** | Flutter (Dart), built from https://flutter.dev |
| **Status** | Ready to implement from scratch in a new repository |
| **Supersedes** | v1 PRD and the Expo / React Native prototype (`gym-tracker`, private GitHub repo) |

> **How to use this document in a new Claude session**
> Paste or attach this file and say: *"Implement this PRD milestone by milestone, starting with M0. After each
> milestone, run `flutter analyze` and `flutter test`, show me the result, and commit."* Section 13 lists the
> milestones and their acceptance criteria. Section 12 lists test scenarios that must pass. Everything marked
> **MUST** is required; **SHOULD** is strongly recommended; **LATER** is out of scope for v1.

---

## 1. Product overview

A minimalist, fast, offline-first gym workout logger built around one idea: **automatic progressive overload**.
The user logs sets between exercises with large tap targets and almost no typing. The app pre-fills every set
from the user's plan and last session, and moves the working weight up automatically when they earn it.
Other sports (functional training, cycling, snowboarding, running, Pilates) can be logged as lightweight
activities that count toward consistency; running, cycling and snowboarding can carry a manually entered distance or be recorded live with GPS (sections 5.8 and 5.10).

### 1.1 Goals
1. Log a full set in **one tap** when the user did what was planned.
2. Apply the progression rule (section 4) automatically and correctly, including when past workouts are
   edited, resumed or deleted.
3. Show progress clearly: charts per exercise, personal records, and "compared to last session" deltas.
4. Work **fully offline**. A gym with no signal must never block logging.
5. Clean, safe, well-tested codebase that follows Flutter and Dart best practices.
6. Log other sport activities (date, optional duration, optional distance for running, cycling and snowboarding, and note) so the weekly stats reflect all training.

### 1.2 Non-goals (explicitly out of scope)
- **Social features, friends, feed and leaderboards were dropped by the owner.** Do not build friend tables,
  feeds, sharing or leaderboards. Do not add `visibility` or friendship columns "for later".
- Exercise videos or "How to" content.
- AI-generated workouts.
- **Warm-up sets, and set types in general, in v1.** The owner dropped warm-up sets. Do not add a set-type column,
  W/D/F badges or special warm-up handling. (Drop and failure sets are LATER, section 14.)
- Smart-watch apps.
- Paid features or ads.

### 1.3 Target user and context
A lifter in a gym, phone in hand between sets, often sweaty, distracted, and on poor or no connectivity. Every
screen must be usable one-handed, at a glance, in a dark gym.

---

## 2. Design direction

### 2.1 Model: Hevy (https://www.hevyapp.com)
Use **Hevy as the model for overall design, information architecture and high-level UX**. Take inspiration from
its patterns; **do not copy its branding, logo, name, icons, illustrations, copy or exact layouts.** The app has
its own name and identity: **FitApp**.

Hevy patterns to adopt:

| Hevy pattern | How it applies here |
|---|---|
| Workout screen header with live **Duration · Volume · Sets** and a prominent **Finish** button | **MUST** (M3) |
| Exercise card: exercise name (accent colored), `⋮` menu, optional **notes** field, per-exercise **rest timer** | Name, menu and rest timer **MUST** (60 s default, configurable: section 5.7); notes **SHOULD** |
| **Set table** with columns **SET · PREVIOUS · KG · REPS · ✓** | **MUST**. "Previous" shows the same set from the last session, e.g. `22.5 kg × 10` |
| Completed set rows highlighted in the accent color, with a checked box | **MUST** |
| Set type badges: **W** (warm-up), **D** (drop), **F** (failure) | **Not in v1.** Warm-up was dropped by the owner; D and F are **LATER**. Every set is a normal set. |
| **+ Add Set** under the table and a full-width **Add Exercise** button at the bottom | **MUST** |
| Exercise detail page with **Summary / History** tabs; chart with metric chips (**Heaviest Weight · One Rep Max · Best Set Volume**); **PR** badge | **MUST** (M5), but there is no "How to" tab |
| Bottom navigation with a few clear destinations | **MUST** (section 6) |
| Routines (saved workout templates) | Templates exist since feature 003 and carry their own progression (feature 005); folders are **LATER** |

### 2.2 Visual identity (keep these customizations from the prototype)
The owner explicitly approved this look. Hevy is the *structure* model; this is the *skin*.

- **Always dark.** Pure black background with dark grey grouped cards. There is no light theme in v1.
- **One accent color** for every action: buttons, active tab, checkmarks, completed rows.
- **A fixed color per metric**, used everywhere (numbers, chart lines, metric bars), so values can be read
  without labels.
- **Subtle backdrop** behind every screen: a soft accent glow from the top-right corner, a faint grid fading out
  toward the middle, a thin barely-visible rising curve near the top, and a very faint blue glow bottom-left.
  It must stay **not conspicuous**: cards are opaque and content is never harder to read.
- Pill-shaped bold uppercase primary buttons, small uppercase grey section headers, rounded cards (radius 14),
  and hairline separators inside grouped lists.
- **Haptics:** a selection tick on taps and steppers, a success pulse when a set is logged or the base weight
  goes up, and a warning pulse when a set is cleared.

#### Design tokens (MUST be defined once in a theme file, never hard-coded in widgets)

| Token | Value | Use |
|---|---|---|
| `background` | `#000000` | Screen background |
| `surface` | `#1C1C1E` | Cards, grouped rows |
| `surfaceHigh` | `#2C2C2E` | Pressed rows, steppers, chips, separators |
| `textPrimary` | `#FFFFFF` | |
| `textSecondary` | `#8E8E93` | Labels, captions |
| `textTertiary` | `#5A5A5F` | Chevrons, empty check circles |
| `accent` | `#11D16C` | Primary actions, active states, success |
| `onAccent` | `#000000` | Text and icons on the accent color |
| `accentSoft` | `#11D16C` at 15% opacity | Badges, timer pill, completed row tint |
| `danger` | `#FF453A` | Destructive actions, missed reps |
| `metricSets` | `#FF453A` | Sets |
| `metricReps` | `#11D16C` | Reps |
| `metricVolume` | `#64D2FF` | Volume |
| `metricWeight` | `#FF9F0A` | Weight |

Spacing scale: 2 / 4 / 8 / 16 / 24 / 32 / 64. Minimum tap target: **48×48 dp** (steppers 56×60).
Numbers use tabular figures.

### 2.3 UX rules (learned from the prototype; MUST follow)
1. **Nothing may shift layout right after a tap.** The rest timer lives in a **fixed footer** next to Finish,
   not above the set list. A timer appearing at the top pushed rows down and caused mis-taps.
2. **One-tap logging:** tapping a set's check box logs it exactly as prescribed. Tapping the row opens a
   **bottom sheet** with big weight and reps steppers, Log/Update, and Clear set.
3. Unlogged rows show the prescribed values **dimmed**. Logged rows are full brightness.
4. A working set that missed its target reps shows the reps in **red** (`8 / 10`).
5. The overload set is visually marked (accent ↑ badge plus an accent outline or label).
6. Destructive actions (remove exercise, delete workout, discard empty workout) always ask for confirmation.
7. Steppers: weight steps by the exercise's increment; reps step by 1; nothing goes below 0.
8. Interactive elements carry semantic labels for screen readers (e.g. *"Set 3, overload: 10 reps at 22.5 kg.
   Opens editor."*). Decorative layers (the backdrop) are excluded from semantics.

---

## 3. Core concepts and glossary

| Term | Meaning |
|---|---|
| **Exercise** | A movement, e.g. *Incline Dumbbell Bench Press*. Either from the built-in library or user-created (custom). |
| **Per hand** | A flag on dumbbell exercises. The weight is per hand, so **volume counts both hands (×2)**. |
| **Plan** | `baseWeight`, `targetReps`, `targetSets` (≥ 2), `increment`, optional rest time. Either the **exercise plan** (per user and exercise, table `exercise_state`) or a **template plan** (per template exercise). |
| **Template plan** | The plan of one exercise inside one template. Seeded from the exercise's own plan when the exercise is added to the template; after that it progresses on its own. |
| **Working sets** | Sets 1 … N−1, prescribed at `baseWeight`. They alone decide progression. |
| **Overload set** | Set N (the last set), prescribed at `baseWeight + increment`, **always**. It is a stretch target only: it never affects the result. |
| **Session** | One exercise inside one finished workout. |
| **Volume** | Σ weight × reps (× 2 if per hand). |
| **Activity** | A logged non-gym sport session: type, date, optional duration and note. Optional distance (whole metres, 1 to 1,000,000) only for running, cycling and snowboarding; live tracked snowboarding days also carry run, lift and rest metrics (section 5.10); no other sport-specific metrics. Counts toward This week, Week streak and the weekly bars; never toward volume, exercise stats or progression. |
| **Activity type** | One entry of the code-level registry (`id`, `label`): `functional`, `cycling`, `snowboarding`, `running`, `pilates`. Running, cycling and snowboarding have `hasDistance` and live GPS tracking. |
| **Est. 1RM** | Epley formula: `w × (1 + reps / 30)`, rounded to 0.1. 1 rep gives `w`, 0 reps gives 0. |

---

## 4. Progression engine (the heart of the app; MUST be pure Dart with 100% test coverage)

### 4.1 Prescription
For a plan `{base, reps, sets=N, inc}` the sets are `1..N`. Sets `1..N−1` use `base`; set `N` uses
`base + inc` and is flagged `isOverload`. All weights are rounded to the nearest **0.25 kg** to avoid
floating-point drift (`roundWeight(kg) = round(kg × 4) / 4`).

Validation: `targetSets ≥ 2`, `targetReps ≥ 1`, `increment > 0`, `baseWeight ≥ 0`. Otherwise throw.

### 4.2 Evaluation when a workout is finished
Given the plan and the logged sets (order-independent, keyed by set number):

| Condition (checked in this order) | Result | `reason` |
|---|---|---|
| Any working set (1..N−1) not logged | base unchanged | `incomplete` |
| Any working set with `reps < targetReps` **or** `weight < baseWeight` | base unchanged | `missed_reps` |
| Otherwise (every working set logged at `weight ≥ baseWeight` and `reps ≥ targetReps`) | **next base = `roundWeight(base + increment)`** | `progressed` |

Notes:
- Only the working sets decide. The overload set is still prescribed at `base + inc` and marked ↑, but skipping
  it, failing it or lifting more on it never changes the result. There is no "jump" to a heavier lifted weight.
- Hitting the reps at a *lighter* weight than base does not count.
- Exercises without a plan are logged but never progressed.

### 4.3 Finishing a workout (MUST be transactional)
For each exercise with a plan and at least one logged set:
1. `plan = snapshot ?? current plan of the session's source` (a resumed workout keeps the plan it was originally done with). The source is the template exercise the workout exercise is linked to (`template_exercise_id`), otherwise the exercise's own plan.
2. `result = evaluate(plan, sets)`.
3. Store a **snapshot** on the workout-exercise row: plan base, reps, sets, increment, and `resultBaseWeight`.
4. If `result.progressed` **and** the current base of that source still equals `plan.baseWeight`, set it to
   `result.nextBaseWeight`. Only that source is written: a template workout never updates the exercise's own plan. Do not overwrite a base weight the user edited by hand in the meantime.
5. Set `endedAt`.

Show a summary: `⬆ Incline DB Press: 20 kg → 22.5 kg` or `• Lat Pulldown: stays at 50 kg`.
If no sets were logged at all, offer to **discard** the workout instead.

### 4.4 Editing history safely (`canRewriteBase`)
A finished workout may be **edited**, **resumed** or **deleted**. The current base weight may be rewritten
**only if both** of these hold:
- this workout is the **latest finished session of the same plan** (ad-hoc sessions of that exercise, or sessions
  of that template exercise), **and**
- the current base equals the `resultBaseWeight` this workout produced (compare after `roundWeight`).

Otherwise history is corrected but the current plan is left alone. If a template exercise was deleted, its
finished sessions are orphans and never change any plan; a live session without a snapshot is unlinked and falls
back to the exercise plan.

| Action | Behavior |
|---|---|
| **Edit** a finished workout (change, add or clear sets; add or remove exercises) | Changes save immediately. After each change, re-evaluate against the **snapshot** plan, update the snapshot's `resultBaseWeight`, and rewrite the current base if `canRewriteBase`. An exercise with no snapshot uses the current plan, and only if it is the latest session. |
| **Resume** ("finished by mistake") | Allowed **only for the most recent finished workout overall**, and only if no other workout is in progress. Undo its progression (restore `plan.baseWeight` if `canRewriteBase`), clear `resultBaseWeight`, set `endedAt = null`. Finishing again re-applies progression. |
| **Delete** | Undo its progression if `canRewriteBase`, then delete the workout and its children (cascade). |
| **Clear set** | Remove the logged set. It returns to "not logged". |

---

## 5. Functional requirements

### 5.1 Exercise library
- **MUST** ship with this seed library (fixed UUIDs so local and cloud rows match later):

| # | Name | Muscle group | Per hand | Default increment (kg) |
|---|---|---|---|---|
| 1 | Barbell Bench Press | Chest | no | 2.5 |
| 2 | Incline Dumbbell Bench Press | Chest | yes | 2.5 |
| 3 | Cable Fly | Chest | no | 2.5 |
| 4 | Barbell Back Squat | Legs | no | 5 |
| 5 | Romanian Deadlift | Legs | no | 5 |
| 6 | Leg Press | Legs | no | 5 |
| 7 | Leg Curl | Legs | no | 2.5 |
| 8 | Deadlift | Back | no | 5 |
| 9 | Lat Pulldown | Back | no | 2.5 |
| 10 | Seated Cable Row | Back | no | 2.5 |
| 11 | Dumbbell Row | Back | yes | 2.5 |
| 12 | Overhead Press | Shoulders | no | 2.5 |
| 13 | Dumbbell Lateral Raise | Shoulders | yes | 1 |
| 14 | Barbell Curl | Arms | no | 2.5 |
| 15 | Dumbbell Hammer Curl | Arms | yes | 2 |
| 16 | Triceps Pushdown | Arms | no | 2.5 |

  UUID scheme: `00000000-0000-4000-8000-` followed by the number as 12-digit zero-padded hex (`…000000000001` to `…000000000010`).
  Library seeding is idempotent and updates names, groups and increments on every app start.
- **MUST** support exercise search, grouping by muscle group, and creating a **custom exercise** by typing a name
  that doesn't exist (name, per-hand flag, increment, category: Chest, Back, Legs, Shoulders, Arms or Custom).
  Names are unique per user, case-insensitive.
- **MUST** provide an **Exercises** library screen (`/exercises`), reachable from the Train header icon and the
  Progress "All exercises" link, to browse, create and edit custom exercises (also via Edit on the exercise
  detail; built-in exercises are not editable).

### 5.2 Plan setup
- The first time an exercise appears in a workout without a plan, show an inline **plan setup** card: base weight
  (stepper, steps by increment), target reps (default 10), sets (default 3, min 2), and increment as segmented
  chips **+1 / +2 / +2.5 / +5** (default: the exercise's default increment). Button: *Start with this plan*.
- Plans are editable from the exercise detail page. Help text: "The weight goes up by the increment when every set before the last hits the target reps."
- Template plans are shown in the template editor (`3 × 10 @ 20 kg · overload +2.5`, or *No plan yet*); tap a row to edit it, saved with the template.

### 5.3 Live workout (Hevy-style)
- **Start workout** from the home tab, or **Continue** if one is in progress. At most one workout is active.
- Header: elapsed **Duration**, live **Volume**, **Sets** done, and a **Finish** button.
- Per exercise, a card with the name, plan summary (`3 × 10 @ 20 kg · overload +2.5 · per hand`, plus `· template plan` when the workout came from a template), and a `⋮`
  menu (Remove exercise, Edit plan). *Edit plan* edits the template plan for template exercises.
- **Set table:** SET (number, or ↑ for overload) · PREVIOUS (same set number from the
  previous session of this exercise, e.g. `20 kg × 10`, or `—`) · KG · REPS · ✓.
  Rows are pre-filled from the prescription; tap ✓ for one-tap logging, or tap the row for the bottom-sheet
  editor. Logging the same set number again **overwrites** it (no duplicates).
- **+ Add Set** adds an extra set row. Extra sets beyond N are logged but don't affect progression, and neither does the overload set itself.
- **Compared to previous** card under each exercise once a set is logged: Sets, Reps, Volume, Top weight, each
  with ▲ / ▼ / – and the % change, colored with the metric colors. Shows "First session" if there is no previous.
- **Rest timer (MUST):** starts on each logged set and **counts down** from the rest target in a fixed footer pill.
  The target is the exercise's own rest time if set, otherwise the **default rest time from Settings (60 s out of
  the box, configurable: section 5.7)**. At 0 it gives a haptic pulse (and a sound if enabled), then keeps showing
  **overtime** counting up (e.g. `+0:12`) in a muted style. Logging the next set restarts it; tapping the pill
  dismisses it. It is computed from a stored start timestamp (not a ticking counter), so it stays correct when the
  app is backgrounded. A system notification when the app is in the background is **SHOULD**.
- **Discard workout** in the live menu deletes the live workout after confirmation (stronger warning when it was
  resumed). A **Date** row (live and finished workouts) moves the session to another day to log past gym
  sessions; time of day and duration are kept.
- **Set milestone reward:** when sets 1 and 2 of an exercise both meet or beat the target reps during a live
  workout, a short (about 3 s) non-blocking burst plays over the card: a neon line-art bodybuilder pumps three times
  and explodes into a firework, with a success haptic. A **Target hit · sets 1–2** pill then sits on the right of the
  Add Set row whenever the condition holds (also in edit mode, without the burst). Reduced motion shows the pill
  only. Feature 008.
- **Add Exercise** opens the exercise picker (modal) and appends the exercise to *this* workout.
- **Exercise notes** (**SHOULD**): free text per exercise in this workout.

### 5.4 History
- Finished workouts and logged activities in one list, newest first, grouped by month. Each row has an icon:
  a dumbbell for gym workouts, the sport's own icon for activities. Workout rows show the date, exercise names,
  total **volume** (metric-volume color), set count and duration; activity rows show the type, date, distance, duration, pace (running) or speed (cycling) when both distance and
  duration are set, and note.
- Tapping a workout row opens it in **edit mode** (same screen as live logging): "changes save automatically",
  and footer buttons **Done**, **Resume** (only if allowed) and **Delete**.
- **Resume** works for any finished workout while none is live, also from the finish summary; a resumed workout
  keeps its earlier duration (device-local live-session record). Finishing rewrites a plan's base only when the
  workout is the newest session for that plan; backdated or older resumed sessions never do.
- A **List / Calendar** switch: Month or Week calendar with prev/next, a month and year picker and Today; each day
  shows the icon of its first session and "+N" for more, and tapping a day lists its entries.
- Tapping an activity row opens the activity sheet to edit it or delete it (delete asks for confirmation).

### 5.5 Home / Train tab
- Date kicker, title, a hero card and stat tiles: *This week*, *Week streak*, *Total workouts*. Below them, the 3
  most recent workouts (gym workouts only). The hero is **Ready to train?** with **Start gym workout** (1 tap);
  **Continue workout** when a gym workout is active; when a GPS session is active it shows "<Sport> in progress", the
  ticking `mm:ss · km` and **Continue <sport>** (no separate tracking banner). Templates keep their **START**.
  The Train header has no icons and there is no *Log activity* button (feature 011, section 5.9).
- The **activity sheet** (opened from the hub's *Log a past session* and *More sports*; titled "Log a past session" for
  new entries, "Edit activity" when editing; no *Start live*): activity type, date (default today, never in the future), optional
  duration in minutes (1 to 1440), for running, cycling and snowboarding an optional **distance** (None/Set, typed in km with
  `.` or `,`, rounded to 10 m, 0.01 to 1000 km; stored as whole metres) and optional note (max 200 chars). Types come from the registry
  (`lib/domain/activity_types.dart`); adding a sport is one registry entry plus one icon.
- *This week* and *Week streak* count gym workouts **and** activities. *Total workouts* counts gym workouts only.
- **Weekly streak:** consecutive ISO weeks (Monday start) with at least 1 workout, ending this week or last week.
  The current week doesn't break the streak while it's in progress. It must work across year boundaries
  (2026 has an ISO week 53).

### 5.6 Progress / analytics
- **Workouts per week** bar chart for the last 8 ISO weeks (current week highlighted in the accent color);
  activities count as well as gym workouts. Volume, exercise stats and progression ignore activities.
- List of trained exercises (most recent first) showing the **current base weight** (metric-weight color).
- **Exercise detail** (tabs *Summary* / *History*):
  - Metric tiles: Current base, Heaviest set, Est. 1RM, Sessions.
  - **Line chart** (smooth curve, glow, gradient fill, highlighted last point), with chips
    **Working weight · Volume · Est. 1RM** (Hevy-style). Working weight = heaviest non-overload set of the
    session. Show the last 20 sessions.
  - **PR badge** when the latest session set a record.
  - Last session vs the one before it ("compared to previous").
  - History: sessions newest first, each with its sets as `reps (green) … weight (orange)` rows. Tap one to open
    that workout.
  - Plan card with **Edit**.
- **Personal records:** heaviest weight, best Est. 1RM, best single-set volume. Detect which PR types a new set
  beats (strictly greater than all history).

### 5.7 Settings and units
- A **Settings** screen, opened from the **You** tab (route `/settings`).
- **Default rest time** (MUST): stepper in 5 s steps, range 10 s to 10 min, default **60 s**, plus preset chips
  30 / 60 / 90 / 120 / 180 s. Stored in the local `settings` table and applied to the next logged set.
- **Per-exercise rest time** (MUST): in plan setup and *Edit plan*, a *Rest time* row with **Default (60 s)** or a
  custom value (same stepper). Stored on the exercise plan; empty means "use the default".
- **Rest-timer alert** (SHOULD): haptic on/off and sound on/off, both default on.
- **Units:** kg only in v1. A kg/lb setting is **LATER**; store kg internally regardless.

### 5.10 Live snowboarding tracking (feature 017)
- **Scope:** Snowboarding joins running and cycling as a live-tracking type (same hub entry, setup, permission, foreground
  service, crash recovery, privacy and one-live-session rules as section 5.8) and, like them, accepts an optional manual
  distance. Out of scope: barometer altitude, lift / piste / resort names, 3D maps and replay, heart rate, friends and
  live location, GPX, miles, offline tiles.
- **Detection:** each accepted fix is classified as run, lift or rest automatically from GPS speed and smoothed GPS altitude
  (no barometer); the user never tags anything. No auto-pause for snowboarding: standing still is rest. Manual **Pause**
  excludes that time from everything. Pure domain code in `lib/domain/tracking/`, replayable from the stored points.
- **Metrics:** ride, lift and rest time, ride distance, vertical drop, run count (a run is a descent between lifts with at
  least 30 m of drop; stopping on the way down is rest, not a new run), current, average and max speed (km/h).
- **Live screen:** speed hero, status chip (Riding / On lift / Resting), tiles for runs, vertical, max speed, avg speed,
  distance and elapsed; lifts are drawn muted on the map. Footer unchanged.
- **Finish sheet and History:** the finish sheet shows the day totals and a ride / lift / rest time bar. The History row shows
  "N runs · X m ↓" with the route thumbnail.
- **Saved result:** one `activities` row (`source = gps`, `distance_meters` = ride distance, `moving_seconds` = ride time) plus
  `vertical_drop_meters`, `run_count`, `max_speed_mps`, `lift_seconds`, `rest_seconds` and `segments` (JSON list of run,
  lift and rest segments; run segments also carry per-route-point speed, seconds and altitude). Raw points are deleted;
  all six columns sync with the activity.
- **Activity detail:** speed heatmap on the route, map style switch (Dark, Winter, Satellite; stored on the device only,
  not synced), totals, time bar, run comparison (five metrics, sortable) with best-run badges (fastest, longest, most
  vertical), a timeline of runs and lifts, and a 2D replay of each run (`/activity/:id/replay/:run`: play / pause,
  scrubber, 1x / 4x / 16x).
- **Known limits:** riding a gondola down counts as a run; a slow uphill walk counts as rest; a very flat conveyor lift may
  count as rest. Thresholds will be tuned after a real day on the mountain.

---

### 5.8 Live GPS tracking (running, cycling and, since feature 017, snowboarding; feature 010)
- **Flow:** **[+]** hub → **Running**, **Cycling** or **Snowboarding** (`/track/new?type=<id>`) → setup screen ("Searching for GPS", Start at accuracy ≤ 20 m or *Start anyway*) → live screen →
  **Finish** (1 s hold) → finish sheet (route map, metrics, **Save** / **Discard** with confirmation) →
  **History** row with a route thumbnail (drawn locally, no tiles) → **Activity detail** (interactive map, start and
  finish markers, km markers, metrics, per-km splits; edit type, date, note only; delete confirmed).
- **Live screen:** running shows elapsed time, distance, current and average pace, last km split; cycling shows
  speed, distance, average speed, elapsed time, climb. Footer: Pause/Resume, Lock, Finish. Auto-pause when still
  (running 10 s, cycling 5 s). Fixes with accuracy > 20 m or impossible speed are ignored. Sessions under 1 min or
  50 m need confirmation to save.
- **Background and recovery:** continues with the screen off (Android foreground service, persistent notification
  with time and distance). Fixes are persisted in batches (about 5 s); after a kill the app reopens the live screen
  with the session intact (at most about 5 s lost). Only one live session (gym workout or tracked activity) at a
  time; starting the other shows a message with a button to open the one in progress.
- **Saved result:** one `activities` row (`source = gps`, distance, duration, moving time, elevation gain,
  simplified route, splits); raw points are deleted. Metrics come from pure domain code replayable from points.
- **Permissions:** location "while in use" only, with a short rationale before the OS prompt; if denied, offer
  settings or the manual form. Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_LOCATION`. Location services off mid-session pauses with a banner.
- **Privacy and map:** location data never leaves the device; only map tile requests go to MapTiler. The key is
  `MAP_TILES_KEY` via `--dart-define-from-file=env/dev.json` (never in the repo). No key or no network: the route is
  drawn on a plain dark background.
- **LATER:** Health Connect/HealthKit import, GPX export, miles, offline tile download. Snowboarding is tracked live since feature 017 (section 5.10).
- The live route thins itself to at most 2,000 points for every tracked type (feature 017).

### 5.9 Start/Log hub and You tab (feature 011)
- **[+] action** in the middle of the bottom bar (accent circle, label "Start or log a session"); opens the hub sheet from any
  tab and is never a selected tab. **You** tab (`/you`) lists **Exercise library** (`/exercises`) and **Settings** (`/settings`).
- **Hub sheet:** *START NOW*: **Continue <session>** (only when a session is in progress), **Gym workout**,
  **Running** / **Cycling** / **Snowboarding** (→ `/track/new?type=<id>`), **More sports** (non-live sports open the past-session form
  prefilled with the sport and today), gym templates. *EARLIER*: **Log a past session**.
- **One start guard** for gym and GPS starts on every entry point (hub, Train hero, template START). A blocked start shows
  "<Workout|Running|Cycling|Snowboarding> in progress. Finish it first." with **Open**. Logging a past session is never blocked.
- Train stats and Recent are unchanged (a later slice reworks them). Details: `specs/011-start-hub/` and `docs/ux/unified-start-proposal.md`.

## 6. Navigation and screens

```
Bottom navigation (5 slots)
├── Train      (home: hero Start/Continue, templates, stats, recent; no header icons)
├── History    (workouts and activities by month → workout editor or activity sheet)
├── [+]        action, not a tab: opens the Start/Log hub sheet from any tab (section 5.9)
├── Progress   (weekly chart, exercises → exercise detail)
└── You        (/you: Exercise library, Settings)

Full-screen routes
├── /track/new?type=       live tracking setup (GPS fix, Start)
├── /track/live            live tracking screen (map, metrics, Pause/Lock/Finish)
├── /activity/:id/replay/:run   2D replay of one snowboarding run
├── /workout               live workout (active)
├── /workout/:id           finished workout in edit mode
├── /activity/:id          activity detail (map, metrics, splits)
├── /exercise/:id          exercise detail (Summary / History)
├── /exercises             exercise library (from You)
├── /add-exercise?workout= exercise picker (modal)
├── /template/new          create a template
├── /template/:id          edit a template
└── /settings              settings (default rest time, section 5.7)
```
The Android back gesture must behave correctly everywhere. Bottom sheets close on back.

---

## 7. Data model (local, source of truth)

All ids are **client-generated UUID v4** (so offline creation and future sync are idempotent). Timestamps are
ISO-8601 UTC. Every syncable table has `updated_at` and `dirty` (1 = changed locally, not yet pushed).

```
exercises          id PK, name, muscle_group?, is_per_hand, default_increment, is_custom, dirty
exercise_state     exercise_id PK → exercises, base_weight, target_reps, target_sets, increment,
                   rest_seconds? (NULL = use the default rest time), updated_at, dirty
templates          id PK, name (unique ignoring case), created_at, last_used_at?, updated_at, dirty
template_exercises id PK, template_id → templates (cascade), exercise_id → exercises, position,
                   base_weight?, target_reps?, target_sets?, increment?, rest_seconds?,   -- template plan
                   updated_at, dirty, UNIQUE(template_id, exercise_id)
workouts           id PK, name?, started_at, ended_at?, notes?, updated_at, dirty
workout_exercises  id PK, workout_id → workouts (cascade), exercise_id → exercises, position,
                   notes?, template_exercise_id? (indexed, no FK; NULL = uses the exercise plan),
                   plan_base_weight?, plan_target_reps?, plan_target_sets?, plan_increment?,   -- snapshot
                   result_base_weight?,                                                       -- snapshot
                   updated_at, dirty
sets               id PK, workout_exercise_id → workout_exercises (cascade), set_no, weight, reps,
                   is_overload, completed_at, updated_at, dirty,
                   UNIQUE(workout_exercise_id, set_no)
activities         id PK, type_id, started_at, duration_minutes?, distance_meters?, notes?,
                   source ('manual'|'gps'), moving_seconds?, elevation_gain_meters?,
                   route? (encoded polyline), splits? (JSON),
                   vertical_drop_meters?, run_count?, max_speed_mps?, lift_seconds?, rest_seconds?,
                   segments? (JSON, snowboarding), updated_at, dirty,
                   index on started_at                              -- non-gym sport activities
tracking_sessions  id PK, type_id, state ('active'|'paused'), started_at, paused_ms, paused_at?,
                   updated_at, dirty                                -- the one live GPS session, local only
track_points       session_id → tracking_sessions (cascade), seq, t, lat, lon, alt?, accuracy, speed?,
                   paused, PK(session_id, seq)                      -- raw fixes, deleted on save or discard
pending_deletes    table_name, row_id, PK(table_name, row_id)      -- delete queue for sync
settings           key PK, value                                   -- local-only in v1, e.g. default_rest_seconds = 60
```
- Schema version is 9 (v2 templates, v3 template plans and `template_exercise_id`, v4 `activities`, v5 `activities.distance_meters`, v6 `tracking_sessions`, `track_points` and the tracked columns on `activities`, v7 `exercises.deleted_at`, v8 `sync_state`, v9 the snowboarding columns on `activities`). Use real schema **migrations** with a version number (drift `stepByStep`). Never drop user data on upgrade.
- Foreign keys **ON**. Writes that touch several rows (finish, resume, recalculate, delete) run in **one
  transaction**.

---

## 8. Backend and sync (built in feature 013, M7)

- **Opt-in.** Nothing leaves the phone until the user signs in with Google (Android) from Settings. Supabase
  (Postgres + Auth + RLS). Without the `SUPABASE_*` / `GOOGLE_WEB_CLIENT_ID` keys the app is fully offline.
  The local database stays the source of truth (schema v8 adds a `sync_state` table with per-table pull cursors).
- **Server schema** mirrors section 7 with `user_id` on every row (default `auth.uid()`), plus `deleted_at` and
  `server_updated_at` (set by trigger). **RLS: owner-only** on every table; no friendship tables.
- **Tombstones, not hard deletes.** A local delete is replayed as `deleted_at`; a trigger tombstones children of a
  tombstoned parent. Pull applies tombstones as local deletes.
- **Pull cursors.** Per table, `server_updated_at > cursor - 2 min` (the overlap covers out-of-order commits),
  ordered, paged by 1000; re-applying rows is idempotent. Pull runs before push.
- **Conflicts.** Last-writer-wins on the client `updated_at` (trigger); a tombstoned row ignores later updates, so
  deletes win regardless of clocks. A pulled row never overwrites a dirty, newer local row.
- **Push** is the `sync_push(payload)` RPC (`SECURITY INVOKER`): deletes first, then upserts in FK order, pages of
  at most 500 rows. Each row is isolated: a bad row is returned in `rejected` and stays dirty, the rest apply.
  `dirty` is cleared only if `updated_at` is unchanged since it was read; failures are silent and retried.
- **No server-side uniqueness** (only PKs and FKs), so one bad row can never block a device. Collisions are
  resolved on pull: same template or custom exercise name renames the local row " (2)"; same
  `(workout_exercise_id, set_no)` keeps the newer set.
- **Exercises.** The built-in library stays in the app. The server holds `custom_exercises` and
  `exercise_overrides` (built-ins the user hid, `archived_at`), not a global library table. `archived_at` is
  separate from the `deleted_at` tombstone.
- **Settings.** `user_settings` syncs a whitelist only: default rest time, rest-alert vibration and sound.
- **What is synced:** workouts (also unfinished), exercises, sets, plans, templates, custom exercises and
  overrides, activities with route, splits and snowboarding segments. Raw GPS points and live sessions never leave the device.
- **Sign-in decision** (the phone remembers which account its data belongs to): no local history and an empty
  cloud binds; no local history and cloud data restores; local history and an empty cloud makes a first backup;
  both have data asks Merge or Cancel; a phone bound to another account asks before replacing its data.
- **Account actions** (Settings): sign out (data stays, backup stops), remove my data from this phone, delete
  account (Edge Function `delete-account`; tables cascade; then keep or remove local data).
- **Triggers:** app start, return to foreground, after finishing a workout, right after sign-in, and a manual
  "Back up now"; one sync at a time, repeats within 5 s are coalesced.
- Migrations live in `supabase/migrations/` and are tested on PGlite (`npm ci && node tool/db_test.mjs`).
  Setup: `docs/sync-setup.md`.

---

## 9. Technical architecture (Flutter)

### 9.1 Stack (verify each package is current, maintained and null-safe on pub.dev before adding it)
| Concern | Choice |
|---|---|
| Language | Dart (latest stable), sound null safety |
| SDK | Flutter **stable** channel, latest version at implementation time |
| State management | `flutter_riverpod` (with code generation optional) |
| Routing | `go_router` |
| Location and map | `geolocator` (GPS), `flutter_map` + `latlong2` (OpenStreetMap tiles via MapTiler) |
| Local DB | `drift` (type-safe SQLite, migrations, in-memory DB for tests) with its Flutter SQLite libs |
| Charts | `fl_chart` (or `CustomPainter` for the glow line and backdrop) |
| IDs | `uuid` |
| Haptics | Flutter's built-in `HapticFeedback` (no package needed) |
| Dates and formatting | `intl` |
| Backend (feature 013) | `supabase_flutter`, `google_sign_in` |
| Lints | `flutter_lints` minimum; prefer `very_good_analysis` (strict) |
| Tests | `flutter_test`, `mocktail` if needed, drift's in-memory database |

Prefer the platform's built-in widgets (Material 3 with a custom dark `ThemeData` and `ThemeExtension` for the
metric colors) over third-party UI kits.

### 9.2 Project structure (feature-first, layered)
```
lib/
  main.dart
  app/                 app widget, router, theme (tokens, ThemeData, ThemeExtension), backdrop painter
  core/                formatting (formatKg), ISO-week utils, haptics wrapper, result types
  domain/              PURE Dart, no Flutter imports:
    progression.dart   prescribe, evaluate, roundWeight, canRewriteBase
    stats.dart         volume, Epley 1RM, PRs, summarizeSession, diffSummary, weekly streak
    activity_types.dart ActivityType registry, activityTypeById, activityLabel, validateActivity
  data/
    db/                drift database, tables, migrations, seed library
    repositories/      WorkoutRepository, ExerciseRepository, TemplateRepository, ActivityRepository (activity_repository.dart) (all business writes, transactions); plan_store.dart (PlanStore: validated plan reads/writes)
    sync/              push/pull, delete queue, account actions (feature 013)
  features/
    train/             home tab
    workout/           live and edit workout screen, set table, set sheet, plan setup, rest timer
    history/            merged workouts and activities list
    activities/         activity sheet, activity_icons.dart (type id to icon)
    progress/          weekly chart, exercise list, exercise detail
    exercises/         picker, custom exercise
    settings/          settings screen (default rest time, alerts)
  widgets/             shared UI kit: Button, Card, Group/Row, SectionHeader, Stepper, Chips, MetricTile,
                       Delta, Stat, LineChart, BarChart
test/                  mirrors lib/ (domain, data, widgets, features)
integration_test/      key end-to-end flows
```
Rules: widgets never touch the DB directly (they go through repositories via providers); the domain layer is
pure and fully unit-tested; no business logic in widgets; no hard-coded colors or sizes outside the theme.

### 9.3 Code quality and safety (MUST)
- `flutter analyze` with zero warnings, `dart format` clean, `flutter test` green. All three run on every
  milestone and in CI.
- **No secrets in the repo, ever.** Config comes from `--dart-define-from-file=env/dev.json`; commit only
  `env/example.json` with empty values. The Supabase anon key is not a secret, but keep it out of git anyway.
- **Android signing:** the release keystore (`*.jks`/`*.keystore`) and `android/key.properties` are **never
  committed**. Document how to create them in the README.
- **`.gitignore`** MUST cover at least: `.dart_tool/`, `build/`, `.flutter-plugins`,
  `.flutter-plugins-dependencies`, `.pub-cache/`, `.pub/`, `*.iml`, `.idea/`, `.vscode/`,
  `android/local.properties`, `android/key.properties`, `android/.gradle/`, `android/app/release/`, `*.jks`,
  `*.keystore`, `*.p8`, `*.p12`, `*.mobileprovision`, `ios/Pods/`, `ios/.symlinks/`,
  `ios/Flutter/Generated.xcconfig`, `ios/Flutter/flutter_export_environment.sh`, `env/*.json` (except
  `env/example.json`), `.env*`, `coverage/`, `*.log`, `.DS_Store`, `supabase/.temp/`.
  Generated code (`*.g.dart`, `*.freezed.dart`): either commit it consistently or generate it in CI; pick one
  and document it.
- **Repo hygiene:** a README (what it is, the progression rule, setup, run, test, build APK, project layout,
  roadmap), `docs/ARCHITECTURE.md` (data flow, progression and edit rules, sync design), `.editorconfig`,
  `analysis_options.yaml`. **No LICENSE file** (private project; the owner decides later). No IDE folders in git.
- **Git:** private GitHub repo under the owner's account; commits use the owner's **GitHub no-reply email**;
  small, focused commits with clear messages; never commit generated build output.
- **CI (SHOULD):** a GitHub Actions workflow on push and PR: `flutter pub get`, `dart format --set-exit-if-changed`,
  `flutter analyze`, `flutter test`, and `flutter build apk --debug`.
- **Accessibility:** `Semantics` labels on all interactive controls, 48 dp minimum targets, sufficient
  contrast on the dark theme, and the backdrop excluded from semantics.
- **Errors:** never crash on bad data. DB errors are caught and logged, and the user sees a short message.
  Sync errors are silent and retried.

### 9.4 Building the APK (no third-party cloud needed)
- Prerequisites on the Mac: Flutter SDK, Android SDK (command-line tools or Android Studio), JDK 17.
  `flutter doctor` must be green for Android.
- Debug APK for personal use: `flutter build apk --debug`, or a release APK signed with the owner's keystore:
  `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`. Install it by copying it to
  the phone and opening it.
- Android application id: `com.fitapp.app` (changeable before any store release). App name: **FitApp**.

---

## 10. Non-functional requirements
| Area | Requirement |
|---|---|
| Offline | 100% of v1 features work with no network. |
| Performance | Logging a set updates the UI in < 100 ms; app cold start < 2 s on a mid-range Android phone. |
| Data safety | No data loss on app kill mid-workout (every set persists immediately). Migrations preserve data. |
| Orientation | Portrait only. |
| Min Android | Flutter's current default minimum SDK. |
| Privacy | No analytics or trackers. Data stays on the device until the user opts into cloud backup by signing in (section 8). |

---

## 11. Acceptance examples (worked scenarios)
Plan: `base 20, reps 10, sets 3, inc 2.5` (Incline Dumbbell Bench Press, per hand).

1. Sets `20×10, 20×10, 22.5×6` → **progressed**, next base **22.5**. Next prescription is `22.5, 22.5, 25`.
2. Next session `22.5×10, 22.5×8, 25×4` → **missed_reps**, base stays **22.5**.
3. Session-1 volume = (20·10 + 20·10 + 22.5·6) × 2 = **1070 kg**. Session-2 volume vs session 1 shows
   ▲/▼ with %.
4. Finish by mistake after session 1, then **Resume** → base back to **20**; change set 2 to 8 reps and finish →
   `missed_reps`, base **20**.
5. Edit the latest finished workout: set 2 → 9 reps → base **20**; back to 10 reps → base **22.5**.
6. Two sessions (20→22.5, then 22.5→25). Edit the *first* one to fail → its stored result becomes 20, but the
   current base stays **25**.
7. User manually sets base to 30 after finishing, then resumes and re-finishes → the result is judged on the
   snapshot plan (progressed to 22.5), but the current base stays **30**.
8. Delete the latest finished workout → its increase is undone. Delete an older one → the current base is unchanged.
9. Overload set skipped or failed: `20×10, 20×10, 25×2`, or `20×10, 20×10` with no set 3 → still **progressed**,
   next base **22.5** (the overload set never decides; scenario 1 is unchanged).
10. Template A and B both contain Cable Fly at 20 kg (each has its own plan). Finishing A's workout with all
    working sets hit → A's plan becomes **22.5**; B's plan and the exercise's own plan stay **20**.

---

## 12. Test plan (MUST pass; port these from the prototype's 55 tests)
**Domain (pure unit tests)**
- `prescribe`: base, base, base+inc; 4-set and +5 variants; invalid plans throw.
- `evaluate`: progressed; exceeding target reps; missed reps on set 2; reps hit at a lighter weight than base;
  overload set missing, failed or heavier than prescribed (never changes the result); working set missing; order-independence.
- `roundWeight`: removes float drift (`0.1 + 0.2 + 22.2 → 22.5`).
- `canRewriteBase(isLatestSessionForPlan, currentBase, resultBaseWeight)`: latest and matching → true; plan edited since, not latest, or never applied → false.
- Stats: per-hand volume; Epley (100×10 → 133.3, ×1 → 100, ×0 → 0); PRs and `newPRTypes`; session summary and
  diff; ISO week keys (9 Nov 2026 → 2026-W46, 1 Jan 2027 → 2026-W53); workouts per week; streak with an
  in-progress current week, with a gap, and across the year boundary.

**Data (drift in-memory)**
- Library seeded with 16 exercises; migration and seeding are idempotent.
- Full flow: plan → session → progression → prescription → missed session → history.
- Re-logging a set overwrites it; exercises without a plan don't progress.
- Snapshot written on finish; resume, edit, delete and manual-edit scenarios from section 11; resume blocked
  while another workout is active or when the workout is not the most recent; recalculation after clearing a set;
  legacy workouts without snapshots.
- Template progression (feature 005): per-template plans seeded on create, edit, save-from-workout and upgrade; finish, edit, resume and delete touch only the linked template plan; two templates with the same exercise progress independently; orphan sessions and unlinked live sessions; v2 to v3 migration.
- Sport activities (feature 006): registry (known ids, `activityLabel` fallback "Activity", `validateActivity`: unknown type, future day, duration outside 1 to 1440, note over 200 chars trimmed); `ActivityRepository` create, update, delete (queues `pending_deletes`), list, watch; merged `historyEntries` newest first; stats where activities count toward This week, Week streak and weekly bars but not Total workouts, volume or progression; v3 to v4 migration keeps existing data; widget tests for the activity sheet, History icons and edit/delete with confirmation.
- `previousSession` lookup; workout list with volume (per-hand ×2) and exercise names.
- (Phase 2) Sync ordering: deletes before upserts; dirty cleared only if unchanged; failure keeps rows dirty;
  library exercises are never pushed; deleting a workout queues one server delete.

**Widgets and integration**
- Set row: dimmed when unlogged, check box logs as prescribed, missed reps shown in red.
- Rest timer appears in the footer without shifting the list.
- Rest timer counts down from the default (60 s out of the box), uses a per-exercise override when set, pulses at 0
  and then shows overtime; it stays correct after the app is backgrounded (computed from a stored start time).
- Changing the default rest time in Settings persists across restarts and applies to the next logged set; the
  per-exercise value `NULL` falls back to the default.
- End-to-end: start workout → add exercise → set up plan → log 3 sets → finish → exercise detail shows the new
  base and a chart point.

---

## 13. Milestones (implement in order; each ends with analyze + test green and a commit)
| # | Milestone | Done when |
|---|---|---|
| **M0** | Project setup: `flutter create --org com.fitapp --project-name fitapp --platforms android,ios`, then set the Android `applicationId` to `com.fitapp.app`; lints, `.gitignore`, `.editorconfig`, README skeleton, env handling, private GitHub repo named `fitapp`, CI workflow | `flutter analyze` clean; CI green; no secrets or IDE files tracked |
| **M1** | Domain layer: progression and stats in pure Dart | All domain tests in section 12 pass |
| **M2** | Data layer: drift schema, migrations, seed library, repositories (finish, resume, recalculate, delete, clear, previous session, history queries) | All data tests pass; scenarios in section 11 verified in tests |
| **M3** | Theme and UI kit (tokens, backdrop, buttons, groups, stepper, chips, metric tiles), bottom navigation, Train tab, live workout screen (Hevy-style header, set table with PREVIOUS column, one-tap logging, bottom-sheet editor, plan setup, countdown rest timer in the footer, Settings screen with the default rest time, compare-to-previous, finish summary, discard empty) | A full workout can be logged on a real phone; widget tests pass |
| **M4** | History tab and edit mode (auto-save, Done, Resume, Delete, clear set, remove exercise, add exercise to a past workout) | Section 11 scenarios 4–8 work in the UI |
| **M5** | Progress tab and exercise detail (weekly bars, exercise list with base weight, metric tiles, glow line chart with chips, PR badge, history, plan edit) | Charts render with 1, 2 and 20+ sessions |
| **M6** | Polish: haptics, accessibility labels, empty states, app icon and splash (black), release APK build documented and verified on the phone | APK installed and used for a real workout |
| **M7** (built, feature 013; manual two-phone check pending) | Phase 2: Supabase auth, push sync, pull/restore, RLS migrations with tests | Sign in on a second phone restores full history |

---

## 14. Roadmap (after v1, not in scope now)
- Sign-in with cloud backup and restore (M7, built in feature 013)
- Template folders and "repeat last workout" (templates themselves exist since feature 003)
- Barometer altitude, lift and piste names, 3D maps and replay, heart rate, Health Connect/HealthKit import, GPX export, miles and offline map tiles (live GPS tracking for running and cycling exists since feature 010, for snowboarding since feature 017)
- Drop and failure set types (warm-up sets are intentionally not planned)
- Rest-timer notifications when the app is in the background, if not done in M3
- kg / lb setting
- Plate calculator
- Deload suggestion after repeated `missed_reps` (e.g. −10% after 3 failed sessions)
- iOS release (Sign in with Apple required if Google sign-in is offered)

## 15. Decisions log (from the prototype phase)
| Decision | Why |
|---|---|
| Offline-first with local SQLite as the source of truth | Gyms often have poor signal |
| Supabase over Firebase for the backend | Relational data and SQL aggregates; RLS; no per-read billing. InstantDB rejected because it is shutting down (services end 31 Aug 2027) |
| Snapshots on each workout exercise | Makes resume, edit and delete of history correct without replaying all sessions |
| Only the latest workout can be resumed | Resuming older ones would scramble progression order; older ones are edited in place |
| Rest timer in the footer | A timer appearing at the top shifted rows and caused mis-taps |
| Friends and social dropped | Owner's decision (Nov 2026) |
| Flutter instead of Expo for v2 | Owner's decision; local APK builds without a third-party cloud (`flutter build apk`) |
| App name **FitApp** | Owner's decision (12 Nov 2026); replaces the working title "Gym Tracker" |
| No warm-up sets, and no set types in v1 | Owner's decision; keeps the set table and progression simple |
| Rest timer default **60 s**, configurable (global default plus per-exercise override) | Owner's decision; stored in Settings and on the exercise plan |
| Progression decided by the working sets only (1..N−1); the overload set never decides and there is no jump to a heavier lifted weight | Owner's decision (13 Nov 2026); simpler and predictable: next base is always base + increment |
| Each template exercise has its own plan; template workouts progress the template plan, never the exercise's own plan | Owner's decision (13 Nov 2026); the same exercise can progress differently in different templates. Ad-hoc workouts keep using the exercise plan |
| Log other sports from the Train tab ("Log activity"; since 2.7 via the [+] hub, "Log a past session") and show them in History | Owner's decision (13 Nov 2026); one place to log, one list to review |
| Activities can be edited and deleted from History | Owner's decision (13 Nov 2026); same expectation as workouts, delete is confirmed |
| Activities count toward This week, Week streak and the weekly bars; Total workouts stays gym only; never volume or progression | Owner's decision (13 Nov 2026); consistency covers all training, "workouts" stays gym |
| Distinct icons per row in History, including a dumbbell for gym workouts | Owner's decision (13 Nov 2026); tell sports and gym apart at a glance |
| Resume any finished workout, discard live workouts, backdate gym sessions | Owner's decision (13 Nov 2026); a backdated or older session never rewrites a plan's base |
| Exercises library with custom categories; History calendar | Owner's decision (13 Nov 2026); browse and edit exercises, review training by day |
| Keep the approved dark green look | Owner's decision; Hevy is the structure model only, not the palette |

## 16. Open items
1. **App icon artwork:** a black background with a green mark. To be designed; a simple placeholder is fine for M6.

There are no other open questions. The earlier ones (app name, warm-up sets, rest-timer default, color palette) were
resolved on 12 Nov 2026; see the decisions log.

## 17. Changelog
- **2.1 (12 Nov 2026):**
  - App named **FitApp**; project, org and Android id renamed (`fitapp`, `com.fitapp`, `com.fitapp.app`).
  - Warm-up sets removed everywhere (no set types in v1; no `set_type` column).
  - Rest timer: counts down from a **60 s default that is configurable** (global default in a new Settings screen,
    plus a per-exercise override stored on the plan). New `settings` table and `/settings` route.
  - Confirmed: keep the dark green look; Hevy is the structure model only.
- **2.0 (11 Nov 2026):** first Flutter PRD, based on the Expo / React Native prototype and the Hevy reference.
- **2.2 (13 Nov 2026):** feature 005, template progression (owner decisions of 13 Nov 2026).
  - Progression rule: only the working sets 1..N−1 decide; progressed means next base = base + increment. The
    overload set is still prescribed and marked but never affects the result. Reasons `no_overload_set` and
    `overload_not_heavier` removed.
  - Per-template plans: `template_exercises` gets `base_weight`, `target_reps`, `target_sets`, `increment`,
    `rest_seconds`; `workout_exercises` gets `template_exercise_id`. Template workouts progress only the template
    plan; ad-hoc workouts keep using `exercise_state`.
  - `canRewriteBase` works per plan; orphaned sessions never change any plan. Schema v3, `stepByStep` migrations.
  - New scenarios 9 and 10 in section 11.
- **2.3 (13 Nov 2026):** feature 006, sport activities (owner decisions of 13 Nov 2026).
  - Lightweight logging of Functional training, Cycling, Snowboarding and Running; no sport-specific metrics.
  - Code-level registry `lib/domain/activity_types.dart`, `ActivityRepository`, new `activities` table (schema v4,
    `from3To4`), merged History list with icons, edit and delete.
  - Activities count toward This week, Week streak and the weekly bars; Total workouts stays gym only.
- **2.4 (13 Nov 2026):** feature 007, workout flow and exercise library (owner decisions of 13 Nov 2026).
  - Resume any finished workout (also from the finish summary), keeping earlier duration; Discard workout; Date row to backdate sessions.
  - Exercises library screen with create/edit custom exercises and a category selector; History List/Calendar switch.
  - Finishing rewrites a plan's base only for the newest session of that plan. No schema change (v4), no new packages.
- **2.5 (14 Nov 2026):** feature 009, Pilates and manual distance (owner request of 14 Nov 2026).
  - New activity type Pilates (`pilates`). Running and cycling get an optional manual distance (`hasDistance`),
    typed in km, stored as whole metres in `activities.distance_meters` (schema v5, `from4To5`).
  - History rows show distance and, when a duration is set too, pace (running) or speed (cycling).
  - Live GPS tracking, routes, maps, sensors and miles stay LATER. Constitution 1.3.0.
- **2.6 (14 Nov 2026):** feature 010, live GPS tracking for running and cycling (owner approval of 14 Nov 2026).
  - Start live from Log activity, setup, live screen, finish sheet, History route thumbnail, Activity detail (section 5.8).
  - Schema v6: `tracking_sessions`, `track_points`, tracked columns on `activities`. New packages `geolocator`, `flutter_map`, `latlong2`; `MAP_TILES_KEY` map key.
  - Snowboarding tracking, Health Connect, GPX export, miles, offline tiles stay LATER. Constitution 1.4.0.
- **2.7 (14 Nov 2026):** feature 011, start/log hub (owner decision of 14 Nov 2026).
  - Bottom bar becomes Train, History, [+], Progress, You; [+] opens the Start/Log hub sheet from any tab; new You tab (`/you`) holds Exercise library and Settings (Train header icons removed).
  - One start guard for gym and GPS starts on every entry point; Train hero shows Start/Continue for gym and GPS (tracking banner removed); *Log activity* button removed.
  - Activity sheet: no *Start live*; new entries titled "Log a past session". No schema change, no new packages.
- **2.8 (14 Nov 2026):** feature 013, cloud backup and sync (M7).
  - Section 8 rewritten to the built design: opt-in Google sign-in, tombstones, pull cursors, LWW with deletes
    winning, `sync_push` RPC, custom exercises and overrides, settings whitelist, sign-in decisions, account actions.
  - Schema v8 (`sync_state`); packages `supabase_flutter`, `google_sign_in`; Edge Function `delete-account`.
- **2.9 (16 Nov 2026):** feature 017, live snowboarding tracking (owner request of 16 Nov 2026).
  - Snowboarding becomes a live-tracking type with an optional manual distance; automatic run / lift / rest detection from GPS speed and altitude; ride / lift / rest time, ride distance, vertical drop, run count, speeds (section 5.10).
  - Finish sheet and History row with day totals; Activity detail with speed heatmap, Dark / Winter / Satellite map styles, run comparison with best-run badges, timeline and 2D run replay.
  - Schema v9 (`from8To9`): six nullable columns on `activities`; server migration `20261116000001_activities_snowboard.sql`; all six sync. No new packages. Constitution 1.8.0.
  - Barometer altitude, lift and piste names, 3D maps and replay, heart rate, GPX, miles, offline tiles stay LATER.
