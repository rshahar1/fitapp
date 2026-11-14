# Unified workout start — UX audit and proposal

Status: proposal (not specified or implemented yet). Date: 2026-11-14.
Grounded in: `lib/features/train/train_screen.dart`, `lib/features/activities/activity_sheet.dart`,
`lib/domain/activity_types.dart`, `lib/features/shell/shell_scaffold.dart`.

## 1. Current flow (as built)

Train tab, top to bottom:

1. Hero card "Ready to train?" → **Start workout** (primary, accent). 1 tap → empty gym workout.
2. Optional "Running in progress" banner (only while GPS tracking).
3. **Log activity** (secondary, full width) → bottom sheet: type grid (Functional, Cycling,
   Snowboarding, Running, Pilates) → for Running/Cycling a **Start live** button, "or log it
   manually below" → date, duration, distance, note, Save.
4. Templates (gym only), each with a START pill. 1 tap → templated gym workout.
5. Stats: "This week", "Week streak", "Total workouts". Recent: date + exercise names + volume.

Tap counts to begin:

| Intent | Taps today | Path |
|---|---|---|
| Empty gym workout | 1 | Start workout |
| Gym from template | 1 | START on template card |
| Live run / ride | 3 + setup | Log activity → Running → Start live → (setup screen) Start |
| Log a past run | 4+ | Log activity → Running → Distance "Set" → type km → Save |
| Log Pilates / snowboarding | 2–3 | Log activity → type → Save |

## 2. UX audit — why the split feels unnatural

1. **The split is on the wrong axis.** The UI divides by *sport* (gym = "Start", everything else =
   "Log"). The user's real intent is divided by *time*: "I'm starting now" vs. "I did this
   earlier". A runner heading out the door has the same intent as a lifter walking into the gym,
   yet one gets the hero button and the other gets a form.
2. **"Log" is the wrong verb for live tracking.** "Start live" — the one action most like "Start
   workout" — sits *inside* a sheet titled "Log activity", below a type picker, and is followed by
   "or log it manually below". Live tracking is discoverable only if you already know it's there.
3. **Hierarchy signals second-class status.** Gym owns the accent primary button, the hero card copy
   ("Ready to train?"), templates and every stat. Other sports get one grey secondary button. Users
   read visual weight as "what this app is for".
4. **Mixed mental models in one sheet.** The sheet is simultaneously a launcher (Start live), a
   retroactive form (date, duration, distance) and an editor (Edit/Delete). Fields like
   "Duration: None / Set" make sense for a past entry and are noise for a live start.
5. **The taxonomy leaks.** "Functional training" and "Pilates" are indoor sessions closer to gym
   training than to running, yet they live under "activity". Snowboarding has no live mode, so the
   same grid behaves differently per tile (Start live appears and disappears).
6. **The dashboard doesn't reflect non-gym work.** Recent rows show exercise names and volume;
   the empty state says "No workouts yet — start your first workout". A user who only runs sees
   an app that looks empty and unused, which undermines habit loops (streaks, "this week").
7. **Inconsistent concurrency handling.** The activity sheet blocks "Start live" if a gym workout or
   tracking session is active; the gym buttons only check for an active gym workout (worth
   verifying whether starting a gym workout during a live run is guarded in the repository).
8. **No equivalent of templates for cardio.** Gym users get one-tap routines; runners can't save
   "Easy 5k" or "Commute ride", so every run costs the same multi-step path.

## 3. Design options

### Option A — Unified Start sheet ("What are you training?")

Replace both buttons with a single primary **Start** (hero card + optionally a FAB). Tapping opens a
sheet: row 1 = big tiles *Gym · Run · Ride · More*; row 2 = your templates (gym and cardio);
footer link "Log a past session".

- **Friction:** +1 tap for gym (Start → Gym). Run drops from 3 to 2 taps.
- **Pros:** one mental model, one entry point, symmetric for all sports; trivially scales (new
  sport = new tile); clean place for "log past".
- **Cons:** taxes the core gym user on every session — directly violates "keep the instant gym
  launch". Mitigation (remember last choice / long-press) adds hidden behaviour.
- **Scalability:** excellent.

### Option B — Modality-aware hero card with quick-start chips (split launcher)

Keep the hero card, but make it a launcher for *any* modality:

```
┌─────────────────────────────────────────┐
│ Ready to train?                          │
│ [ ▶ Start gym workout            ]       │  ← primary, label follows last/pinned sport
│ ( 🏃 Run ) ( 🚴 Ride ) ( 🧘 Pilates ) ( ⋯ ) │  ← quick-start chips, 1 tap each
└─────────────────────────────────────────┘
  Log a past session  ›                      ← text link, retroactive form only
  Templates  [Push day ▶] [Easy 5k ▶] ...    ← mixed gym + cardio templates
```

- Primary button = the user's *primary sport* (default Gym; adapts to last used or a pinned
  setting). Chips start the other modalities directly: GPS sports go straight to the track setup
  screen; non-GPS sports (Pilates, Snowboarding, Functional) start a simple timer session or open a
  short "start now" form.
- "Log activity" becomes **"Log a past session"**, a quiet link (also reachable from History),
  holding only the retroactive form.
- **Friction:** gym unchanged at 1 tap; live run 1 tap (+ setup); past entry unchanged.
- **Pros:** preserves the gym flow exactly; makes every sport a peer; separates "now" from
  "earlier"; reuses the existing type registry (`activityTypes` drives the chips).
- **Cons:** chip row fills up as sports grow (cap at 3–4 + "More", ordered by usage); an adaptive
  primary label can surprise users if it changes silently (prefer explicit "primary sport" or
  last-used with a stable default).
- **Scalability:** good — "More" sheet absorbs the long tail.

### Option C — Center "+" action in bottom navigation (global hub)

Add a central **+** to the nav bar (Train · History · **+** · Progress · …) that opens a
start/log hub from any tab; Train becomes a dashboard.

- **Friction:** gym becomes 2 taps unless Train keeps its hero button (then two competing
  entries). Reachable from History/Progress, which is nice for "log past".
- **Pros:** globally available; familiar pattern (Strava/Instagram style); strong home for
  future modalities and quick-logging.
- **Cons:** biggest structural change (router, shell, PRD §6 three-tab nav); duplicates the hero
  CTA; central "+" usually reads as "create content", fuzzy for "start a live session".
- **Scalability:** excellent, but over-engineered for 5 sports.

### Comparison

| | Gym taps | Live run taps | Past log | Scales to N sports | Build cost |
|---|---|---|---|---|---|
| Today | 1 | 3 + setup | 4+ | Poor (hidden in sheet) | — |
| A. Unified sheet | 2 | 2 + setup | 2+ | Excellent | Low–medium |
| **B. Hero + chips** | **1** | **1 + setup** | 2+ | Good ("More") | Medium |
| C. Nav "+" hub | 1–2 | 2 + setup | 2+ | Excellent | High |

## 4. Recommendation — Option B, in three slices

Split by **intent (now vs. earlier)**, not by sport, and keep the gym button exactly where muscle
memory expects it.

1. **Slice 1 — Start any sport from the hero (highest value, low risk).**
   - Hero card gets a quick-start chip row driven by `activityTypes` (live-tracking types first,
     ordered by recent usage, max 3 + "More").
   - GPS chips route straight to `Routes.newTrack(typeId)` — reuse the existing concurrency guard
     from `_startLive`, and apply the same guard to the gym buttons.
   - The tracking banner merges into the hero ("Run in progress · 23:41 · 4.2 km · Continue"), so
     there is one "in progress" surface for every modality.
   - Rename "Log activity" → "Log a past session" (secondary link); strip "Start live" out of the
     sheet so the sheet is purely retroactive/edit.
2. **Slice 2 — One activity feed.** "Recent", "This week", streaks and totals count every session
   type; rows show sport icon + the sport's headline metric (volume for gym, distance/pace for
   runs, duration otherwise). Empty-state copy becomes sport-neutral.
3. **Slice 3 — Cardio templates and primary sport.** Allow templates for GPS sports (name, type,
   optional target distance) shown alongside gym templates; add a "Primary sport" setting that
   controls the hero button label (default Gym → no change for existing users).

Non-GPS sports (Pilates, Functional, Snowboarding) in slice 1: start a lightweight timed session
(start → finish → duration auto-filled) rather than the past-entry form, so "start now" means the
same thing for every chip. If that's too much for slice 1, those chips can open the past-session
form prefilled with today + type as an interim.

### Success measures
- Taps to start a live run: 3 → 1 (excluding GPS setup).
- Share of runs/rides recorded live vs. logged manually (should rise).
- Gym start taps unchanged (regression guard: widget test asserting Start workout is one tap).

### Next step (spec-kit)
Run `/speckit-specify` for a new feature `011-unified-start` (slice 1), then `/speckit-plan` →
`/speckit-tasks` → `/speckit-implement`; slices 2–3 as follow-up features. PRD §6 (Train tab)
needs a matching update.

---

## 5. Decision (2026-11-14): Option C — center "+" start/log hub

The product owner chose **Option C** over the recommended B. This section is the implementation
plan; it supersedes §4 where they conflict.

### Target design

**Bottom bar (5 slots):** `Train · History · [+] · Progress · You`
- `[+]` is an *action*, not a tab: a raised accent circle in the middle slot that opens the
  Start/Log hub sheet from any tab. It never becomes the selected destination.
- `You` is a new tab holding what today lives in the Train header icons: Settings and the
  Exercise library (`Routes.settings`, `Routes.exercises` stay valid routes). This keeps the "+"
  centred with four real destinations. (Open question for `/speckit-clarify`: name "You" vs.
  "Profile" vs. "More".)

**Start/Log hub sheet** (`[+]`), two sections split by intent:
- *Start now*: `Gym workout` (empty), one row per live-trackable sport (`activityTypes` with
  `hasLiveTracking` → `Routes.newTrack(id)`), other sports under `More sports`. Below: templates
  (gym today; cardio templates are a later slice), each one tap to start.
- *Earlier*: `Log a past session` → the existing retroactive activity form (gym past-session
  logging is out of scope).
- When a session is in progress (gym or GPS), the hub's top row is `Continue <session>` and new
  starts are blocked with the same message/snackbar behaviour as `_startLive` today.

**Train tab becomes the dashboard**, but keeps a one-tap quick start so gym stays at 1 tap:
- Hero card: `Ready to train?` + primary button `Start gym workout` (or `Continue …` when a gym
  or GPS session is active — the GPS tracking banner merges into this card).
- Templates list with START pills stays.
- Stats and Recent count **all** session types (gym + activities), sport icon + headline metric
  per row (volume / distance + pace / duration); sport-neutral empty-state copy.
- The secondary `Log activity` button and header icons are removed.

**Activity sheet** (`activity_sheet.dart`) loses `Start live` and the "or log it manually below"
line — it becomes purely the past-session / edit form.

### Tap budget (acceptance)
| Intent | Target |
|---|---|
| Gym empty workout | 1 (Train hero) or 2 (+ → Gym) |
| Gym from template | 1 (Train) or 2 (+ → template) |
| Live run / ride | 2 (+ → Run) then GPS setup |
| Log a past run | + → Log a past session → form |
| Continue anything in progress | 1 from Train or + |

### Slices (one spec-kit feature each)
1. **011-start-hub** — 5-slot nav with `[+]` action and `You` tab; hub sheet (Start now / Earlier,
   continue-in-progress, unified concurrency guard for gym + GPS starts, also applied to Train's
   gym buttons); strip `Start live` from the activity sheet; Train header icons move to `You`;
   GPS banner merges into hero card. Update PRD §6 and `contracts/ui-routes.md`.
2. **012-unified-feed** — Train stats + Recent across all session types.
3. **013-cardio-templates** — templates for GPS sports shown in hub and Train.

### Engineering notes
- Shell: `ShellScaffold` uses `NavigationBar` with `StatefulNavigationShell`; the `[+]` slot must
  not map to a branch index (custom bottom bar or index remapping); add a `You` branch in
  `buildRouter()`.
- Reuse `TrainScreen.start/startTemplate` and `_ActivitySheetState._startLive` logic by moving it
  into a shared start controller/service (e.g. `lib/features/start/`), with domain-level guard
  logic unit-tested first (constitution: `lib/domain/` pure Dart, tests first).
- Widget tests: hub opens from every tab; gym 1-tap from Train; run start routes to
  `/track/new?type=running`; blocked start when a session is active; activity sheet has no
  `Start live`.
- Accessibility: `[+]` gets a semantic label ("Start or log a session"), 48dp target.
