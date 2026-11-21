/// Core rules (REQUIREMENTS §6): pure functions, no Flutter imports.
/// Ported from `reference/web/app.js`.
library;

import 'models.dart';

const List<String> dayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday', //
];
const List<String> dayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const List<String> monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

// ---------- time helpers ----------

String pad2(int n) => n < 10 ? '0$n' : '$n';

/// `yyyy-MM-dd` in local time.
String dateKey(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Midnight of the day [n] days after [d] (calendar days, DST-safe).
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

DateTime parseDateKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Weekday with Monday = 0 … Sunday = 6.
int mon0(DateTime d) => (d.weekday + 6) % 7;

int toMin(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String minToHHMM(num m) {
  final v = m.round().clamp(0, 1439);
  return '${pad2(v ~/ 60)}:${pad2(v % 60)}';
}

/// Minutes since local midnight, seconds as a fraction.
double nowMin(DateTime d) => d.hour * 60 + d.minute + d.second / 60;

// ---------- formatting (§6.6) ----------

({String t, String ap}) fmtParts(num minutes) {
  final m = minutes.round() % 1440;
  final h = m ~/ 60;
  return (t: '${h % 12 == 0 ? 12 : h % 12}:${pad2(m % 60)}', ap: h < 12 ? 'AM' : 'PM');
}

/// `6:00 AM`.
String fmt12(num minutes) {
  final p = fmtParts(minutes);
  return '${p.t} ${p.ap}';
}

/// `6:00 – 7:00 AM`, `11:30 AM – 12:15 PM`.
String fmtRangeMin(int start, int end) {
  final s = fmtParts(start), e = fmtParts(end);
  return s.ap == e.ap ? '${s.t} – ${e.t} ${e.ap}' : '${s.t} ${s.ap} – ${e.t} ${e.ap}';
}

String fmtRange(Activity a) => fmtRangeMin(a.startMin, a.endMin);

/// `45 min`, `1 hr`, `1 hr 45 min`.
String dur(num minutes) {
  final mins = minutes.round();
  if (mins < 60) return '$mins min';
  final h = mins ~/ 60, m = mins % 60;
  return m == 0 ? '$h hr' : '$h hr $m min';
}

String repeatLabel(List<int> days) {
  final sorted = [...days]..sort();
  final s = sorted.join();
  if (s == '0123456') return 'Daily';
  if (s == '01234') return 'Mon–Fri';
  if (s == '56') return 'Weekends';
  return sorted.map((i) => dayNames[i].substring(0, 3)).join(', ');
}

String greeting(DateTime d) {
  final h = d.hour;
  if (h < 5) return 'Good night';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// `Sunday, 4 October`.
String dateHeader(DateTime d) => '${dayNames[mon0(d)]}, ${d.day} ${monthNames[d.month - 1]}';

/// Stable across runs and platforms (§6.6a); `String.hashCode` is not.
int stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = ((h * 31 + c) & 0xFFFFFFFF).toSigned(32);
  }
  return h.abs();
}

// ---------- schedule & status (§6.1, §6.2) ----------

bool scheduledOn(Activity a, DateTime d) =>
    a.days.contains(mon0(d)) && dateKey(d).compareTo(a.createdAt) >= 0;

LogEntry? logOf(Logs logs, DateTime d, String id) => logs[dateKey(d)]?[id];

/// True when [a]'s window on the day [key] is "not applicable": it had already
/// ended when the activity was created, or when its times were last moved.
bool notApplicableOn(Activity a, String key) {
  final e = a.endMin;
  if (a.createdAt == key && a.createdMin != null && e <= a.createdMin!) return true;
  return a.naDate == key && a.naMin != null && e <= a.naMin!;
}

int _byStartThenName(Activity a, Activity b) {
  final c = a.startMin.compareTo(b.startMin);
  return c != 0 ? c : a.name.compareTo(b.name);
}

/// [activities] in chronological order (start, then name).
List<Activity> sortedByStart(Iterable<Activity> activities) =>
    activities.toList()..sort(_byStartThenName);

class TodayItem {
  const TodayItem({
    required this.activity,
    required this.status,
    required this.log,
    required this.inWindow,
  });

  final Activity activity;
  final ItemStatus status;
  final LogEntry? log;

  /// `start <= now < end`, whatever the status.
  final bool inWindow;

  int get s => activity.startMin;
  int get e => activity.endMin;

  bool get resolved =>
      status == ItemStatus.done || status == ItemStatus.partial || status == ItemStatus.skipped;
}

ItemStatus _fromLog(LogStatus s) => switch (s) {
      LogStatus.done => ItemStatus.done,
      LogStatus.partial => ItemStatus.partial,
      LogStatus.skipped => ItemStatus.skipped,
    };

/// Status of [a] at [now] (§6.2, evaluated in order).
ItemStatus statusOf(Activity a, {required LogEntry? log, required DateTime now, String? earlyStartId}) {
  if (log != null) return _fromLog(log.status);
  final nm = nowMin(now), s = a.startMin, e = a.endMin;
  if (notApplicableOn(a, dateKey(now))) return ItemStatus.na;
  if (s <= nm && nm < e) return ItemStatus.now;
  if (earlyStartId == a.id && nm < s) return ItemStatus.now;
  if (nm < s) return ItemStatus.upcoming;
  return ItemStatus.missed;
}

/// Activities scheduled on [now]'s day, sorted by start then name.
List<TodayItem> todayItems({
  required List<Activity> activities,
  required Logs logs,
  required DateTime now,
  String? earlyStartId,
}) {
  final nm = nowMin(now);
  return [
    for (final a in sortedByStart(activities.where((a) => scheduledOn(a, now))))
      TodayItem(
        activity: a,
        log: logOf(logs, now, a.id),
        status: statusOf(a, log: logOf(logs, now, a.id), now: now, earlyStartId: earlyStartId),
        inWindow: a.startMin <= nm && nm < a.endMin,
      ),
  ];
}

// ---------- the NOW card (§6.3) ----------

enum NowCardKind { empty, freeDay, active, resolved, freeTime, wrapUp }

class NowCard {
  const NowCard(this.kind, {this.focus, this.next, this.doneCount = 0, this.total = 0});

  final NowCardKind kind;

  /// The item the card is about (active / resolved).
  final TodayItem? focus;

  /// The next item starting later today, if any.
  final TodayItem? next;

  /// Wrap-up: done + partial.
  final int doneCount;

  /// Wrap-up: today's items excluding `na`.
  final int total;

  /// Wrap-up: happy face when at least 60 % were done or partly done.
  bool get good => total > 0 && doneCount / total >= .6;
}

NowCard nowCard({required bool hasActivities, required List<TodayItem> items, required double nm}) {
  if (!hasActivities) return const NowCard(NowCardKind.empty);
  if (items.isEmpty) return const NowCard(NowCardKind.freeDay);
  final focus = items.where((i) => i.inWindow).firstOrNull ??
      items.where((i) => i.status == ItemStatus.now).firstOrNull;
  // An item finished ahead of time (early start) is not "up next" any more.
  final next =
      items.where((i) => i.s > nm && !identical(i, focus) && !i.resolved).firstOrNull;
  if (focus != null) {
    return NowCard(
      focus.status == ItemStatus.now ? NowCardKind.active : NowCardKind.resolved,
      focus: focus,
      next: next,
    );
  }
  if (next != null) return NowCard(NowCardKind.freeTime, next: next);
  return NowCard(
    NowCardKind.wrapUp,
    doneCount:
        items.where((i) => i.status == ItemStatus.done || i.status == ItemStatus.partial).length,
    total: items.where((i) => i.status != ItemStatus.na).length,
  );
}

/// "Yoga at 6:00 AM" or "a free day" — what [now]'s tomorrow starts with.
String firstTomorrow(List<Activity> activities, DateTime now) {
  final t = addDays(now, 1);
  final first = sortedByStart(activities.where((a) => scheduledOn(a, t))).firstOrNull;
  return first == null ? 'a free day' : '${first.name} at ${fmt12(first.startMin)}';
}

// ---------- missed check-in prompt (§6.4) ----------

/// How long after a window ends the app still asks about it, in minutes.
const int missedPromptWindow = 180;
const Duration snoozeDuration = Duration(minutes: 15);

/// The most recently ended missed item worth asking about, if any.
TodayItem? missedPromptCandidate(
  List<TodayItem> items,
  double nm, {
  Set<String> snoozed = const {},
}) {
  TodayItem? best;
  for (final i in items) {
    if (i.status != ItemStatus.missed || !i.activity.askMissed) continue;
    if (nm - i.e >= missedPromptWindow || snoozed.contains(i.activity.id)) continue;
    if (best == null || i.e > best.e) best = i;
  }
  return best;
}

// ---------- stats (§6.5) ----------

class StatRow {
  StatRow(this.activity);

  final Activity activity;
  int sched = 0;
  int done = 0;
  int partial = 0;

  int get pct => sched == 0 ? 0 : ((done + partial * .5) / sched * 100).round();

  /// What the UI shows as "6 / 7".
  int get shown => done + partial;
}

class Stats {
  Stats(this.rows, {required this.sched, required this.done, required this.partial});

  final List<StatRow> rows;
  final int sched;
  final int done;
  final int partial;

  /// Null when nothing has been scheduled (and finished) in the range.
  int? get pct => sched == 0 ? null : ((done + partial * .5) / sched * 100).round();
  int get shown => done + partial;
}

/// Stats for dates in `[from, to)`, up to and including [now]'s day. Only
/// windows that have ended or been logged count.
Stats computeStats({
  required List<Activity> activities,
  required Logs logs,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final per = <String, StatRow>{};
  var sched = 0, done = 0, partial = 0;
  final todayKey = dateKey(now), nm = nowMin(now);
  for (var d = dateOnly(from); d.isBefore(to); d = addDays(d, 1)) {
    if (d.isAfter(now)) break;
    final key = dateKey(d);
    for (final a in activities) {
      if (!scheduledOn(a, d)) continue;
      final log = logs[key]?[a.id];
      if (log == null && key == todayKey && nm < a.endMin) continue; // not over yet
      if (log == null && notApplicableOn(a, key)) continue;
      final row = per.putIfAbsent(a.id, () => StatRow(a));
      row.sched++;
      sched++;
      if (log?.status == LogStatus.done) {
        row.done++;
        done++;
      } else if (log?.status == LogStatus.partial) {
        row.partial++;
        partial++;
      }
    }
  }
  return Stats(per.values.toList(), sched: sched, done: done, partial: partial);
}

enum InsightsRange { week, month }

class Insights {
  const Insights({
    required this.range,
    required this.label,
    required this.current,
    required this.rows,
    this.delta,
    this.best,
    this.worst,
  });

  final InsightsRange range;

  /// "28 Sep – 4 Oct" or "October 2026".
  final String label;
  final Stats current;

  /// Per-activity rows, highest % first (ties: earlier start).
  final List<StatRow> rows;

  /// Current overall % minus the previous period's; null when there is no
  /// previous data.
  final int? delta;

  /// Most consistent / most missed; set only when ≥ 2 activities have data.
  final StatRow? best;
  final StatRow? worst;

  bool get isEmpty => current.pct == null;
}

String _shortDate(DateTime d) => '${d.day} ${monthNames[d.month - 1].substring(0, 3)}';

Insights computeInsights({
  required List<Activity> activities,
  required Logs logs,
  required DateTime now,
  required InsightsRange range,
}) {
  final DateTime from, to, prevFrom;
  final String label;
  if (range == InsightsRange.week) {
    from = addDays(now, -mon0(now));
    to = addDays(from, 7);
    prevFrom = addDays(from, -7);
    label = '${_shortDate(from)} – ${_shortDate(addDays(to, -1))}';
  } else {
    from = DateTime(now.year, now.month);
    to = DateTime(now.year, now.month + 1);
    prevFrom = DateTime(now.year, now.month - 1);
    label = '${monthNames[now.month - 1]} ${now.year}';
  }
  final cur = computeStats(activities: activities, logs: logs, from: from, to: to, now: now);
  final prev = computeStats(activities: activities, logs: logs, from: prevFrom, to: from, now: now);
  final rows = [...cur.rows]..sort((a, b) {
      final c = b.pct.compareTo(a.pct);
      return c != 0 ? c : _byStartThenName(a.activity, b.activity);
    });
  final curPct = cur.pct, prevPct = prev.pct;
  return Insights(
    range: range,
    label: label,
    current: cur,
    rows: rows,
    delta: curPct != null && prevPct != null ? curPct - prevPct : null,
    best: rows.length > 1 ? rows.first : null,
    // Lowest %; on a tie the later one, so it never repeats "most consistent".
    worst: rows.length > 1 ? rows.last : null,
  );
}

// ---------- buddy speech (§9.7) ----------

enum LineKind { now, done, partial, skipped, free, wrapGood, wrapMeh }

const Map<LineKind, List<String>> bubbleLines = {
  LineKind.now: [
    '{m} min in. Keep breathing — you’ve got this.',
    'Nice and steady. {r} to go.',
    'You’re in it. Just this, for now.',
    'Settled in? {r} left — no rush.',
  ],
  LineKind.done: [
    '{n} done! Lovely work.',
    'That’s one for the books. Nicely done.',
    '{n} — complete. You’re on a roll.',
    'Done and dusted. Proud of you.',
  ],
  LineKind.partial: [
    'Some {n} beats none. Proud of you.',
    'Showing up counts. Well done.',
    'A bit is still progress.',
  ],
  LineKind.skipped: [
    'Rest is part of the plan too.',
    'No worries — tomorrow’s a fresh start.',
    'Skipped is fine. Onwards.',
  ],
  LineKind.free: [
    'Free time. Breathe — {next} starts in {in}.',
    'A little gap. {next} is up in {in}.',
  ],
  LineKind.wrapGood: ['That’s a wrap! {d} of {t} done today.'],
  LineKind.wrapMeh: ['Day’s done. {d} of {t} — tomorrow’s a fresh page.'],
};

const String earlyStartLine = 'Starting early? Love that. Tap complete when you’re done.';

final RegExp _placeholder = RegExp(r'\{(\w+)\}');

/// Picks a line deterministically from [seed] so it doesn't flicker between
/// rebuilds, then fills `{placeholders}` from [vars].
String pickLine(LineKind kind, String seed, [Map<String, Object> vars = const {}]) {
  final lines = bubbleLines[kind]!;
  final line = lines[stableHash(seed) % lines.length];
  return line.replaceAllMapped(_placeholder, (m) => '${vars[m[1]] ?? ''}');
}

LineKind lineKindFor(ItemStatus status) => switch (status) {
      ItemStatus.done => LineKind.done,
      ItemStatus.partial => LineKind.partial,
      _ => LineKind.skipped,
    };

// ---------- templates & sample data (§7.7, §7.9) ----------

class TemplateItem {
  const TemplateItem(this.name, this.icon, this.start, this.end, [this.days = allDays]);

  final String name;
  final String icon;
  final String start;
  final String end;
  final List<int> days;
}

enum Template { morning, workday }

const Map<Template, List<TemplateItem>> templates = {
  Template.morning: [
    TemplateItem('Wake up', 'sun', '05:45', '05:50'),
    TemplateItem('Drink water', 'water', '05:50', '06:00'),
    TemplateItem('Yoga', 'yoga', '06:00', '07:00'),
    TemplateItem('Get ready', 'shirt', '07:00', '07:30'),
    TemplateItem('Breakfast', 'coffee', '07:30', '08:00'),
  ],
  Template.workday: [
    TemplateItem('Deep work', 'focus', '08:00', '10:00', weekdays),
    TemplateItem('Break', 'pause', '10:00', '10:15', weekdays),
    TemplateItem('Study', 'book', '10:15', '12:00', weekdays),
    TemplateItem('Lunch', 'bowl', '13:00', '13:45'),
    TemplateItem('Reading', 'bookmark', '15:00', '15:45'),
    TemplateItem('Meditation', 'moon', '21:00', '21:15'),
  ],
};

/// How many days of history "Load sample routine" generates.
const int demoDays = 13;

const Map<String, double> _demoRates = {
  'Yoga': .86,
  'Deep work': .86,
  'Reading': .71,
  'Meditation': .43,
};

/// Deterministic logs for the [demoDays] days before [now]; today gets none.
Logs demoLogs(List<Activity> activities, DateTime now) {
  final Logs logs = {};
  for (var i = demoDays; i >= 1; i--) {
    final d = addDays(now, -i), key = dateKey(d);
    final day = <String, LogEntry>{};
    for (final a in activities) {
      if (!scheduledOn(a, d)) continue;
      final r = _demoRates[a.name] ?? .8;
      final x = (stableHash(key + a.name) % 100) / 100;
      if (x < r - .08) {
        day[a.id] = LogEntry(status: LogStatus.done, at: a.endMin - 5);
      } else if (x < r) {
        day[a.id] = LogEntry(status: LogStatus.partial, at: a.endMin - 5, amount: 50);
      } else if (x < r + .08) {
        day[a.id] = LogEntry(status: LogStatus.skipped, at: a.endMin);
      }
    }
    logs[key] = day;
  }
  return logs;
}

// ---------- editor helpers (§7.5) ----------

enum RepeatMode { daily, weekdays, custom }

RepeatMode repeatMode(List<int> days) {
  final s = ([...days]..sort()).join();
  if (s == '0123456') return RepeatMode.daily;
  if (s == '01234') return RepeatMode.weekdays;
  return RepeatMode.custom;
}

/// Default start for a new activity: the end of the latest one, or the next
/// half hour.
String suggestStart(List<Activity> activities, DateTime now) {
  var latest = -1;
  for (final a in activities) {
    if (a.endMin > latest) latest = a.endMin;
  }
  final m = latest >= 0 ? latest : (nowMin(now) / 30).ceil() * 30;
  return minToHHMM(m > 1410 ? 1410 : m);
}

/// " · overlaps Breakfast", " · Drink water follows at 5:50 AM" or "".
/// Overlap = shares a weekday and the time ranges intersect.
String neighbourHint({
  required String? id,
  required int start,
  required int end,
  required List<int> days,
  required List<Activity> activities,
}) {
  final others = sortedByStart(activities.where((a) => a.id != id));
  for (final a in others) {
    if (a.days.any(days.contains) && a.startMin < end && a.endMin > start) {
      return ' · overlaps ${a.name}';
    }
  }
  final after = others.where((a) => a.startMin >= end).firstOrNull;
  return after == null ? '' : ' · ${after.name} follows at ${fmt12(after.startMin)}';
}

// ---------- notification plan (§10.2) ----------

enum NotifKind { start, nearEnd, end }

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.actId,
    required this.date,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final NotifKind kind;
  final String actId;

  /// `yyyy-MM-dd` of the activity window this is about.
  final String date;

  /// Local fire time.
  final DateTime at;
  final String title;
  final String body;
}

/// The platform keeps a limited number of alarms per app; stay under it.
const int maxScheduled = 60;
const int nearEndLead = 10;

/// Deterministic, positive 31-bit ID.
int notificationId(String actId, String date, NotifKind kind) =>
    stableHash('$actId$date${kind.name}') & 0x7fffffff;

/// IDs of reminders that may still be on screen: those of yesterday's and
/// today's windows of existing activities without a log. A shown notification
/// with any other ID is stale (its activity was logged or deleted).
Set<int> liveNotificationIds({
  required List<Activity> activities,
  required Logs logs,
  required DateTime now,
}) {
  final ids = <int>{};
  for (final day in const [-1, 0]) {
    final d = addDays(now, day), key = dateKey(d);
    for (final a in activities) {
      if (!scheduledOn(a, d) || logs[key]?[a.id] != null) continue;
      for (final kind in NotifKind.values) {
        ids.add(notificationId(a.id, key, kind));
      }
    }
  }
  return ids;
}

/// What to schedule for today and the next two days: the first [maxScheduled]
/// reminders later than `now + 5 s` for activities without a log.
List<PlannedNotification> planNotifications({
  required List<Activity> activities,
  required Logs logs,
  required bool enabled,
  required DateTime now,
}) {
  if (!enabled) return const [];
  final earliest = now.add(const Duration(seconds: 5));
  final out = <PlannedNotification>[];
  for (var day = 0; day < 3; day++) {
    final d = addDays(now, day), key = dateKey(d);
    for (final a in activities) {
      if (!scheduledOn(a, d) || logs[key]?[a.id] != null) continue;
      final s = a.startMin, e = a.endMin, pre = e - nearEndLead;
      void add(NotifKind kind, int minute, String title, String body) {
        final at = DateTime(d.year, d.month, d.day, 0, minute);
        if (!at.isAfter(earliest)) return;
        out.add(PlannedNotification(
          id: notificationId(a.id, key, kind),
          kind: kind,
          actId: a.id,
          date: key,
          at: at,
          title: title,
          body: body,
        ));
      }

      if (a.remindStart) add(NotifKind.start, s, '${a.name} starts now', fmtRange(a));
      if (a.remindEnd && pre > s) {
        add(NotifKind.nearEnd, pre, '${a.name} ends in 10 minutes', 'Wrap up whenever you’re ready.');
      }
      if (a.askMissed) {
        add(NotifKind.end, e, 'Did you finish ${a.name}?', 'One tap keeps your week accurate.');
      }
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out.length > maxScheduled ? out.sublist(0, maxScheduled) : out;
}
