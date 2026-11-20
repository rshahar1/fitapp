# Feature Specification: Share a Workout as an Image

**Feature Branch**: `027-workout-share`

**Created**: 2026-11-20

**Status**: Implemented

**Input**: Owner request 2026-11-20: "Add a workout sharing feature across all workout types that
generates a shareable image and opens the native share sheet so users can share the image to
WhatsApp or any other app." Layouts are tailored per workout type to what the app already records;
edge cases (no GPS, zero values, long exercise lists) must be handled gracefully.

## Findings before the change

- Session types: gym workouts (exercises, sets, weight, reps) and activities of five types:
  running, cycling (GPS or manual), snowboarding (GPS day or manual), functional training and
  pilates (manual: duration, optional distance for distance types only).
- GPS running/cycling keep a simplified route, distance, duration, moving time, climb and per-km
  splits. GPS snowboarding days also keep ride (moving), lift and rest seconds, max speed, vertical
  drop, run count and per-segment records (speeds per route point, altitudes).
- Nothing can be shared today; the constitution lists sharing as out of scope until the owner
  requests it. This request is that owner request.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Share a run or ride with its route (Priority: P1)

After a tracked run or ride, the user opens the activity, taps **Share**, sees a preview card
with the route drawing and the key stats, and taps **Share image** to pick WhatsApp (or any app).

**Independent Test**: open a GPS run, tap Share, verify the preview and that the system share sheet
opens with one PNG image.

**Acceptance Scenarios**:

1. **Given** a GPS run of 5.2 km in 27 min with a route, **When** Share is tapped, **Then** the
   card shows "Running", the date, a drawing of the route with start and finish dots, distance
   `5.2 km`, average pace `5:12 /km`, duration, and, when recorded, moving time, climb and the
   fastest km split.
2. **Given** a GPS ride, **Then** the card shows average speed in km/h instead of pace.
3. **Given** the preview, **When** Share image is tapped, **Then** the system share sheet opens
   with a single PNG image of the card (and a one-line text caption).

### User Story 2 - Share a gym workout (Priority: P1)

From a finished workout (and right after finishing one), the user shares a card listing the
exercises with their sets, reps and weights plus the session totals.

**Acceptance Scenarios**:

1. **Given** a finished workout with Bench press 3 × 8 at 60 kg and Squat 80 kg × 5, 85 kg × 5,
   85 kg × 4, **Then** the card lists `Bench press — 3 × 8 · 60 kg` and
   `Squat — 3 sets · top 85 kg × 5`, plus duration, sets, reps and volume totals.
2. **Given** a bodyweight exercise (weight 0), **Then** its line shows reps only (e.g. `3 × 12`).
3. **Given** a per-hand exercise, **Then** its weight reads `20 kg each`.
4. **Given** 11 exercises, **Then** the card shows the first 7 and a `+4 more exercises` line; the
   image never overflows or clips text.
5. **Given** the finish summary sheet after finishing, **Then** it offers **Share workout**.

### User Story 3 - Share a snowboarding day (Priority: P1)

**Acceptance Scenarios**:

1. **Given** a tracked snowboarding day, **Then** the card shows the route coloured by speed
   (lifts in grey), a full-day time breakdown bar with ride, lift and rest time (with each
   duration), top speed in km/h, vertical drop, run count, ride distance, total time and, when
   known, the longest run.
2. **Given** a manual snowboarding entry (no route), **Then** the card shows duration and
   distance only, without a route area.

### User Story 4 - Share any other activity (Priority: P2)

**Acceptance Scenarios**:

1. **Given** a functional training or pilates entry of 45 min, **Then** the card shows the type,
   date and `45 min`.
2. **Given** a manual run with distance and duration, **Then** the card shows distance, duration
   and pace, without a route area.
3. **Given** a manual entry with no duration and no distance, **Then** the card still shows the
   type and date with a short "Logged in FitApp" line, never an empty stat grid or zeros.

### Edge Cases

- Missing or unreadable GPS route, or a route with fewer than two points: no route area; the stat
  layout fills the space.
- Zero or missing values (0 m distance, 0 climb, no splits, no moving time) are omitted, never
  shown as `0` or `—`.
- Pace/speed is shown only when both distance and duration are positive.
- Very long exercise names are cut to one line with an ellipsis; long lists are capped with
  `+N more exercises`.
- A workout still in progress cannot be shared (no Share action until finished).
- Unknown activity types (from a newer app version) share as a generic activity card.
- If writing the image or opening the share sheet fails, a short error message is shown; the app
  never crashes.
- Notes are never printed on the image (they may be private).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every finished gym workout and every activity, of every type, MUST offer a Share
  action from its detail screen; the gym finish summary MUST also offer Share workout.
- **FR-002**: Share MUST open a preview showing exactly the image that will be shared, with a
  Share image button.
- **FR-003**: The shared image MUST be a portrait PNG (4:5, 1080 × 1350 px) on the app's dark
  style with the type title, date, the FitApp name and type-specific content.
- **FR-004**: Running/cycling with a route MUST show a route drawing (no map tiles, works offline)
  with start/finish dots; stats per User Story 1.
- **FR-005**: Snowboarding GPS days MUST show the speed-coloured route and a ride/lift/rest time
  breakdown with durations, plus the stats in User Story 3.
- **FR-006**: Gym workouts MUST show totals (duration, sets, reps, volume) and one compressed line
  per exercise, at most 7 lines plus `+N more exercises`.
- **FR-007**: Other activity types MUST show duration, distance and derived pace/speed when
  recorded.
- **FR-008**: Zero or missing values MUST be omitted; the layout MUST adapt to 0–8 stats.
- **FR-009**: The image MUST be handed to the operating system share sheet; the app itself sends
  nothing over the network and stores nothing beyond a temporary file.
- **FR-010**: Notes MUST NOT appear on the image.
- **FR-011**: Share controls MUST have accessibility labels and 48 dp tap targets.

### Key Entities

- **Share card**: the type-specific content of one image: title, date line, headline stats
  (label, value, unit), optional route (with optional per-stretch colours), optional time
  breakdown (ride/lift/rest), optional exercise lines with a hidden count. Derived on the fly,
  never stored.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From any finished session, the share sheet opens in at most 2 taps (Share → Share
  image).
- **SC-002**: 100% of session types (gym + all 5 activity types, GPS and manual) produce a card
  without empty sections or zero values.
- **SC-003**: The image is ready (share sheet shown) within 2 seconds on a mid-range phone.
- **SC-004**: All text on the image is readable when viewed full-screen in a chat app (minimum
  ~30 px text at 1080 px width).

## Assumptions

- Android first; the share sheet is the platform's standard one (iOS works the same way later).
- The route is drawn without map tiles so the image works offline and leaks no tile keys; a map
  background is a possible later enhancement.
- Units stay metric (kg, km) as everywhere in the app.
- Pace/speed use the same formulas as the activity detail screen (distance over duration), so the
  image matches what the app shows.
- Sharing is a user-initiated export through the OS; it is not a social feature (no accounts,
  feeds or friends) and does not change the sync or privacy model.
