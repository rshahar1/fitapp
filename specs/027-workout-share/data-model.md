# Data Model: Share a Workout as an Image

No persisted data. All types are immutable, derived on the fly in `lib/domain/share/`.

## ShareStat
| Field | Type | Notes |
|---|---|---|
| label | String | e.g. `Distance`, `Avg pace` |
| value | String | e.g. `5.2`, `5:12` |
| unit | String? | e.g. `km`, `/km` |

## ShareTimeBreakdown (snowboarding)
`rideSeconds`, `liftSeconds`, `restSeconds` (each ≥ 0); `totalSeconds`; shown only when total > 0.

## ShareExerciseLine
`name` (String), `detail` (String, e.g. `3 × 8 · 60 kg`).

## ShareCardData
| Field | Type | Notes |
|---|---|---|
| layout | ShareLayout | route · snow · strength · basic |
| typeId | String | `gym` or an activity type id (icon lookup) |
| title | String | activity label or workout name / `Workout` |
| startedAt | DateTime | date line formatted by the view |
| stats | List<ShareStat> | 0..6, omitted values never present |
| route | List<GeoPoint>? | ≥ 2 points or null |
| segments | String? | snow records JSON passed through for heat spans (snow only) |
| breakdown | ShareTimeBreakdown? | snow only |
| exercises | List<ShareExerciseLine> | strength only, ≤ 7 |
| hiddenExercises | int | count behind `+N more exercises` |

Layout selection: gym → strength; snowboarding with readable segments and route → snow;
running/cycling (or any type) with a drawable route → route; otherwise basic.
