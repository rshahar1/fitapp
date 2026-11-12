# Contract: Routes and UI behavior

## Routes (go_router)

| Route | Screen | Notes |
|---|---|---|
| `/train` (tab 1, initial) | Train/home | gear icon → `/settings` |
| `/history` (tab 2) | History by month | row → `/workout/:id` |
| `/progress` (tab 3) | Weekly bars + trained exercises | row → `/exercise/:id` |
| `/workout` | Live workout | redirects to `/train` if no active workout |
| `/workout/:id` | Finished workout, edit mode | footer: Done, Resume (if `canResume`), Delete |
| `/exercise/:id` | Exercise detail, tabs Summary / History | |
| `/add-exercise?workout=<id>` | Exercise picker (fullscreen dialog) | returns selected exercise |
| `/settings` | Settings | default rest time, alert toggles |

Android back: pops bottom sheets first, then routes; on a tab root it exits the app.

## Workout screen (live and edit share one widget, `mode: live | edit`)

- **Header** (live): Duration (from `started_at`), Volume, Sets, **Finish** pill. Edit mode shows
  "Changes save automatically".
- **Exercise card**: name (accent), plan summary, `⋮` → Remove exercise (confirm) / Edit plan; notes
  field (SHOULD); plan setup card instead of table when no plan exists.
- **Set table**: columns SET · PREVIOUS · KG · REPS · ✓. Prescribed values dimmed until logged;
  logged row accent-soft tint + checked box; overload row ↑ badge + accent outline; missed working
  reps red `8 / 10`. `+ Add Set` below.
  - Tap ✓ → `logSet` with prescribed values, success haptic, start rest timer.
  - Tap row → bottom sheet: weight stepper (± increment), reps stepper (± 1), min 0, **Log/Update**,
    **Clear set** (warning haptic).
  - Semantics: "Set 3, overload: 10 reps at 22.5 kg. Opens editor." / "Log set 3 as prescribed".
- **Compared to previous** card once ≥ 1 set logged (Sets, Reps, Volume, Top weight; ▲▼– %, metric
  colors) or "First session".
- **Add Exercise** full-width button at the bottom.
- **Fixed footer**: rest pill (left, hidden when no timer, occupying reserved space so nothing
  shifts) + Finish (live) or Done/Resume/Delete (edit).
- **Finish**: 0 sets → confirm discard; else show summary sheet (`⬆ name: 20 kg → 22.5 kg` /
  `• name: stays at 50 kg`), success haptic if any progressed, then go to `/train`.

## Rest pill

- Countdown `m:ss` from target; at 0 → haptic (if enabled) + sound (if enabled) once, then muted
  `+m:ss` overtime. Tap → dismiss. Restored after process death from stored start time.

## Train tab

Date kicker, title, hero card (Start workout / Continue workout), tiles This week · Week streak ·
Total workouts, 3 recent workouts (tap → `/workout/:id`).

## History tab

Month section headers; row: date, exercise names, volume (metricVolume color), sets, duration.
Empty state with a hint to start a workout.

## Progress tab and exercise detail

- Weekly bars (last 8 ISO weeks, current week accent).
- Trained exercises, most recent first, base weight in metricWeight color.
- Detail Summary: tiles (Current base, Heaviest set, Est. 1RM, Sessions); line chart (last 20
  sessions) with chips Working weight · Volume · Est. 1RM; PR badge; compared to previous; plan card
  with Edit (base, reps, sets, increment chips, rest time Default/custom).
- Detail History: sessions newest first, set rows `reps` (metricReps) and `weight` (metricWeight);
  tap → `/workout/:id`.
- Must render with 1, 2 and 20+ sessions.

## Settings

Default rest time stepper (5 s steps, 10 s–10 min) + chips 30/60/90/120/180 s; haptic toggle; sound
toggle. Values persist immediately.

## Global UI rules

Always dark; tokens from PRD §2.2 only; backdrop behind every screen wrapped in `ExcludeSemantics`;
48×48 dp minimum targets (steppers 56×60); tabular figures; portrait only; destructive actions
confirm.
