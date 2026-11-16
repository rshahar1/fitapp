# Implementation Plan: Step totals in History, steps card below Templates

**Branch**: `015-step-history` | **Spec**: [spec.md](spec.md)

## Technical Context

Builds on feature 014 (`StepSource`, `stepsEnabledProvider`, `stepAccessProvider`,
`todayStepsProvider`, `todayStart`). No schema change, no new package, no Android change.

## Constitution Check (1.7.0)

- VI: read-only, nothing stored or synced. ✅ VII: selected-day total, 30 days, no charts. ✅
- III: provider and widget tests first. ✅ IV: widgets use providers only. ✅

## Design

### Core / data

- Pure helper in `lib/core/step_source.dart`: `({DateTime start, DateTime end})? stepWindow(DateTime
  day, DateTime now)` → null when `day` is after today or before `todayStart(now) - 30 days`;
  otherwise start = local midnight of `day`, end = min(next local midnight, now). Build next
  midnight with `DateTime(y, m, d + 1)` (DST-safe).
- `daySteps = FutureProvider.autoDispose.family<int?, DateTime>` in `lib/data/providers.dart`
  (key: date-only local DateTime): enabled + granted (via `stepAccessProvider`) + window non-null
  → `stepsBetween(start, end)`; otherwise null. Uses `clockProvider`.
- `formatSteps(int n)` in `lib/core/format.dart`: `NumberFormat.decimalPattern()` + " steps" /
  " step" for 1.

### UI

- `train_screen.dart`: move `const StepsCard()` from after `_HeroCard` to after the Templates
  section (after the template list / empty text, before the `SizedBox` + metrics `Row`). Adjust
  `StepsCard` padding so spacing matches neighbours.
- `history_calendar.dart`: the selected-day `SectionHeader(DateFormat('EEEE d MMMM')...)` gets
  `trailing:` a small `_DaySteps(day: selected)` ConsumerWidget that watches
  `daySteps(selected)` and renders `Text(formatSteps(n))` (bodyMedium, textSecondary, tabular) or
  `SizedBox.shrink()` when null/loading. No icon. Semantics label "Steps on <date>: n".
  Check `SectionHeader`'s `trailing` support (used on Train for "New").
- Resume refresh: History calendar invalidates `stepAccessProvider` and `daySteps` on
  `AppLifecycleListener.onResume` (ConsumerStatefulWidget already).
