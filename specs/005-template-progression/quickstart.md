# Quickstart: validate template progression

```bash
export JAVA_HOME=$HOME/development/jdk-17/Contents/Home ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$HOME/development/flutter/bin:$JAVA_HOME/bin:$PATH
dart format --set-exit-if-changed . && flutter analyze && flutter test -j 1
```

Automated: `test/domain/progression_test.dart` (rule), `test/data/template_progression_test.dart`
(per-template §11 scenarios and isolation), `test/drift/fitapp/migration_test.dart` (v2→v3).

On the phone:

1. Open a template (e.g. "Chest") → each exercise shows its plan; tap Cable Fly → set 20 kg, 3 × 10,
   +2.5 → Save.
2. Start "Chest", log Cable Fly 20×10, 20×10, skip or fail set 3, finish → summary shows
   `Cable Fly: 20 kg → 22.5 kg`.
3. Start "Chest" again → Cable Fly prescribes 22.5, 22.5, 25. Discard.
4. Start an empty workout, add Cable Fly → it still prescribes the exercise's own plan (unchanged).
5. In History, open the Chest workout, change set 2 to 9 reps → the Chest plan is back to 20.
