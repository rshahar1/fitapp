# Feature Specification: Set Milestone Reward Animation

**Feature Branch**: `008-set-milestone-reward`

**Created**: 2026-11-14

**Status**: Implemented

**Input**: User description: "A clean, minimal reward animation when Set 1 and Set 2 both hit or
exceed their target reps; preview the design first." The design was previewed as an interactive
HTML mock-up and approved by the user before specification.

## Clarifications

### Session 2026-11-14 (decided with the user via the approved preview)

- Q: What triggers the reward? → A: **Set 1 and Set 2 of an exercise are both logged with reps at
  or above the plan's target reps.** No plan, or a missing set, means no reward.
- Q: When does the burst play? → A: Only in a **live** workout and only on a **false → true
  transition caused by logging**. Not when opening a workout where the rule already holds, and
  not in edit mode of a finished workout.
- Q: What if the user then clears or lowers a set? → A: The pill disappears; reaching the target
  again replays the burst.
- Q: What does the animation look like? → A: A neon line-art upper-body bodybuilder in a
  double-biceps pose (accent green strokes with glow, surface-colored fills), about 150×128 dp,
  centered over the exercise card's set table on a 65% black scrim. Timeline about 3 s: pop-in
  (380 ms); three muscle "pumps" (biceps, delts, pecs grow) over 1.3 s with growing glow, shake
  and strain lines; at 1.4 s the figure flashes and collapses; a firework burst (60 sparks,
  crackling sub-sparks, shockwave ring) plus two smaller side bursts; the scrim fades and the pill
  appears. A success haptic plays at the explosion.
- Q: What remains afterwards? → A: A **pill** "Target hit · sets 1–2" with a small figure icon on
  the right side of the "Add Set" row (no layout shift). It is shown whenever the rule holds,
  live and edit mode.
- Q: Reduced motion? → A: With system animations disabled there is **no burst, pill only**.
- Q: Sound, other sets, history, settings? → A: Out of scope.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Celebrate hitting the target on the first two sets (Priority: P1)

The lifter logs set 1 and set 2 of an exercise at or above the target reps. The moment the second
one is logged, a short neon bodybuilder animation flexes over the set table and bursts into
fireworks, then a "Target hit · sets 1–2" pill stays on the exercise card.

**Why this priority**: It is the whole feature: a small, motivating reward for a strong start.

**Independent Test**: In a live workout with a plan targeting 8 reps, log set 1 with 8 and set 2
with 9 → the burst plays once and the pill appears; the Add Set button remains tappable throughout.

**Acceptance Scenarios**:

1. **Given** a live workout and set 1 already at target, **When** set 2 is logged at or above
   target, **Then** the burst plays once, then the pill shows.
2. **Given** an exercise where the rule already holds, **When** the workout screen is opened,
   **Then** the pill shows and no burst plays.
3. **Given** a finished workout in edit mode where the rule holds, **Then** the pill shows and no
   burst plays, also after editing a set that keeps the rule true.
4. **Given** the pill is shown, **When** set 1 or 2 is cleared or edited below target, **Then**
   the pill disappears; **When** it is raised to target again in a live workout, **Then** the
   burst replays.
5. **Given** a set below target, or a missing set 1 or 2, or an exercise without a plan,
   **Then** there is no burst and no pill.
6. **Given** the burst is playing, **When** the user taps anywhere (including Add Set or a set
   row), **Then** the tap works normally and is not blocked.
7. **Given** system animations are disabled, **When** the rule becomes true, **Then** only the
   pill appears.
8. **Given** the pill, **Then** a screen reader announces "Target hit for sets 1 and 2" as a live
   region.

### Edge Cases

- Two exercises reach the rule at nearly the same time: only one burst plays at a time; the later
  one is skipped (its pill still shows).
- Leaving the screen or disposing the card during the burst removes the overlay without errors.
- Logging a third or later set never triggers a burst; only sets 1 and 2 count.
- Reps above target count as hitting it.
- Small screens: the figure stays about 150×128 dp and centered; nothing overflows.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The rule "first two sets hit target" MUST be a pure function of the plan's target
  reps and the reps of sets 1 and 2; it is false when any input is missing.
- **FR-002**: The burst MUST play only in a live workout, only when the rule changes from false to
  true because a set was logged or edited, at most one at a time.
- **FR-003**: The burst MUST be about 3 s: figure pop-in, three growing pumps, flash and collapse,
  firework with two smaller side bursts, scrim fade, with a success haptic at the explosion.
- **FR-004**: The overlay MUST NOT block taps and MUST be removed when the card is disposed.
- **FR-005**: A "Target hit · sets 1–2" pill MUST show on the right of the Add Set row whenever
  the rule holds (live and edit mode), without shifting the layout, with a live-region semantics
  label "Target hit for sets 1 and 2".
- **FR-006**: With reduced motion (animations disabled) no burst MUST play; the pill still shows.
- **FR-007**: Colors MUST come from theme tokens, including the new accentBright, mint, gold and
  rewardIconFill tokens; no hard-coded colors in widgets.

### Key Entities

No new stored data. The reward is derived from existing set and plan values; nothing is persisted.

## Success Criteria *(mandatory)*

- **SC-001**: The burst plays exactly once per false → true transition in a live workout and never
  on open or in edit mode.
- **SC-002**: Logging remains one-tap and 100% of taps during the burst reach their targets.
- **SC-003**: The pill appears and disappears in step with the rule in 100% of tested cases.
- **SC-004**: All quality gates (format, analyze, tests) stay green.

## Assumptions

- Target reps come from the exercise's current plan (existing prescription), the same value
  already shown in the set table.
- Out of scope: sound, rewards for other sets, persisting reward history, a settings toggle.
- No data-model or schema change.
