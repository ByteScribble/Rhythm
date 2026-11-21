/// Data model and JSON (REQUIREMENTS §5). Pure Dart.
library;

/// A stored check-in outcome. "missed" is never stored; it is derived.
enum LogStatus { done, partial, skipped }

/// Derived status of an activity on a given day (§6.2).
enum ItemStatus { done, partial, skipped, na, now, upcoming, missed }

enum Reactions { on, quiet, off }

const int schemaVersion = 1;
const List<int> allDays = [0, 1, 2, 3, 4, 5, 6];
const List<int> weekdays = [0, 1, 2, 3, 4];

/// Keys of the selectable activity icons, in grid order (§9.6).
const List<String> iconKeys = [
  'sun', 'water', 'yoga', 'shirt', 'coffee', 'focus', //
  'pause', 'book', 'bowl', 'bookmark', 'moon', 'walk',
];

int _hhmmToMin(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

final RegExp _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
final RegExp _dateKey = RegExp(r'^\d{4}-\d{2}-\d{2}$');

class Activity {
  const Activity({
    required this.id,
    required this.name,
    required this.icon,
    required this.start,
    required this.end,
    required this.days,
    this.remindStart = true,
    this.remindEnd = true,
    this.askMissed = true,
    required this.createdAt,
    this.createdMin,
    this.naDate,
    this.naMin,
  });

  final String id;
  final String name;
  final String icon;

  /// `HH:mm`, 24 h.
  final String start;

  /// `HH:mm`, 24 h; after [start], same day.
  final String end;

  /// 0 = Monday … 6 = Sunday; non-empty.
  final List<int> days;
  final bool remindStart;

  /// 10 minutes before the end.
  final bool remindEnd;

  /// Check-in when the window ends.
  final bool askMissed;

  /// `yyyy-MM-dd`, local.
  final String createdAt;

  /// Minutes since midnight at creation.
  final int? createdMin;

  /// Set when an edit moves the window to a time that has already passed that
  /// day: on [naDate], a window ending at or before [naMin] is "not
  /// applicable" (no prompt, not counted). Kept apart from [createdAt] so the
  /// edit doesn't hide the activity's earlier history.
  final String? naDate;
  final int? naMin;

  int get startMin => _hhmmToMin(start);
  int get endMin => _hhmmToMin(end);

  Activity copyWith({
    String? id,
    String? name,
    String? icon,
    String? start,
    String? end,
    List<int>? days,
    bool? remindStart,
    bool? remindEnd,
    bool? askMissed,
    String? createdAt,
    int? createdMin,
    bool clearCreatedMin = false,
    String? naDate,
    int? naMin,
  }) =>
      Activity(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        start: start ?? this.start,
        end: end ?? this.end,
        days: days ?? this.days,
        remindStart: remindStart ?? this.remindStart,
        remindEnd: remindEnd ?? this.remindEnd,
        askMissed: askMissed ?? this.askMissed,
        createdAt: createdAt ?? this.createdAt,
        createdMin: clearCreatedMin ? null : (createdMin ?? this.createdMin),
        naDate: naDate ?? this.naDate,
        naMin: naMin ?? this.naMin,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'start': start,
        'end': end,
        'days': days,
        'remindStart': remindStart,
        'remindEnd': remindEnd,
        'askMissed': askMissed,
        'createdAt': createdAt,
        'createdMin': ?createdMin,
        'naDate': ?naDate,
        'naMin': ?naMin,
      };

  /// Returns null when [json] is not a usable activity.
  static Activity? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'], start = json['start'], end = json['end'];
    if (id is! String || id.isEmpty || name is! String || name.trim().isEmpty) return null;
    if (start is! String || end is! String || !_hhmm.hasMatch(start) || !_hhmm.hasMatch(end)) {
      return null;
    }
    if (_hhmmToMin(end) <= _hhmmToMin(start)) return null;
    final rawDays = json['days'];
    final days = <int>{
      if (rawDays is List)
        for (final d in rawDays)
          if (d is int && d >= 0 && d <= 6) d,
    }.toList()
      ..sort();
    if (days.isEmpty) return null;
    final icon = json['icon'];
    final createdAt = json['createdAt'];
    final createdMin = json['createdMin'];
    final naDate = json['naDate'], naMin = json['naMin'];
    final hasNa = naDate is String && _dateKey.hasMatch(naDate) && naMin is num;
    return Activity(
      id: id,
      name: name.trim(),
      icon: icon is String && iconKeys.contains(icon) ? icon : 'focus',
      start: start,
      end: end,
      days: days,
      remindStart: json['remindStart'] != false,
      remindEnd: json['remindEnd'] != false,
      askMissed: json['askMissed'] != false,
      createdAt: createdAt is String && _dateKey.hasMatch(createdAt) ? createdAt : '1970-01-01',
      createdMin: createdMin is num ? createdMin.round() : null,
      naDate: hasNa ? naDate : null,
      naMin: hasNa ? naMin.round() : null,
    );
  }
}

class LogEntry {
  const LogEntry({required this.status, required this.at, this.amount, this.note});

  final LogStatus status;

  /// Minutes since midnight when the check-in was made.
  final int at;

  /// 25 / 50 / 75; only for [LogStatus.partial].
  final int? amount;

  /// ≤ 120 chars; only for [LogStatus.partial].
  final String? note;

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'at': at,
        'amount': ?amount,
        'note': ?note,
      };

  static LogEntry? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final status = LogStatus.values.where((s) => s.name == json['status']).firstOrNull;
    if (status == null) return null;
    final at = json['at'], amount = json['amount'], note = json['note'];
    final partial = status == LogStatus.partial;
    return LogEntry(
      status: status,
      at: at is num ? at.round() : 0,
      amount: partial && amount is num ? amount.round() : null,
      note: partial && note is String && note.isNotEmpty ? note : null,
    );
  }
}

class Settings {
  const Settings({
    this.reactions = Reactions.on,
    this.notify = true,
    this.askedNotifyPermission = false,
    this.exactHintDismissed = false,
  });

  final Reactions reactions;

  /// Master switch for reminders.
  final bool notify;

  /// The one-time POST_NOTIFICATIONS request has been made (§10.5).
  final bool askedNotifyPermission;

  /// The "reminders may arrive late" hint was dismissed (§10.5).
  final bool exactHintDismissed;

  Settings copyWith({
    Reactions? reactions,
    bool? notify,
    bool? askedNotifyPermission,
    bool? exactHintDismissed,
  }) =>
      Settings(
        reactions: reactions ?? this.reactions,
        notify: notify ?? this.notify,
        askedNotifyPermission: askedNotifyPermission ?? this.askedNotifyPermission,
        exactHintDismissed: exactHintDismissed ?? this.exactHintDismissed,
      );

  Map<String, dynamic> toJson() => {
        'reactions': reactions.name,
        'notify': notify,
        if (askedNotifyPermission) 'askedNotifyPermission': true,
        if (exactHintDismissed) 'exactHintDismissed': true,
      };

  static Settings fromJson(Object? json) {
    if (json is! Map) return const Settings();
    return Settings(
      reactions:
          Reactions.values.where((r) => r.name == json['reactions']).firstOrNull ?? Reactions.on,
      notify: json['notify'] != false,
      askedNotifyPermission: json['askedNotifyPermission'] == true,
      exactHintDismissed: json['exactHintDismissed'] == true,
    );
  }
}

/// `dateKey → activityId → entry`.
typedef Logs = Map<String, Map<String, LogEntry>>;

/// The whole persisted document (key `rhythm.v1`).
class AppData {
  AppData({List<Activity>? activities, Logs? logs, this.settings = const Settings()})
      : activities = activities ?? [],
        logs = logs ?? {};

  List<Activity> activities;
  Logs logs;
  Settings settings;

  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        'activities': [for (final a in activities) a.toJson()],
        'logs': {
          for (final day in logs.entries)
            if (day.value.isNotEmpty)
              day.key: {for (final e in day.value.entries) e.key: e.value.toJson()},
        },
        'settings': settings.toJson(),
      };

  /// Tolerant of missing or malformed parts: anything unusable is dropped.
  static AppData fromJson(Object? json) {
    if (json is! Map) return AppData();
    final acts = <Activity>[];
    final seen = <String>{};
    final rawActs = json['activities'];
    if (rawActs is List) {
      for (final raw in rawActs) {
        final a = Activity.tryFromJson(raw);
        if (a != null && seen.add(a.id)) acts.add(a);
      }
    }
    final Logs logs = {};
    final rawLogs = json['logs'];
    if (rawLogs is Map) {
      for (final day in rawLogs.entries) {
        final key = day.key, value = day.value;
        if (key is! String || !_dateKey.hasMatch(key) || value is! Map) continue;
        final entries = <String, LogEntry>{};
        for (final e in value.entries) {
          final entry = LogEntry.tryFromJson(e.value);
          if (e.key is String && entry != null) entries[e.key as String] = entry;
        }
        if (entries.isNotEmpty) logs[key] = entries;
      }
    }
    return AppData(activities: acts, logs: logs, settings: Settings.fromJson(json['settings']));
  }
}
