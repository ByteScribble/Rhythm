# Rhythm — Flutter Android App Requirements

**Version:** 1.0 · **Date:** 4 Oct 2026 · **Owner:** Hritik
**Audience:** the coding agent or developer who builds the app. Read this whole file before writing code.

---

## 0. How to use this kit

```
rhythm_flutter/
  REQUIREMENTS.md        ← this spec (source of truth)
  CLAUDE.md              ← short working rules for the coding agent
  assets/fonts/          ← Geist Regular/Medium/SemiBold/Bold (.ttf, SIL OFL)
  assets/android-res/    ← launcher icons (mipmap-*) + notification icon (drawable/ic_stat_rhythm.xml)
  assets/icon-only.png   ← 1024px master icon
  reference/web/         ← working web prototype (app.js = behaviour reference, app.css = visual reference)
  reference/design/      ← design canvas screens (.dc.html): visual source for every screen
```

**Precedence when sources disagree:** this file → `reference/design/*.dc.html` (visuals) → `reference/web/app.js` (behaviour).
The web prototype already implements almost every rule below; port its logic rather than reinventing it.

---

## 1. Product summary

Rhythm is a calm, personal daily-routine tracker. The user defines time-boxed activities (e.g. 6:00–7:00 Yoga) that repeat on chosen weekdays. The app answers five questions at a glance:

1. What should I be doing right now?
2. What comes next?
3. What have I completed today?
4. What did I miss?
5. How consistent am I over time?

Feel: "a calm operating system for my day" — spacious, quiet, trustworthy. Not a dense dashboard, not a childish habit tracker. One dominant action per screen.

A small animated **buddy face** reacts to each activity's status (happy when done, sad when missed, etc.) and "talks" in a speech bubble. It is drawn in code, never a system emoji.

---

## 2. Hard constraints

| # | Constraint |
|---|---|
| C1 | **100% offline.** No backend, no accounts, no analytics, no network calls at runtime. Remove the `INTERNET` permission from the release manifest. |
| C2 | All data stored on-device. |
| C3 | **Android only** for v1 (min SDK 24, target/compile = Flutter defaults, ≥ 35). |
| C4 | Flutter stable **3.29 or newer** (Kotlin-DSL Gradle files), Dart 3, null-safe. Custom theme (§8), no default Material look. |
| C5 | Minimal dependencies. Allowed packages only: `flutter_local_notifications`, `timezone`, `shared_preferences`. Anything else needs a written reason in the PR/commit message. No state-management package (use `ChangeNotifier` + `ListenableBuilder`). No `google_fonts` (it fetches at runtime) — fonts are bundled. |
| C6 | Must pass `flutter analyze` with zero errors/warnings and `flutter test` green. |
| C7 | Reminders must still fire when the app is closed and after a phone reboot. |

---

## 3. Tech stack & project setup

1. In this folder run:
   `flutter create --org com.hritik --project-name rhythm --platforms android .`
   (keeps the existing files; generates `android/`, `lib/main.dart`, `test/`).
2. `pubspec.yaml` dependencies (use latest compatible versions; these are minimums):
   ```yaml
   dependencies:
     flutter: { sdk: flutter }
     flutter_local_notifications: ^19.4.0
     timezone: ^0.10.0
     shared_preferences: ^2.5.0
   dev_dependencies:
     flutter_test: { sdk: flutter }
     flutter_lints: ^5.0.0
   flutter:
     uses-material-design: true
     fonts:
       - family: Geist
         fonts:
           - { asset: assets/fonts/Geist-Regular.ttf, weight: 400 }
           - { asset: assets/fonts/Geist-Medium.ttf, weight: 500 }
           - { asset: assets/fonts/Geist-SemiBold.ttf, weight: 600 }
           - { asset: assets/fonts/Geist-Bold.ttf, weight: 700 }
   ```
   If a newer major of `flutter_local_notifications` is the only one that resolves, use it and adapt to its API (check its CHANGELOG).
3. Copy `assets/android-res/*` into `android/app/src/main/res/` (overwrite the default launcher icons).
4. Android Gradle (`android/app/build.gradle.kts`) — required by `flutter_local_notifications`. Keep everything `flutter create` generated and add/adjust only these lines (if your Flutter generated Groovy `build.gradle`, apply the equivalent):
   ```kotlin
   android {
     namespace = "com.hritik.rhythm"
     compileSdk = flutter.compileSdkVersion
     compileOptions {
       isCoreLibraryDesugaringEnabled = true
       sourceCompatibility = JavaVersion.VERSION_11
       targetCompatibility = JavaVersion.VERSION_11
     }
     defaultConfig { applicationId = "com.hritik.rhythm"; minSdk = 24 }
   }
   dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }
   ```
5. `AndroidManifest.xml`:
   - App label `Rhythm`, icon `@mipmap/ic_launcher`, round icon `@mipmap/ic_launcher_round`.
   - Permissions: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `VIBRATE`. **Not** `USE_EXACT_ALARM` (Play policy). No `INTERNET` in release (debug may keep it for hot reload via `src/debug/AndroidManifest.xml`).
   - Inside `<application>` add the plugin receivers:
     ```xml
     <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"/>
     <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
     <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
       <intent-filter>
         <action android:name="android.intent.action.BOOT_COMPLETED"/>
         <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
         <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
         <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
       </intent-filter>
     </receiver>
     ```
   - Main activity: `android:windowSoftInputMode="adjustResize"`. Predictive back is on by default at target 35; handle back with `PopScope`.
6. Edge-to-edge with transparent status/navigation bars; respect `MediaQuery.padding` (SafeArea) everywhere. Status bar icons dark.

---

## 4. Architecture

```
lib/
  main.dart                 bootstrap: init store, notifications, run app
  app.dart                  MaterialApp, theme, root shell
  theme/tokens.dart         colors, spacing, radii, shadows, durations, text styles (§8)
  data/models.dart          Activity, LogEntry, Settings, enums, JSON (§5)
  data/logic.dart           PURE functions: today items, statuses, stats, formatting (§6) — no Flutter imports
  data/store.dart           AppStore extends ChangeNotifier: load/save, CRUD, logs, settings, templates, demo
  data/clock.dart           Clock abstraction (now()) so tests can fake time
  services/notifications.dart  scheduling, permissions, action handling (§10)
  widgets/                  buddy.dart, bubble.dart, buttons.dart, chips.dart, status_node.dart,
                            progress_bar.dart, activity_icon.dart, cards.dart, toast.dart, switch_row.dart
  screens/
    shell.dart              bottom nav, 30 s ticker, lifecycle, missed-prompt trigger
    today_screen.dart
    routine_screen.dart
    insights_screen.dart
    editor_screen.dart      add + edit (full-screen route)
    sheets/                 checkin_sheet.dart, missed_sheet.dart, row_menu_sheet.dart, settings_sheet.dart
test/
  logic_test.dart           unit tests for §6 (required)
  store_test.dart           JSON round-trip, CRUD, undo
  widget_smoke_test.dart    pumps app with fake clock + demo data, taps through main flows
```

- **State:** a single `AppStore` (ChangeNotifier) provided via an `InheritedNotifier` (`StoreScope.of(context)`). Screens rebuild with `ListenableBuilder`.
- **Time:** every "now" goes through `Clock`. The shell runs a `Timer.periodic(30s)` that calls `store.tick()` → notifyListeners, plus refreshes on `AppLifecycleState.resumed`.
- **No business logic in widgets.** Widgets call store methods and render results of `logic.dart`.

---

## 5. Data model & storage

Storage: `SharedPreferencesAsync` (no in-memory cache, safe across isolates). One key `rhythm.v1` holding a JSON document, plus key `rhythm.pendingActions` (see §10.4). Write **immediately** after every activity/log mutation (await the write); settings may be debounced; also flush on `AppLifecycleState.paused`. Corrupt/missing JSON → start empty, never crash.
**Only the main isolate ever writes `rhythm.v1`.** The notification background isolate writes only `rhythm.pendingActions` (§10.4), so two isolates never overwrite the same blob.

```jsonc
{
  "schema": 1,
  "activities": [
    {
      "id": "k3j9x2a",            // random 7-char base36
      "name": "Yoga",              // 1–40 chars, trimmed
      "icon": "yoga",              // key from §9.6
      "start": "06:00",            // HH:mm 24h
      "end": "07:00",              // HH:mm, must be > start (same day only; no overnight in v1)
      "days": [0,1,2,3,4,5,6],     // 0=Mon … 6=Sun, non-empty
      "remindStart": true,
      "remindEnd": true,           // 10 min before end
      "askMissed": true,           // check-in at end
      "createdAt": "2026-10-04",   // yyyy-MM-dd local
      "createdMin": 383            // minutes since midnight at creation (nullable)
    }
  ],
  "logs": {
    "2026-10-04": {
      "k3j9x2a": { "status": "done|partial|skipped", "at": 383, "amount": 50, "note": "…" }
    }
  },
  "settings": { "reactions": "on|quiet|off", "notify": true }
}
```

- `amount` (25/50/75) and `note` (≤120 chars) only for `partial`.
- "missed" is **never stored**; it is derived (§6).
- Deleting an activity keeps its old logs (history stays) but removes it from all lists and stats.

---

## 6. Core logic (pure, unit-tested)

Definitions: `nm` = now in minutes since local midnight (with seconds as fraction). `s`, `e` = activity start/end minutes. `mon0(date)` = (weekday + 6) % 7 with Monday = 0.

### 6.1 Scheduled on a date
`scheduledOn(a, d)` ⇔ `a.days` contains `mon0(d)` **and** `dateKey(d) >= a.createdAt`.

### 6.2 Status of an activity today (evaluate in this order)
1. A log exists → its status (`done` / `partial` / `skipped`).
2. `createdAt == today` and `createdMin != null` and `e <= createdMin` → `na` ("Added after this window"; never prompts, excluded from stats).
3. `s <= nm < e` → `now`.
4. `earlyStartId == a.id` and `nm < s` → `now` (user tapped "Start early"; in-memory only).
5. `nm < s` → `upcoming`.
6. otherwise → `missed`.

Today's list = activities scheduled today, sorted by start, then name.

### 6.3 The NOW card (Today screen) — choose exactly one state
- **No activities at all** → Empty state (§9.1.6).
- **None scheduled today** → "A free day" card.
- `focus` = the **first** item (in sorted order) whose window contains `nm` (`s <= nm < e`), else the first item with status `now` (early start). Overlaps are allowed, so pick the first.
  - focus status `now` → **Active card**.
  - focus resolved (done/partial/skipped) while still inside its window → **Resolved card**.
- No focus, a later item exists → **Free time card** with "Up next" + "Start early".
- No focus, nothing later → **Wrap-up card** ("That's today"), happy face if (done + partial) / (all today's items excluding `na`) ≥ 0.6, otherwise partial face. The bubble line uses the same counts. Subtitle: "Rest well. Tomorrow starts with {name} at {time}." or "Rest well. Tomorrow starts with a free day."

### 6.4 Missed check-in prompt
On app open, resume, tab switch to Today and every 30 s tick — if no sheet/route is open and Today is visible — find items with status `missed`, `askMissed == true`, `nm - e < 180` (ended < 3 h ago), not snoozed. Show the **Missed sheet** for the most recently ended one. "Ask me later" snoozes that activity for 15 min (in memory). **Any dismissal without an answer (swipe down, back, tap on scrim) also counts as "Ask me later".**
Editing an activity so that its new window has already ended today must not trigger an instant prompt: on saving an edit, if the new `end <= nm` and there is no log today, set `createdAt = today` and `createdMin = round(nm)` so it shows as `na` today.

### 6.5 Stats (Insights)
For a range [from, to) of dates, iterate days up to today:
- skip if not `scheduledOn`;
- skip today's items whose window hasn't ended and have no log;
- skip items that have **no log** and are `na` (created after the window on their creation day) — a log always wins;
- otherwise count `sched += 1`; `done += 1` if done; `partial += 1` if partial.
- Per-activity `% = round((done + 0.5 × partial) / sched × 100)`; overall same formula over totals; shown count = `done + partial` of `sched`.
- Week = Monday–Sunday containing today; previous = the week before. Month = calendar month; previous = previous month.
- Delta chip = current overall % − previous overall % (hide if previous has no data).
- Most consistent = highest %, tie → earlier start. Most missed = lowest %. Show the pair only when ≥ 2 activities have data. Most-missed card: `missed` face if % < 50 else `partial`; suffix "· try another time?" if % < 60 else "· still solid".

### 6.6 Formatting
- 12-hour clock: `6:00 AM`; ranges collapse a shared suffix: `6:00 – 7:00 AM`, `11:30 AM – 12:15 PM`.
- Durations: `45 min`, `1 hr`, `1 hr 45 min`.
- Repeat label: all days → `Daily`; Mon–Fri → `Mon–Fri`; Sat+Sun → `Weekends`; else `Mon, Wed, Fri`.
- Greeting: <5 h "Good night", <12 "Good morning", <17 "Good afternoon", else "Good evening".
- Date header: `Sunday, 4 October`.

### 6.6a Stable hash (used for bubble lines, demo data, notification IDs)
Dart's `String.hashCode` is not stable across runs — never use it for these. Use this port of the web prototype:
```dart
int stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) { h = ((h * 31 + c) & 0xFFFFFFFF).toSigned(32); }
  return h.abs();
}
```

### 6.6b Midnight rollover
`tick()` detects a date change and then: clears `earlyStartId` and all snoozes, recomputes today, reschedules notifications. Animation keys include the date so nothing replays oddly.

### 6.7 Required unit tests (`test/logic_test.dart`)
Fake clock at Sunday 4 Oct 2026. Cover at minimum: each branch of 6.2; early start; `na` on creation day; NOW-card state selection for 06:23 / 07:04 / 12:20 / 23:00; prompt selection + snooze; week and month stats incl. partial = 0.5 and delta; repeat labels; range formatting across AM/PM; stats ignore deleted activities.

---

## 7. Screens & behaviour

Mobile frame reference: 390 × 844. Screen side padding 20, top = safe area + 28, section gap 28. Bottom nav 64 + safe area.

### 7.1 Today (default tab)
1. **Header** — eyebrow greeting (14, secondary), `Today` (28/600), date (14, secondary). Right: Settings icon button and Add icon button (44 × 44, white, 1 px border, radius 12).
2. **NOW section** — label `NOW` (13/600, +6 % tracking, uppercase, secondary). When not in an active window append ` · 12:20 PM`.
   - **Active card** (only element on the screen with shadow-2): buddy row (face 52 `now` + speech bubble), icon tile 44 (primary-soft/primary) + name (22/600) + range; 4 px progress bar of elapsed %; meta row "**37 min** remaining" / "Ends 7:00"; buttons: primary **Mark complete** (flex, 48 h, check icon) + secondary **More** (opens Check-in sheet).
     - Mark complete: one tap, no confirmation, haptic light impact, toast "Nice — Yoga complete" with **Undo** (3.2 s).
     - Early-started item: no progress bar; meta "Scheduled 7:00 – 7:30 AM"; bubble "Starting early? Love that. Tap complete when you're done."
   - **Resolved card**: face 56 by status (done → jump + sparkles), bubble line, name + "Logged at 6:23 AM", status chip, divider, Up-next row, text button **Undo** (clears the log).
   - **Free time card**: face `now`, bubble "Free time. Breathe — Lunch starts in 40 min.", chip "Free time", title "Nothing scheduled right now", sub "Your next activity starts in 40 min.", divider, Up-next row with secondary **Start early** (44 h).
   - **Wrap-up card** and **Free day card** as in §6.3, each with one secondary button (See this week / View routine).
3. **TODAY section** — label + "3 of 8 done" (done+partial+skipped of total). Summary chips (only non-zero): "6 completed", "1 partial", "2 to check in". Then the **timeline** (§9.3). Row tap: upcoming/na → Edit screen; missed with no log → Missed sheet; anything else → Check-in sheet.

### 7.2 Check-in sheet ("How did Yoga go?")
Bottom sheet (radius 28 top, grabber 36 × 4, padding 8/20/24 + safe area). Header: face 52 (`now`, or `partial` once Partial is chosen) + title (20/600) + sub "6:00 – 7:00 AM · One tap saves it".
Options (60 h rows, radius 14, 1 px border, 36 px face left, title 16/500 + description 13):
- **Completed** — "Finished as planned" → saves immediately, closes.
- **Partially completed** — "Did some of it — that counts" → row becomes selected (1.5 px warning border, #FFFBF3 fill) and reveals: amount chips 25 / 50 / 75 % (default 50), optional note field, buttons **Cancel** (text) + **Save as partial** (primary).
- **Skipped** — "Not today" → saves immediately.
Footer when not partial: **Clear check-in** (danger text, only if a log exists) and **Cancel**.
After saving: toast with Undo.

**Toast copy (complete list):** "Nice — Yoga complete" · "Yoga saved as partial" · "Yoga skipped" (all with Undo) · "Check-in cleared" · "Started early — enjoy" · "Template added" · "Evening walk added" · "Changes saved" · "Duplicated" · "Yoga deleted" (Undo) · "Sample routine loaded" · "All data erased". Partial-mode sheet subtitle: "Some is better than none — how much?".

### 7.3 Missed sheet ("Did you complete Yoga?")
Centered: face 72 `missed` (droop + tear, mouth talks once), title 22/600, body "The 6:00 – 7:00 AM window ended. A quick answer keeps your week accurate." Buttons: primary **Yes, done** (52 h, full width); row of two secondary 52 h: **Partially** (opens Check-in sheet in partial mode) and **No** (= skipped); text **Ask me later**.

### 7.4 Routine
Header `Routine` + "11 activities · repeats automatically" + Add icon button. Groups **Morning** (< 12:00), **Afternoon** (12:00–16:59), **Evening** (≥ 17:00), each a white list group (radius 16, hairline dividers) with a count on the right. Row (64 h): start time (72 w, tabular, secondary) · icon tile 36 · name 16 + "Daily · 1 hr" 13 · ⋮ button (44) → Row menu sheet: **Edit**, **Duplicate** ("Yoga (copy)"), **Delete** (danger; toast with Undo). Tapping the row opens Edit. Empty state: "No routines yet" + **Add activity**.
List is always chronological; no manual drag-reorder in v1.

### 7.5 Add / Edit activity (full-screen route, slides up)
Top bar: **Cancel** (left) · title "New activity" / "Edit activity". Body (scroll, gaps 24):
1. **Activity name** — text field 52 h, autofocus on new, max 40. Error "Give it a short name".
2. **Icon** — 6-column grid of 48 h tiles (12 icons, §9.6); selected = 1.5 px primary border + primary-soft fill.
3. **Start time / End time** — two fields side by side; tap opens `showTimePicker`, forced to 12 h by wrapping its `builder` in `MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false), child: child!)`. Hint below: "30 min · Drink water follows at 5:50 AM" or "… · overlaps Breakfast" (overlap = shares a weekday and time ranges intersect; warning only, not blocking). Changing start so that end ≤ start sets end = start + 30 min. Error "End time needs to be after 6:00 AM".
4. **Repeat** — segmented control Daily / Weekdays / Custom + 7 day chips (44 circles, M T W T F S S, `Semantics` with full day names). Custom pre-selects M W F when coming from Daily. Error "Pick at least one day".
5. **Reminders** — list group with 3 switch rows: Notify at start · Notify before end ("10 min before") · Ask if missed ("A quick check-in when it ends").
6. Edit only: **Delete activity** (danger text) + hint "Past history is kept either way."
Sticky footer: primary **Create activity** / **Save changes** (52 h, full width). New activity defaults: icon walk, start = end of the latest activity (or next half hour), 30 min, daily, all reminders on.
After save: pop, toast "Evening walk added" / "Changes saved", reschedule notifications.

### 7.6 Insights
Header `Insights`, sub = range label ("28 Sep – 4 Oct" or "October 2026"), right: segmented **Week | Month**.
1. `THIS WEEK` label; big number `82%` (48/600, tabular); "Overall completion · 41 of 50"; delta chip (green ↑ or neutral ↓, "6% vs last week"); 8 px bar.
2. `BY ACTIVITY` list group, sorted by % desc: name 16/500, "6 / 7 **86%**", 6 px bar (primary; primary-muted when < 50 %). Never red.
3. Two small cards side by side: **Most consistent** (success icon + still happy face 32) and **Most missed** (neutral clock icon + sad or partial face 32, suffix "· try another time?" when < 60 %).
Empty state: face `now` 64 + "Nothing to show yet" + "Insights appear once your first activity window has passed."

### 7.7 Settings sheet (gear on Today)
- **Reactions**: segmented On / Quiet / Off. Hint "On: animated face that talks. Quiet: face only. Off: classic icons." Off → no faces anywhere; sheets use plain status icons.
- **Reminders** master switch (cancels/reschedules all).
- **Load sample routine** — replaces all data with both templates (`createdAt = today − 13`, `createdMin = null`) and generates logs for the 13 previous days, deterministically: for each scheduled activity and day, `x = (stableHash(dateKey + name) % 100) / 100`, rate `r` = Yoga .86, Deep work .86, Reading .71, Meditation .43, others .80; `x < r − .08` → done, `x < r` → partial (amount 50), `x < r + .08` → skipped, else no log. `at = end − 5` (done/partial) or `end` (skipped). Today gets no logs.
- **Erase all data** — must ask for confirmation inside the sheet ("Erase everything? This can't be undone." + danger button). 
- **Done**.

### 7.8 Empty state (no activities)
Header as Today. Centered: 88 px dashed circle with 56 px primary-soft tile + sunrise icon; "Your day is empty." (22/600); "Add your first activity and we'll help you stay on track."; primary **Add activity**; "Or start from a template" + pills **Morning routine** / **Workday**.

### 7.9 Templates
- Morning: Wake up 05:45–05:50 (sun), Drink water 05:50–06:00 (water), Yoga 06:00–07:00 (yoga), Get ready 07:00–07:30 (shirt), Breakfast 07:30–08:00 (coffee) — daily.
- Workday: Deep work 08:00–10:00 (focus), Break 10:00–10:15 (pause), Study 10:15–12:00 (book) — Mon–Fri; Lunch 13:00–13:45 (bowl), Reading 15:00–15:45 (bookmark), Meditation 21:00–21:15 (moon) — daily.
- Adding a template skips items with the same name + start already present.

### 7.10 Navigation & system
- Bottom nav: Today / Routine / Insights. 22 px outline icon over 12 px label; selected = primary + 600; others secondary 500; no pill indicator; white bar, 1 px top border, no shadow. Switching tabs keeps each tab's scroll position.
- Android back: close sheet/route → else go to Today → else exit.
- Toasts: dark pill (#172033, white 14), above nav, optional **Undo** in #9DB8FF, auto-hide 3.2 s; hidden when a sheet opens.

---

## 8. Design tokens (`theme/tokens.dart`)

**Colors**
| Token | Hex | Use |
|---|---|---|
| bg | #F6F8FB | app background |
| surface | #FFFFFF | cards, lists, nav, sheets |
| subtle | #F1F4F8 | icon tiles, skipped |
| track | #EEF1F5 | progress track, segmented bg, hairlines |
| border | #E7EBF0 | card / input borders |
| borderStrong | #C9D0DB | upcoming node |
| text | #172033 | primary text |
| label | #475467 | field labels, icons |
| text2 | #667085 | secondary text |
| text3 | #98A2B3 | icons/disabled only — never readable copy |
| primary | #3D6BE0 | CTA, active node, selected tab (AA with white) |
| primaryPressed | #2F5BCB | pressed, link ink |
| primarySoft | #EDF3FF | now row, selection |
| primaryRing | #DCE6FD | now-node halo, focus ring |
| primaryMuted | #8FA9EE | bars < 50 % |
| success / successInk / successSoft | #34A36F / #1F7A52 / #EAF6EF | |
| warning / warningInk / warningSoft | #DFA247 / #A86A12 / #FCF3E3 | partial |
| danger / dangerInk / dangerSoft | #D9646A / #B9474D / #FBEDEE | missed, delete |
| scrim | rgba(23,32,51,.32) | behind sheets |

Text on soft fills always uses the matching `*Ink` color.

**Type** (Geist): stat 48/52 600 −3 % · heading 28/34 600 −2 % · title 22/28 600 −1 % · sheetTitle 20/26 600 · navTitle 17/22 600 · body 16/22 · bodySm 15/22 · secondary 14/20 · section 13/16 600 caps +6 % · meta 13/18 · caption 12/14 500. Times use `FontFeature.tabularFigures()`.

**Spacing** 4 · 8 · 12 · 16 · 20 · 24 · 28 · 32. **Radius** 6 (tags) · 9 (segment thumb) · 12 (buttons, inputs, tiles) · 14 (option rows, now row) · 16 (list groups, small cards) · 20 (Now card) · 28 (sheet top) · pill.
**Shadows** shadow-1 `0 1 2 rgba(16,24,40,.06)` (segment thumb, switch knob) · shadow-2 `0 6 24 rgba(16,24,40,.05)` (Now card only) · shadow-3 `0 −8 32 rgba(16,24,40,.08)` (sheets).
**Motion** fast 150 ms (press, toggles) · base 200 ms (row tint, chip swap, number tween) · check pop 220 ms (scale .6 → 1.08 → 1) · sheet 240 ms in / 180 ms out · curve `Cubic(.2,.8,.2,1)`, exit `Cubic(.4,0,1,1)`. Respect `MediaQuery.disableAnimations` → no loops, instant transitions.

Light theme only in v1 (dark theme is a v1.1 item; keep all colors in tokens so it's a swap).

---

## 9. Components

### 9.1 Buttons
Primary 48 h (52 in footers), radius 12, 16/600 white on primary, pressed primaryPressed + scale .98. Secondary: white, 1 px border, 15/500. Text: 44 h, primary/secondary/dangerInk. Icon button 44 × 44. Disabled: border fill + text3. Min touch target 44 everywhere.

### 9.2 Status chips
28 h, pill, padding 0 10, 13/500, 12 px glyph + word (never color alone): Now (dot) · Upcoming · Completed (check) · Partially done (half circle) · Skipped (dash) · Missed (×) · Free time (clock).

### 9.3 Timeline row
Min 60 h, padding 0 8, gap 12. Columns: time 48 w right-aligned ("6:00" over small "AM") · node 24 w with 2 px connector line (border color; starts at first node centre, ends at last) · body (name 16, status 13) · optional trailing face 28 (+ "Update" link for missed).
Nodes 20 px: done = filled success + white check (pop) · now = white, 2 px primary ring, 8 px primary dot, 4 px primaryRing halo · upcoming/na = white, 1.5 px borderStrong · partial = 2 px warning ring with left half filled · skipped = subtle fill, borderStrong ring, dash · missed = white, 1.5 px danger ring, × in dangerInk.
Now row background primarySoft radius 14, name 600, status "Now · 37 min left" in primaryPressed 500. Past rows' names drop to text2.
Status texts: "Completed", "Partially done · 50%", "Skipped", "Missed · no check-in", "Now · 37 min left", "Now · started early", "Upcoming · 30 min" (the activity's **duration** `e − s`, not time-until; row 0 says "Up first · 30 min"), "Added after this window".

### 9.4 Progress bar
Height 4 (now card) / 6 (per activity) / 8 (overall); radius pill; track = track (on white) or border (on bg); fill animates width 400 ms.

### 9.5 Bottom sheet
`showModalBottomSheet(isScrollControlled: true, useSafeArea: true, showDragHandle: true, backgroundColor: surface, barrierColor: scrim, shape: top radius 28, constraints: BoxConstraints(maxHeight: 0.92 * screenHeight))`, swipe-to-dismiss. Style the drag handle 36 × 4, #D5DAE1.

### 9.6 Activity icons
Keys → Material outlined/rounded icons (bundled, offline):
`sun` wb_twilight · `water` water_drop_outlined · `yoga` self_improvement · `shirt` checkroom · `coffee` coffee_outlined · `focus` center_focus_strong_outlined · `pause` pause_circle_outline · `book` menu_book_outlined · `bowl` rice_bowl_outlined · `bookmark` bookmark_border · `moon` bedtime_outlined · `walk` directions_walk.
Tile 36 (lists) / 40 (up next) / 44 (now card); radius 10/12; neutral = subtle + label; active = primarySoft + primary.

### 9.7 Buddy face (`widgets/buddy.dart`) — key feature
`Buddy(mood, size, {talk=false, sparkle=false, still=false})`, drawn with `CustomPainter` on a 56 × 56 design grid scaled to `size`. All strokes round caps, color #172033; stroke width 2.3 when size ≥ 52, 3.2 when ≤ 36. Face circle r = 25 at (28, 28), fill = mood soft, stroke = mood base (1.5; 2.4 when small).

| Mood | Fill / stroke | Features (56-grid coordinates; Q = quadratic Bézier) | Idle motion |
|---|---|---|---|
| now | #EDF3FF / #3D6BE0 | eyes: filled ellipses (21,25) & (35,25) rx 2.6 ry 3.4 · mouth: M22 35 Q28 40 34 35 | bob ±3 px, 3 s; eyes glance +2.5 px, 5 s; blink |
| done | #EAF6EF / #34A36F | happy eyes: M16.5 26 Q20.5 20.5 24.5 26 and M31.5 26 Q35.5 20.5 39.5 26 · cheeks: circles (14.5,32.5) & (41.5,32.5) r 3 #F4B4B8 80 % · open mouth filled: M19 32 Q28 45 37 32 Z · tongue (large only): M23.5 38 Q28 35.5 32.5 38 Q28 41.5 23.5 38 Z #E8838A | entry jump 700 ms (−12 px, squash 1.08/.92) then bob; sparkles optional |
| partial | #FCF3E3 / #DFA247 | raised brow M32 18.5 Q35.5 16.5 39 18.5 · eyes (21,25.5) ry 3.2 & (35,24.5) ry 3.4 · lopsided mouth M21 35 Q28 38.5 35 33 | tilt −7°/+5°, 2.4 s, pivot bottom-centre; blink |
| skipped | #F1F4F8 / #98A2B3 | relaxed closed eyes M17.5 26.5 Q21 28.8 24.5 26.5 and M31.5 26.5 Q35 28.8 38.5 26.5 · mouth M23 36 Q28 37.5 33 36 · small "z" at (42,14) #98A2B3 (large only) | sway +2 px / +3°, 3.2 s |
| missed | #FBEDEE / #D9646A | **sad brows (inner ends higher):** M16.5 23 L23.5 20 and M39.5 23 L32.5 20 · eyes (21,27) & (35,27) ry 3 · frown M21.5 38.5 Q28 33 34.5 38.5 · tear drop M37 30.5 Q39.2 33.9 37 35.5 Q34.8 33.9 37 30.5 Z #7FA3EE | droop +2 px / −4°, 3.2 s; tear drips 0 → 11 px and fades, 2.2 s loop |

- **Blink:** eyes scaleY 1 → 0.1 → 1 over ~160 ms every 4 s.
- **Talk:** when `talk` is true the mouth scaleY oscillates 1 ↔ 0.35, 8 half-cycles × 180 ms, starting 120 ms after mount; plays once per mount.
- **Sparkles** (done + sparkle): three 4-point stars (12/10/8 px; #DFA247, #34A36F, #3D6BE0) around the face, scale 0 → 1 → 0.6 with rotation and fade, 1.4 s loop, staggered 0/.45/.9 s.
- **Replay rule:** entry effects (jump, talk, bubble pop, sparkles, node pop) play only when the mood/status actually changes — NOT on every 30 s tick rebuild. Key the widget by `activityId + status`.
- `still: true` disables idle loops (used for 28 px timeline faces of done/skipped and Insights cards); small faces may still blink.
- Faces are decorative: wrap in `ExcludeSemantics`. Meaning is always carried by text + node shape.
- Use one `AnimationController` per face; dispose properly; pause when `TickerMode` is off.

**Speech bubble:** fills remaining width beside the face, background bg, 1 px track border, radius 16/16/16/4 (tail corner toward the face), padding 10/14, 14/20 text, max 2 lines, pops in (opacity + 4 px rise + scale .92 → 1, 260 ms, 120 ms delay). Reactions = Quiet → face without bubble; Off → no buddy row.
Lines (pick deterministically from `hash(activityId + date)` so text doesn't flicker):
- now: "{m} min in. Keep breathing — you've got this." · "Nice and steady. {remaining} to go." · "You're in it. Just this, for now." · "Settled in? {remaining} left — no rush."
- done: "{name} done! Lovely work." · "That's one for the books. Nicely done." · "{name} — complete. You're on a roll." · "Done and dusted. Proud of you."
- partial: "Some {name} beats none. Proud of you." · "Showing up counts. Well done." · "A bit is still progress."
- skipped: "Rest is part of the plan too." · "No worries — tomorrow's a fresh start." · "Skipped is fine. Onwards."
- free: "Free time. Breathe — {next} starts in {in}." · "A little gap. {next} is up in {in}."
- wrap good: "That's a wrap! {d} of {t} done today." · wrap meh: "Day's done. {d} of {t} — tomorrow's a fresh page."
Tone rule: supportive and neutral, never guilt ("You failed", "Streak broken!" are banned).

---

## 10. Notifications (offline, local only)

### 10.1 Setup
- `flutter_local_notifications` with `AndroidInitializationSettings('ic_stat_rhythm')` (monochrome vector already in `assets/android-res/drawable`). Accent color #3D6BE0.
- One channel `reminders` / "Reminders", importance high.
- Timezone: initialise `timezone` data; convert each local `DateTime` with `tz.TZDateTime.from(localDateTime, tz.UTC)` (same absolute instant; avoids a native timezone plugin). Reschedule on every app start/resume so DST changes are absorbed. Known v1 limitation: if the device timezone changes while the app is closed, alarms keep their old instants until the next open.

### 10.2 What to schedule
For today + next 2 days, for each scheduled activity **without a log** and with the setting on (master `notify` must be on):
| Trigger | Title | Body | Actions |
|---|---|---|---|
| start (`remindStart`) | "Yoga starts now" | "6:00 – 7:00 AM" | Start · Skip |
| end − 10 min (`remindEnd`, only if > start) | "Yoga ends in 10 minutes" | "Wrap up whenever you're ready." | Complete |
| end (`askMissed`) | "Did you finish Yoga?" | "One tap keeps your week accurate." | Yes · Partially · No |
Only times later than `now + 5 s` (the plugin throws for past dates). Collect all candidates, **sort by fire time ascending, keep the first 60**. Payload JSON `{"actId": "...", "date": "yyyy-MM-dd"}`. IDs deterministic: hash(actId + date + kind) & 0x7fffffff.

### 10.3 Rescheduling
Whenever: app start, resume, any activity/log/settings change, and right after notification permission is granted — cancel only the **pending** requests (`pendingNotificationRequests()` → `cancel(id)`; never `cancelAll()`, which also clears notifications currently on screen), then schedule. Debounce 300 ms. Also cancel an activity's shown notifications once it gets a log.

### 10.4 Actions
- Action buttons use `showsUserInterface: false`, `cancelNotification: true`, except "Start" and "Partially" which open the app (`showsUserInterface: true`; "Partially" opens the Check-in sheet in partial mode for that activity/date; "Start" opens Today).
- Background handler (`@pragma('vm:entry-point')` top-level function passed as `onDidReceiveBackgroundNotificationResponse`): append `{actId, date, action, atMinutes}` to `rhythm.pendingActions` via `SharedPreferencesAsync` (call `WidgetsFlutterBinding.ensureInitialized()` / `DartPluginRegistrant.ensureInitialized()` first). Map: Yes/Complete → done, Partially → partial (amount 50), No/Skip → skipped.
- **Important:** in v19, non-UI action buttons (`showsUserInterface: false`) are delivered to the background handler in a separate isolate **even when the app is in the foreground**. `onDidReceiveNotificationResponse` only receives body taps and `showsUserInterface: true` actions. So all non-UI actions go through `rhythm.pendingActions`.
- The store drains `pendingActions` on app start (before first render), on `resumed`, and on every 30 s tick: read → apply in order → clear. No debounce on the drain.
- Failure cases: `actId` no longer exists → drop silently. Payload `date` ≠ today → write the log under the payload date (correct after midnight). `at` = tap time.
- **Verify this path first in step 11** (§13.7 depends on it). If `SharedPreferencesAsync` is unavailable in the background isolate on your Flutter version, add `path_provider` (allowed exception) and use an append-only JSON-lines file as the queue instead.
- Tapping the notification body: open app on Today; if it's a check-in for today, open the Check-in sheet for that activity. Handle cold start via `getNotificationAppLaunchDetails()`.

### 10.5 Permissions
- First time the user creates an activity or adds a template (not at cold start), request `POST_NOTIFICATIONS` (Android 13+).
- Exact alarms: if `canScheduleExactNotifications()` is false, schedule with `AndroidScheduleMode.inexactAllowWhileIdle` and show, once, a dismissible hint in Settings: "Reminders may arrive a few minutes late. Allow exact alarms" → `requestExactAlarmsPermission()`. Otherwise use `exactAllowWhileIdle`.
- If notifications are denied, the app works fully; the Settings switch shows "Turn on in system settings".
- Exact alarms are denied by default on Android 14+, so most devices will use inexact delivery (can be 10+ min late in Doze). That is acceptable; the hint lets the user opt in.

---

## 11. Accessibility & quality

- Text contrast ≥ 4.5:1 (tokens already comply); status never by color alone.
- All tappable areas ≥ 44 × 44; icon-only buttons have `Semantics`/`tooltip` labels ("Add activity", "Settings", "Options for Yoga").
- Timeline row semantics: "Yoga, 6:00 AM, completed".
- Supports system font scale up to 1.3 without overflow (use `Flexible`, ellipsis on names).
- Reduced motion respected (§8).
- No jank: ticker rebuilds must not restart animations (§9.7 replay rule); `const` constructors where possible.
- Never crash on bad data; log and recover.

---

## 12. Out of scope (v1)

Dark theme · iOS · cloud sync/backup · overnight activities · drag-reorder · streak gamification · widgets · Wear OS · export. (Leave code seams for dark theme and JSON export.)

---

## 13. Delivery checklist / acceptance criteria

The build is accepted when all of these hold on a real Android 13+ device or emulator:

1. `flutter analyze` → 0 issues; `flutter test` → all pass; `flutter build apk --release` succeeds.
2. Fresh install shows the Empty state; "Morning routine" template fills Today correctly for the current time.
3. At 06:23 (with Morning template): Active card for Yoga, 37 min remaining, progress ≈ 38 %; Wake up / Drink water show "Added after this window" if the template was added after 06:00 today.
4. Mark complete → node pops to green check, face jumps with sparkles, toast with Undo; Undo restores. 30 s ticks do not replay these animations.
5. More → Partially → 75 % + note → Save → timeline shows "Partially done · 75%".
6. When a window ends without a check-in and the app is open, the Missed sheet appears within 30 s; "Ask me later" hides it for 15 min.
7. With the app killed: start, 10-min, and end notifications arrive (on time with exact alarms granted; within ±15 min otherwise); tapping **Yes** on "Did you finish…?" without opening the app records Done (visible on next open). Works after a reboot. Tapping **Yes** while the app is open updates Today within 30 s.
8. Add/Edit validations work (empty name, end ≤ start, no days); overlap hint shows; delete has Undo; duplicate works.
9. Insights week/month numbers match §6.5 for "Load sample routine" data (cross-check against `reference/web` on the **same calendar day**; both use the §6.6a hash and §7.7 demo rules).
10. Reactions Off removes all faces; Quiet removes bubbles only.
11. Airplane mode: everything above still works (no network).
12. Release APK has no `INTERNET` permission (`aapt dump permissions`).

---

## 14. Build plan (do these in order; commit after each)

1. **Scaffold** — `flutter create`, pubspec, fonts, icons, Gradle desugaring, manifest receivers/permissions. ✅ when an empty app builds.
2. **Tokens + theme** — `tokens.dart`, `ThemeData` (Geist, no ripples on cards, custom text theme).
3. **Models + logic + tests** — `models.dart`, `clock.dart`, `logic.dart`, `logic_test.dart` covering §6.7. ✅ tests green.
4. **Store** — persistence, CRUD, logs, undo, templates, demo data, pending-action drain; `store_test.dart`.
5. **Core widgets** — buttons, chips, status node, progress bar, activity icon, toast, switch row, bottom sheet helper.
6. **Buddy + bubble** — painter for 5 moods, idle loops, talk, sparkles, replay rule; a debug gallery screen (debug builds only) showing all moods.
7. **Shell + Today** — nav, ticker, lifecycle, all NOW-card states, timeline, chips.
8. **Sheets** — Check-in, Missed (+ auto prompt), Row menu, Settings (with in-sheet erase confirmation).
9. **Routine + Editor** — grouped list, add/edit/duplicate/delete, validations, time pickers, overlap hint.
10. **Insights** — week/month, delta, highlights, empty state.
11. **Notifications** — scheduling, actions (foreground + background queue), permissions, cold-start launch details, reboot.
12. **Polish & a11y** — semantics, font scale 1.3, reduced motion, back button, edge-to-edge.
13. **Widget smoke test + release build** — `widget_smoke_test.dart`; run the §13 checklist; strip `INTERNET` from release.
14. **Review** — get an independent review (another agent or a human) of the diff against this spec before calling it done; fix every finding or note why not.
