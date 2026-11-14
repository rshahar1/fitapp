# Implementation Plan: Cloud Backup and Sync

**Branch**: `013-cloud-sync` | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/013-cloud-sync/spec.md`; background analysis in
`docs/proposals/cloud-sync-supabase.md`.

## Summary

Back up and sync every user's history to their own Supabase account, opted into by native Google sign-in, while the
on-device Drift database stays the source of truth. A background `SyncService` pulls server changes since per-table
cursors and pushes dirty rows and queued deletes through one `sync_push` Postgres function. The server enforces
owner-only RLS, last-writer-wins, delete-wins tombstones and tombstone cascades. Signing in decides between first
backup, restore, merge and account switch. Design: [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/).

## Technical Context

**Language/Version**: Dart 3.14 / Flutter stable (app); SQL + PL/pgSQL (Postgres 15+, Supabase); TypeScript/Deno for
one Edge Function

**Primary Dependencies**: existing `drift`, `flutter_riverpod`, `go_router`; new `supabase_flutter`,
`google_sign_in` (7.x); Supabase CLI (dev tool)

**Storage**: Drift/SQLite on device (schema v7 → v8, adds `sync_state`); Supabase Postgres (10 synced tables)

**Testing**: `flutter_test` + in-memory Drift + `FakeSyncRemote`; widget tests; pgTAP via `supabase test db`;
opt-in `integration_test/sync_test.dart` against the local Supabase stack

**Target Platform**: Android (debug + release signing for Google sign-in); iOS out of scope

**Project Type**: mobile app + managed backend (migrations, one Edge Function)

**Performance Goals**: restore of ~300 workouts / 15k sets / 100 tracked activities in < 60 s (SC-002); backup of a
finished workout < 30 s (SC-003); set logging stays < 100 ms (constitution V, SC-005)

**Constraints**: offline-first, no UI waits on network (FR-001); silent retry (FR-002); no data leaves before sign-in
(FR-003); no secrets in repo (FR-027); sync and restore work in pages, never blocking the UI isolate on large writes

**Scale/Scope**: single user per account, 1–3 devices, histories up to tens of thousands of rows

## Constitution Check

*Constitution v1.5.0 (amended for this feature).*

| Principle | How this plan complies | Pre | Post |
|---|---|---|---|
| I. Offline-first, local source of truth | Drift stays authoritative; screens never read the backend; v8 migration only adds `sync_state`; multi-row apply/push bookkeeping in one transaction per page | ✅ | ✅ |
| II. Pure, fully tested domain | Progression untouched; pulled plans are data, no recalculation (FR-024). Pure conflict helpers (`resolveIncoming`, `suffixName`) live in `lib/domain/sync_rules.dart` with tests first | ✅ | ✅ |
| III. Test-first gates | Tests before code for sync rules, service, migration; pgTAP for backend; gates per milestone | ✅ | ✅ |
| IV. Layered architecture | `lib/data/sync/` behind `SyncRemote`; `AuthRepository`; widgets use providers only; no new UI kit | ✅ | ✅ |
| V. One-tap gym UX | No UI in the workout flow; destructive account actions confirm | ✅ | ✅ |
| VI. Privacy & secrets | Opt-in Google sign-in; RLS owner-only tested; keys via `--dart-define-from-file`; service-role key only in Edge Function secrets; raw GPS fixes never synced | ✅ | ✅ |
| VII. Scope discipline | Android + Google only; no Apple/email login, no live push, no sharing; no social columns | ✅ | ✅ |
| Tech constraints | `supabase_flutter`, `google_sign_in` allowed in v1.5.0; migrations in `supabase/migrations/` with pgTAP | ✅ | ✅ |

No violations; Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/013-cloud-sync/
├── spec.md
├── plan.md              # this file
├── research.md          # R1–R15 decisions
├── data-model.md        # local v8, server tables, triggers, RLS, binding state machine, sync cycle
├── quickstart.md        # validation guide
├── contracts/
│   ├── sync-backend.md  # sync_push, pull, probe, delete-account
│   └── app-interfaces.md # SyncRemote, SyncService, AuthRepository, DeviceBinding, Settings UI
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
supabase/
├── config.toml
├── migrations/
│   ├── <ts>_sync_tables.sql        # tables, indexes, CHECKs
│   ├── <ts>_sync_triggers.sql      # sync_guard, child-of-tombstone, cascade-tombstone
│   ├── <ts>_sync_rls.sql           # RLS + grants
│   └── <ts>_sync_push.sql          # sync_push(payload jsonb)
├── functions/delete-account/index.ts
├── seed.sql                        # two local test users (local stack only)
└── tests/                          # pgTAP: rls, lww, tombstones, sync_push

lib/
├── domain/sync_rules.dart          # pure: incoming-vs-local decision, name suffixing, set collision pick
├── data/
│   ├── db/tables.dart              # + SyncState table
│   ├── db/app_database.dart        # schemaVersion 8, from7To8
│   ├── sync/
│   │   ├── sync_table.dart         # table registry: local↔server mapping, FK order, row (de)serialisers
│   │   ├── sync_remote.dart        # interface + PushBatch/PushResult
│   │   ├── supabase_sync_remote.dart
│   │   ├── sync_service.dart       # cycle, single-flight, debounce, status stream
│   │   ├── pull_applier.dart       # apply rules (data-model §6)
│   │   ├── push_collector.dart     # read dirty rows + deletes, clear-if-unchanged
│   │   └── device_binding.dart     # decide/bind/wipe
│   ├── repositories/auth_repository.dart
│   ├── repositories/settings_repository.dart   # + sync stamps for whitelisted keys
│   └── providers.dart              # + supabase client, auth, sync providers
├── app/app.dart                    # Supabase.initialize when configured; lifecycle sync triggers
└── features/settings/account_section.dart (+ dialogs)

test/
├── domain/sync_rules_test.dart
├── data/db/migration_v8_test.dart
├── data/sync/ (fake_sync_remote.dart, push_test, pull_test, two_device_test, binding_test)
└── features/settings/account_section_test.dart
integration_test/sync_test.dart     # opt-in, local Supabase stack
docs/sync-setup.md                  # Google Cloud + Supabase setup steps
env/example.json                    # + SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_WEB_CLIENT_ID (empty)
```

**Structure Decision**: Existing Flutter layout (constitution IV) plus a top-level `supabase/` folder for the backend.
Sync logic is split into small files under `lib/data/sync/` so each piece (collector, applier, binding) is unit-tested
alone; the only pure decisions go to `lib/domain/sync_rules.dart`.

## Implementation Phases (input for /speckit-tasks)

Each phase ends with format + analyze + test green and a commit.

1. **Groundwork**: add packages, env keys (empty example), `Supabase.initialize` only when configured;
   `docs/sync-setup.md`. Update PRD §8 and `docs/ARCHITECTURE.md` "Sync design" to this plan.
2. **Backend** (tests first, pgTAP): tables, triggers, RLS, `sync_push`, seed users, Edge Function.
3. **Local schema v8**: `sync_state`, migration + test; audit every delete path queues `pending_deletes` (test per
   repository delete); settings sync stamps.
4. **Sync engine** (tests first): `sync_rules` (domain), table registry, `FakeSyncRemote`, push collector, pull
   applier, `SyncService`; two-device convergence tests (SC-007).
5. **Supabase remote**: `SupabaseSyncRemote`; opt-in integration test against the local stack.
6. **Auth & binding**: `AuthRepository` (Google), `DeviceBinding`, decision flow and dialogs; Settings "Account &
   backup" section; widget tests.
7. **Triggers & polish**: app start/resume/finish/sign-in triggers, debounce, status stream, restore progress,
   one-time nudge, delete account.
8. **Verification**: quickstart §1–4 on two emulators; hosted Supabase project + release SHA-1 (owner steps).

## Risks

| Risk | Mitigation |
|---|---|
| Fake remote drifts from real server rules | Same scenario list runs against fake (unit) and local stack (integration); pgTAP covers the triggers |
| Google sign-in config errors (SHA-1, nonce) | `docs/sync-setup.md` checklist; R11 nonce fallback; manual check in phase 8 |
| Large restore freezes UI | Paged pull, one transaction per page, progress stream; perf check against SC-002 with a generated history |
| A delete path forgets `pending_deletes` | Phase 3 audit with a test per delete path |
| 012 not merged to `main` yet | Merge 012 before merging 013 (this branch is based on 012) |

## Complexity Tracking

None.
