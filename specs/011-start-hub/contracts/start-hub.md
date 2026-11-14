# Contract: Bottom bar, Start/Log hub and You tab

## Bottom bar

| Slot | Widget | Target | Semantics |
|---|---|---|---|
| 0 | Train tab | branch 0 `/train` | "Train", selected state |
| 1 | History tab | branch 1 `/history` | "History" |
| 2 | `[+]` action (accent circle, 56 dp) | opens hub sheet, never selected | "Start or log a session" |
| 3 | Progress tab | branch 2 `/progress` | "Progress" |
| 4 | You tab | branch 3 `/you` | "You" |

Tapping the selected tab again returns that branch to its root.

## Hub sheet

```
START NOW
  [Continue workout | Continue running]   only when a session is in progress
  Gym workout                             → start empty gym workout → /workout
  Cycling, Running (hasLiveTracking)      → /track/new?type=<id>
  More sports  ▾                          → expands: Functional training, Snowboarding, Pilates
                                            → past-session form, type preselected, date Today
  <template name> (one per template)      → start template workout → /workout
EARLIER
  Log a past session                      → past-session form, no type preselected
```

Starts (Gym, sports, templates) go through the start guard. Blocked → sheet closes, snackbar
`"<Workout|Running|Cycling> in progress. Finish it first."`, action `Open` → `/workout` or
`/track/live`. "Log a past session" and "More sports" entries are never blocked.

## Train hero

| State | Title | Line | Button |
|---|---|---|---|
| idle | Ready to train? | — | Start gym workout → start gym |
| gym active | Workout in progress | Started … ago / … trained so far | Continue workout → /workout |
| tracking | Running in progress | `mm:ss · x.x km` (ticking) | Continue running → /track/live |

Template START → start guard → template workout or blocked snackbar.

## You tab (`/you`)

Title "You"; rows Exercise library → `/exercises`, Settings → `/settings`.

## Activity form

Title "Log a past session" (new) / "Edit activity" (edit). No "Start live", no "or log it manually
below".
