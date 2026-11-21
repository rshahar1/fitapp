# Quickstart: validate the Iron plate look

## Checks

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

`test/app/theme_guard_test.dart` fails if any old palette hex, `Icons.`, circle or stadium shape
remains in `lib/`.

## Owner review on the emulator

```bash
flutter emulators --launch fitapp_sim
flutter run -d emulator-5554
```

Walk-through (every item must show soot / chalk / yellow, square shapes, capital titles, sharp
icons):

1. Train tab, bottom bar, Go block → Go sheet → start empty workout and a template.
2. Workout: add exercise (picker, library, custom exercise sheet), log sets, edit a set (sheet,
   steppers), rest block, milestone reward, finish summary, discard dialog.
3. History calendar and rows, workout detail; Progress, exercise detail chart and chips.
4. Templates list and editor; Activities: add activity sheet, activity detail, snow day,
   replay, compare.
5. Track setup, live tracking (simulation bar), finish sheet with map.
6. You tab, Settings (switches, duration picker, map style), Account, Privacy.
7. Share preview for gym, route and snow; open the exported PNG.
8. Launcher icon and cold-start splash.

Rejects are fixed on `034-iron-plate-theme` and re-checked with hot reload (`r`).
Nothing is merged, version-bumped or released before approval.
