# Contract: Routes and UI behavior

## Routes (go_router)

| Route | Screen | Notes |
|---|---|---|
| `/train` (tab 1, initial) | Train/home | no header icons (feature 011) |
| `/history` (tab 2) | History by month | row → `/workout/:id` |
| `/progress` (tab 3) | Weekly bars + trained exercises | row → `/exercise/:id` |
| `/you` (tab 4) | You: Exercise library, Settings | rows → `/exercises`, `/settings` |
| `/workout` | Live workout | redirects to `/train` if no active workout |
| `/workout/:id` | Finished workout, edit mode | footer: Done, Resume (if `canResume`), Delete |
| `/exercise/:id` | Exercise detail, tabs Summary / History | |
| `/add-exercise?workout=<id>` | Exercise picker (fullscreen dialog) | returns selected exercise |
| `/activity/:id` | Activity detail | edit type, date, note; delete confirmed |
| `/track/new?type=<id>` | Live tracking setup | from hub Running/Cycling |
| `/track/live` | Live tracking screen | Pause / Lock / Finish |
| `/exercises` | Exercise library | opened from You |
| `/template/new`, `/template/:id` | Create / edit template | |
| `/settings` | Settings | default rest time, alert toggles; opened from You |

Tabs: Train=1, History=2, Progress=3, You=4; the `[+]` slot is an action, not a tab.

Android back: pops bottom sheets first, then routes; on a tab root it exits the app.

## Bottom bar and Start/Log hub (feature 011)

Bottom bar: Train · History · **[+]** · Progress · You. `[+]` (accent circle, label "Start or log a
session") opens the hub sheet from any tab and is never selected. Hub: START NOW (Continue row when a
session is active, Gym workout, Running/Cycling → `/track/new?type=<id>`, More sports → past-session
form prefilled, templates) and EARLIER (Log a past session). One start guard for gym and GPS starts;
blocked → snackbar "<Workout|Running|Cycling> in progress. Finish it first." with Open. Full contract:
[`specs/011-start-hub/contracts/start-hub.md`](../../011-start-hub/contracts/start-hub.md).

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

Date kicker, title (no header icons), hero card, templates with START, tiles This week · Week streak ·
Total workouts, 3 recent workouts (tap → `/workout/:id`). No "Log activity" button.

- Hero idle: "Ready to train?" + **Start gym workout** (1 tap).
- Gym active: "Workout in progress" + **Continue workout** → `/workout`.
- GPS active: "<Sport> in progress", ticking `mm:ss · km`, **Continue <sport>** → `/track/live`
  (no separate tracking banner).
- Template START goes through the start guard (template workout or blocked snackbar).

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
