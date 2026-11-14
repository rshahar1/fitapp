# FitApp

Flutter (Android-first) offline gym logger with automatic progressive overload.
Developed with GitHub Spec Kit (spec-driven development).

- Product requirements: `docs/PRD-fitapp-flutter.md` (v2.5, authoritative)
- Constitution: `.specify/memory/constitution.md`
- Active feature: `specs/009-pilates-distance/` (spec, plan, tasks)

Workflow: `/speckit-analyze` (optional) → `/speckit-implement`, phase by phase. After each milestone run
`dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, show the result, and commit.
Domain (`lib/domain/`) stays pure Dart with tests written first.
