import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'clock.dart';
import 'logic.dart';
import 'models.dart';

/// Key of the persisted document. Only the main isolate writes it.
const String dataKey = 'rhythm.v1';

/// Prefix of queued notification actions. The notification background isolate
/// only ever adds keys under this prefix (one key per action, so two isolates
/// never read-modify-write the same value); the main isolate applies and
/// removes them.
const String pendingActionsPrefix = 'rhythm.pendingActions.';

/// Minimal string storage, so tests can run without the platform plugin.
abstract class KeyValueStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);

  /// All entries whose key starts with [prefix].
  Future<Map<String, String>> readPrefix(String prefix);
}

/// `SharedPreferencesAsync`: no in-memory cache, safe across isolates.
class PrefsStorage implements KeyValueStorage {
  PrefsStorage() : _prefs = SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Future<Map<String, String>> readPrefix(String prefix) async {
    final keys = (await _prefs.getKeys()).where((k) => k.startsWith(prefix));
    final out = <String, String>{};
    for (final k in keys) {
      final v = await _prefs.getString(k);
      if (v != null) out[k] = v;
    }
    return out;
  }
}

class MemoryStorage implements KeyValueStorage {
  MemoryStorage([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> readPrefix(String prefix) async => {
        for (final e in values.entries)
          if (e.key.startsWith(prefix)) e.key: e.value,
      };
}

/// A check-in made from a notification action button (§10.4).
class PendingAction {
  const PendingAction({
    required this.actId,
    required this.date,
    required this.status,
    required this.atMinutes,
  });

  final String actId;

  /// `yyyy-MM-dd` of the window the notification was about.
  final String date;
  final LogStatus status;

  /// Minutes since midnight when the button was tapped.
  final int atMinutes;

  String encode() =>
      jsonEncode({'actId': actId, 'date': date, 'action': status.name, 'atMinutes': atMinutes});

  static PendingAction? tryDecode(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final actId = j['actId'], date = j['date'], at = j['atMinutes'];
      final status = LogStatus.values.where((s) => s.name == j['action']).firstOrNull;
      if (actId is! String || date is! String || status == null) return null;
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) return null;
      return PendingAction(
        actId: actId,
        date: date,
        status: status,
        atMinutes: at is num ? at.round() : 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Queues this action; [stamp] (the tap time) orders the queue. Safe to
  /// call from any isolate.
  Future<void> enqueue(KeyValueStorage storage, {required DateTime stamp}) =>
      storage.write('$pendingActionsPrefix${stamp.microsecondsSinceEpoch}-$actId', encode());
}

/// IDs of the notification buttons.
abstract final class NotifAction {
  static const start = 'start';
  static const skip = 'skip';
  static const done = 'done';
  static const partial = 'partial';
}

/// The check-in a notification button stands for, or null when the button
/// isn't a check-in or the payload is unusable. Yes / Complete → done,
/// Partially → partial, No / Skip → skipped; `at` is the tap time.
PendingAction? pendingActionFor({
  required String? actionId,
  required String? payload,
  required DateTime now,
}) {
  final status = switch (actionId) {
    NotifAction.done => LogStatus.done,
    NotifAction.partial => LogStatus.partial,
    NotifAction.skip => LogStatus.skipped,
    _ => null,
  };
  if (status == null || payload == null) return null;
  try {
    final j = jsonDecode(payload);
    if (j is! Map) return null;
    final actId = j['actId'], date = j['date'];
    if (actId is! String || date is! String) return null;
    return PendingAction(
      actId: actId,
      date: date,
      status: status,
      atMinutes: nowMin(now).round(),
    );
  } catch (_) {
    return null;
  }
}

/// Fields of the add/edit form.
class ActivityDraft {
  ActivityDraft({
    this.id,
    this.name = '',
    this.icon = 'walk',
    required this.start,
    required this.end,
    List<int>? days,
    this.remindStart = true,
    this.remindEnd = true,
    this.askMissed = true,
  }) : days = [...(days ?? allDays)];

  factory ActivityDraft.from(Activity a) => ActivityDraft(
        id: a.id,
        name: a.name,
        icon: a.icon,
        start: a.start,
        end: a.end,
        days: a.days,
        remindStart: a.remindStart,
        remindEnd: a.remindEnd,
        askMissed: a.askMissed,
      );

  /// Null for a new activity.
  final String? id;
  String name;
  String icon;
  String start;
  String end;
  List<int> days;
  bool remindStart;
  bool remindEnd;
  bool askMissed;

  bool get isNew => id == null;
  bool get nameValid => name.trim().isNotEmpty;
  bool get timeValid => toMin(end) > toMin(start);
  bool get daysValid => days.isNotEmpty;
  bool get valid => nameValid && timeValid && daysValid;
}

/// App state: the persisted document plus in-memory session state.
class AppStore extends ChangeNotifier {
  AppStore({required this.clock, required this.storage, Random? random})
      : _random = random ?? Random(),
        _today = dateKey(clock.now());

  final Clock clock;
  final KeyValueStorage storage;
  final Random _random;

  AppData _data = AppData();
  String _today;
  String? _earlyStartId;
  final Map<String, DateTime> _snoozedUntil = {};
  Future<void> _writes = Future.value();
  int _revision = 0;

  List<Activity> get activities => _data.activities;
  Logs get logs => _data.logs;
  Settings get settings => _data.settings;
  Reactions get reactions => _data.settings.reactions;

  DateTime get now => clock.now();
  String get todayKey => dateKey(now);
  String? get earlyStartId => _earlyStartId;

  /// Bumps whenever something that affects reminders changes (activities,
  /// logs, settings, the date).
  int get revision => _revision;

  // ---------- derived ----------

  List<TodayItem> get today => todayItems(
        activities: _data.activities,
        logs: _data.logs,
        now: now,
        earlyStartId: _earlyStartId,
      );

  Activity? activity(String id) => _data.activities.where((a) => a.id == id).firstOrNull;

  LogEntry? logFor(String id, {String? date}) => _data.logs[date ?? todayKey]?[id];

  /// The missed item to ask about right now, if any (§6.4).
  TodayItem? get missedPrompt {
    final t = now;
    final snoozed = {
      for (final e in _snoozedUntil.entries)
        if (e.value.isAfter(t)) e.key,
    };
    return missedPromptCandidate(today, nowMin(t), snoozed: snoozed);
  }

  // ---------- lifecycle ----------

  /// Loads the document. Missing or corrupt data starts empty.
  Future<void> load() async {
    try {
      final raw = await storage.read(dataKey);
      _data = raw == null ? AppData() : AppData.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('Rhythm: could not read saved data, starting empty ($e)');
      _data = AppData();
    }
    _today = todayKey;
    _revision++;
    notifyListeners();
  }

  /// Called every 30 s and on resume: re-evaluates "now" and handles the
  /// midnight rollover (§6.6b).
  void tick() {
    final key = todayKey;
    if (key != _today) {
      _today = key;
      _earlyStartId = null;
      _snoozedUntil.clear();
      _revision++;
    }
    notifyListeners();
  }

  /// Waits for queued writes (call on `paused`).
  Future<void> flush() => _writes;

  Future<void> _persist() {
    final snapshot = jsonEncode(_data.toJson());
    return _writes = _writes.then((_) async {
      try {
        await storage.write(dataKey, snapshot);
      } catch (e) {
        debugPrint('Rhythm: save failed ($e)');
      }
    });
  }

  Future<void> _changed() {
    _revision++;
    notifyListeners();
    return _persist();
  }

  String _uid() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    String make() => [for (var i = 0; i < 7; i++) chars[_random.nextInt(36)]].join();
    var id = make();
    while (activity(id) != null) {
      id = make();
    }
    return id;
  }

  // ---------- activities ----------

  /// Creates or updates from the editor. The draft must be valid.
  Future<Activity> saveDraft(ActivityDraft d) async {
    assert(d.valid);
    final t = now, key = dateKey(t), nm = nowMin(t);
    final days = d.days.toSet().toList()..sort();
    final name = d.name.trim();
    final existing = d.id == null ? null : activity(d.id!);
    final Activity saved;
    if (existing == null) {
      saved = Activity(
        id: _uid(),
        name: name,
        icon: d.icon,
        start: d.start,
        end: d.end,
        days: days,
        remindStart: d.remindStart,
        remindEnd: d.remindEnd,
        askMissed: d.askMissed,
        createdAt: key,
        createdMin: nm.round(),
      );
      _data.activities = [..._data.activities, saved];
    } else {
      var edited = existing.copyWith(
        name: name,
        icon: d.icon,
        start: d.start,
        end: d.end,
        days: days,
        remindStart: d.remindStart,
        remindEnd: d.remindEnd,
        askMissed: d.askMissed,
      );
      // Moving a window to a time that has already passed today must not
      // raise an instant "missed" prompt (§6.4).
      final moved = existing.start != edited.start ||
          existing.end != edited.end ||
          existing.days.join() != edited.days.join();
      if (moved && edited.endMin <= nm && logFor(edited.id, date: key) == null) {
        edited = edited.copyWith(naDate: key, naMin: nm.round());
      }
      saved = edited;
      _data.activities = [
        for (final a in _data.activities) a.id == saved.id ? saved : a,
      ];
    }
    await _changed();
    return saved;
  }

  /// Removes the activity; its logs stay. Returns it for Undo.
  Future<Activity?> deleteActivity(String id) async {
    final victim = activity(id);
    if (victim == null) return null;
    _data.activities = _data.activities.where((a) => a.id != id).toList();
    if (_earlyStartId == id) _earlyStartId = null;
    await _changed();
    return victim;
  }

  Future<void> restoreActivity(Activity a) async {
    if (activity(a.id) != null) return;
    _data.activities = [..._data.activities, a];
    await _changed();
  }

  Future<Activity?> duplicateActivity(String id) async {
    final src = activity(id);
    if (src == null) return null;
    const suffix = ' (copy)';
    final base = src.name.length + suffix.length > 40
        ? src.name.substring(0, 40 - suffix.length).trimRight()
        : src.name;
    final t = now;
    final copy = src.copyWith(
      id: _uid(),
      name: '$base$suffix',
      createdAt: dateKey(t),
      createdMin: nowMin(t).round(),
    );
    _data.activities = [..._data.activities, copy];
    await _changed();
    return copy;
  }

  // ---------- check-ins ----------

  /// Sets or clears (null) the log of [id] on [date] (default today).
  Future<void> setLog(String id, LogEntry? entry, {String? date}) async {
    final key = date ?? todayKey;
    final day = {...?_data.logs[key]};
    if (entry == null) {
      day.remove(id);
    } else {
      day[id] = entry;
    }
    if (day.isEmpty) {
      _data.logs.remove(key);
    } else {
      _data.logs[key] = day;
    }
    if (entry != null) {
      if (_earlyStartId == id) _earlyStartId = null;
      _snoozedUntil.remove(id);
    }
    await _changed();
  }

  /// Records a check-in made now. Returns the entry it replaced (for Undo).
  Future<LogEntry?> logStatus(
    String id,
    LogStatus status, {
    int? amount,
    String? note,
    String? date,
  }) async {
    final previous = logFor(id, date: date);
    final partial = status == LogStatus.partial;
    final trimmed = note?.trim() ?? '';
    await setLog(
      id,
      LogEntry(
        status: status,
        at: nowMin(now).round(),
        amount: partial ? (amount ?? 50) : null,
        note: partial && trimmed.isNotEmpty
            ? (trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed)
            : null,
      ),
      date: date,
    );
    return previous;
  }

  void startEarly(String id) {
    _earlyStartId = id;
    notifyListeners();
  }

  /// "Ask me later": don't prompt about [id] for 15 minutes.
  void snooze(String id) {
    _snoozedUntil[id] = now.add(snoozeDuration);
  }

  // ---------- templates, sample data, reset ----------

  List<Activity> _fromTemplate(Template t, {required String createdAt, int? createdMin}) => [
        for (final item in templates[t]!)
          if (!_data.activities.any((a) => a.name == item.name && a.start == item.start))
            Activity(
              id: _uid(),
              name: item.name,
              icon: item.icon,
              start: item.start,
              end: item.end,
              days: [...item.days],
              createdAt: createdAt,
              createdMin: createdMin,
            ),
      ];

  /// Adds a template, skipping items already present (same name + start).
  Future<void> addTemplate(Template t) async {
    final n = now;
    for (final a in _fromTemplate(t, createdAt: dateKey(n), createdMin: nowMin(n).round())) {
      _data.activities = [..._data.activities, a];
    }
    await _changed();
  }

  /// Replaces all data with both templates and two weeks of history (§7.7).
  Future<void> loadDemo() async {
    final n = now;
    final createdAt = dateKey(addDays(n, -demoDays));
    _data.activities = [];
    _data.logs = {};
    for (final t in Template.values) {
      _data.activities = [..._data.activities, ..._fromTemplate(t, createdAt: createdAt)];
    }
    _data.logs = demoLogs(_data.activities, n);
    _earlyStartId = null;
    _snoozedUntil.clear();
    await _changed();
  }

  Future<void> eraseAll() async {
    _data.activities = [];
    _data.logs = {};
    _earlyStartId = null;
    _snoozedUntil.clear();
    await _changed();
  }

  // ---------- settings ----------

  Future<void> updateSettings(Settings s) async {
    _data.settings = s;
    await _changed();
  }

  Future<void> setReactions(Reactions r) => updateSettings(settings.copyWith(reactions: r));

  Future<void> setNotify(bool on) => updateSettings(settings.copyWith(notify: on));

  // ---------- notification actions (§10.4) ----------

  /// Applies check-ins queued by notification buttons, in order, then clears
  /// them. Returns how many were applied.
  Future<int> drainPendingActions() async {
    final Map<String, String> queued;
    try {
      queued = await storage.readPrefix(pendingActionsPrefix);
    } catch (e) {
      debugPrint('Rhythm: could not read queued actions ($e)');
      return 0;
    }
    if (queued.isEmpty) return 0;
    final keys = queued.keys.toList()..sort();
    var applied = 0;
    for (final k in keys) {
      final action = PendingAction.tryDecode(queued[k]!);
      // Unknown activity (deleted since) or junk → drop silently.
      if (action == null || activity(action.actId) == null) continue;
      final day = {...?_data.logs[action.date]};
      day[action.actId] = LogEntry(
        status: action.status,
        at: action.atMinutes,
        amount: action.status == LogStatus.partial ? 50 : null,
      );
      _data.logs[action.date] = day;
      if (_earlyStartId == action.actId) _earlyStartId = null;
      applied++;
    }
    if (applied > 0) await _changed();
    for (final k in keys) {
      try {
        await storage.remove(k);
      } catch (_) {}
    }
    return applied;
  }
}

/// Provides the [AppStore] to the widget tree.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  /// The store; the caller rebuilds whenever it notifies.
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// The store, without subscribing (for callbacks).
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
