# Rhythm

Rhythm is a calm, offline daily-routine tracker for Android. You define time-boxed activities (say, 6:00-7:00 Yoga) that repeat on the weekdays you choose, and the app answers a few quiet questions: what should I be doing now, what is next, what have I done today, and how consistent have I been. A small animated face reacts to how each activity went, and the wording stays supportive, never guilt-based.

> **Status:** early-stage. The core app works, but expect rough edges and changes.

## Features

- **Activities** with a name, icon, start and end time, and repeat days (daily, weekdays, weekends, or any custom set). Add, edit, and delete; deleting keeps past history.
- **Today screen** with a "now" card for the current activity, up next, a free-time state with "Start early", and a wrap-up at the end of the day.
- **Check-ins**: mark an activity completed, partially completed (25, 50 or 75 percent, with an optional note), or skipped, with undo. If a window ends with no answer, the app can ask once and "Ask me later" snoozes it.
- **Routine screen** listing every activity and its schedule.
- **Insights** for the current week or month, with per-activity consistency, a change versus the previous period, and the most consistent and most missed activities.
- **Reminders** as local notifications: at start, shortly before the end, and a check-in after. Notification buttons can record a result with the app closed. Alarms are rescheduled after a reboot.
- **Starter content**: a morning routine and a workday template, plus a sample routine with two weeks of history for trying things out.
- **Buddy reactions** that can be set to on, quiet, or off.
- **Erase all data** from settings.

## Privacy

Rhythm is fully offline. It has no backend, no accounts, no analytics, and makes no network calls. The release manifest does not request the `INTERNET` permission (only debug and profile builds add it, for tooling). All data is stored on the device with `shared_preferences`. The only permissions requested are for notifications, scheduling alarms, boot completion, and vibration.

## Requirements

- Flutter (stable) with Dart `^3.12.2`, as set in `pubspec.yaml`
- Android SDK, with an emulator or device on Android 7.0 (API 24) or newer
- JDK 17

Runtime dependencies are deliberately few: `flutter_local_notifications`, `timezone`, and `shared_preferences`.

## Run, test, build

```bash
flutter pub get
flutter run                    # debug, on a connected device or emulator
flutter analyze                # expected: no issues
flutter test
flutter build apk --release    # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle        # for Play uploads
```

## Release signing (for forks)

`android/app/build.gradle.kts` reads `android/key.properties` if it exists. That file and any keystore are git-ignored; never commit them. Without it, release builds fall back to the debug key, so `flutter build apk --release` still works locally, but the result is not suitable for distribution.

To sign your own builds, create a keystore with `keytool`, then add `android/key.properties`:

```properties
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=<your-key-alias>
storeFile=/absolute/path/to/your-release.keystore
```

If you publish your own fork, also change `applicationId` and `namespace` in `android/app/build.gradle.kts` (currently `com.bytescribble.rhythm`) and the Kotlin/Java package to match.

## Project layout

```
lib/
  main.dart                    bootstrap: store, queued notification actions, app, reminders
  app.dart                     MaterialApp, theme, scopes
  theme/tokens.dart            colors, spacing, radii, shadows, motion, text styles
  data/models.dart             Activity, LogEntry, Settings, JSON
  data/logic.dart              pure rules: statuses, NOW card, stats, formatting, notification plan
  data/store.dart              AppStore (ChangeNotifier): persistence, CRUD, logs, templates, demo
  data/clock.dart              Clock, so tests can fake time
  services/                    reminders interface and the flutter_local_notifications implementation
  widgets/                     buddy face, bubble, buttons, chips, cards, toast, sheet helper
  screens/                     shell, Today, Routine, Insights, editor, sheets/
test/                          logic, store, and widget smoke tests
assets/fonts/                  bundled Geist fonts and their licence
assets/android-res/            launcher and notification icons
android/                       Android project
```

Design notes: business logic lives in `lib/data/logic.dart` (pure Dart, no Flutter imports) and every "now" goes through `Clock`. Colors, spacing, radii and durations come from `lib/theme/tokens.dart`.

## Contributing

Issues and pull requests are welcome. Please keep changes small and focused, and before opening a PR make sure `flutter analyze` reports no issues and `flutter test` passes. Keep the app offline and the dependency list short; a new package needs a clear reason in the PR description. Add tests for logic changes. Copy should stay calm and supportive.

## License

MIT. See [LICENSE](LICENSE).

The bundled Geist font is licensed under the SIL Open Font License 1.1; see `assets/fonts/OFL.txt`.
