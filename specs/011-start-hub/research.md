# Research: Start/Log Hub

## R1. Center "+" in a `StatefulShellRoute` bottom bar

- Decision: custom 5-slot bar; slot index ≠ branch index (slots 0,1,3,4 → branches 0..3).
- Rationale: `NavigationBar` treats every destination as selectable and requires a text label;
  a custom row keeps "+" an action that is never selected, gives it its own semantics label and a
  raised accent look.
- Alternatives: `NavigationBar` with index remapping (label/selection semantics wrong for "+");
  `FloatingActionButton` docked in a `BottomAppBar` notch (heavier, Material 2 look).

## R2. Where the start logic lives

- Decision: guard decision in `lib/domain/start_guard.dart` (pure); orchestration in
  `lib/features/start/start_actions.dart` reading repositories at tap time.
- Rationale: one guard for all entry points (FR-007); the stream cache can lag behind the DB, so
  the tap-time check reads repositories directly (as `_startLive` did). Repositories still refuse
  invalid starts in a transaction (defence in depth).
- Alternatives: checking only the stream providers (stale on rapid taps); guard per screen
  (today's inconsistency).

## R3. Acting after the sheet closes

- Decision: hub rows pop with a `HubChoice`; the caller acts with its own context.
- Rationale: `_startLive` had to capture `GoRouter`/`ScaffoldMessenger` before popping; returning
  a value avoids using a disposed sheet context and makes the hub easy to test.

## R4. Repository gap

- Finding: `TemplateRepository.startWorkout` refuses an active workout but not an active tracking
  session; `WorkoutRepository.startWorkout` and `TrackingRepository.start` refuse both.
- Decision: add the tracking check to `TemplateRepository.startWorkout` with a failing test first.
