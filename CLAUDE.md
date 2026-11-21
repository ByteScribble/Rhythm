# Rhythm (Flutter, Android) — working rules

- Spec: `REQUIREMENTS.md` is the source of truth. Visuals: `reference/design/*.dc.html`. Behaviour reference: `reference/web/app.js` (port its logic; don't reinvent).
- Follow the build plan in REQUIREMENTS.md §14 in order. Commit after each step with a clear message.
- Offline only: no network calls, no new packages beyond `flutter_local_notifications`, `timezone`, `shared_preferences` without a written reason.
- Keep business logic in `lib/data/logic.dart` (pure Dart, no Flutter imports) and test it.
- All "now" values go through `Clock` so tests can fake time.
- Colors, spacing, radii, durations only from `lib/theme/tokens.dart` — no literal hex in widgets.
- Before saying a step is done: `flutter analyze` (0 issues) and `flutter test` (green).
- Copy tone: supportive, neutral, never guilt-based.
- Don't modify `reference/` — it's read-only input.
