# Data Model: Rest-End Alerts (002)

No schema migration: everything lives in the existing local `settings` key/value table.

| Key | Value | Notes |
|---|---|---|
| `active_rest_started_at` | ISO UTC | existing |
| `active_rest_target_seconds` | int | existing |
| `active_rest_exercise` | text | **new**: exercise name shown in the notification; removed with the timer |
| `notif_permission_asked` | `true` | **new**: set once the automatic permission prompt was shown |
| `rest_alert_haptic`, `rest_alert_sound` | bool | existing toggles, now also select the notification channel |

`ActiveRest` gains an optional `exerciseName` field (null for timers restored from 001 data).

## Notification channels (Android, created at init)

| Channel id | Sound | Vibration |
|---|---|---|
| `rest_sound_vibrate` | rest_chime | yes |
| `rest_sound` | rest_chime | no |
| `rest_vibrate` | none | yes |
| `rest_silent` | none | no |

Notification id: constant `4201` (single rest alert).

## Rest alert state transitions

```
idle ──start──▶ running(foreground) ──hide──▶ running(background, alert scheduled)
  ▲                 │   ▲                         │            │
  │            alarm│   └──────────resume (cancel)┘            │ OS fires at end
  │                 ▼                                          ▼
  └──dismiss/finish── alerted (overtime shown) ◀──resume── notified
```
