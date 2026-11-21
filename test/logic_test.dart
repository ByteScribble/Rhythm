import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/data/clock.dart';
import 'package:rhythm/data/logic.dart';
import 'package:rhythm/data/models.dart';

/// Sunday 4 Oct 2026.
DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 10, 4, h, m, s);

const today = '2026-10-04';

Activity act(
  String name,
  String start,
  String end, {
  List<int> days = allDays,
  String createdAt = '2026-09-21',
  int? createdMin,
  bool askMissed = true,
  String? id,
}) =>
    Activity(
      id: id ?? name.toLowerCase().replaceAll(' ', '-'),
      name: name,
      icon: 'focus',
      start: start,
      end: end,
      days: days,
      askMissed: askMissed,
      createdAt: createdAt,
      createdMin: createdMin,
    );

/// Both templates, created two weeks ago.
List<Activity> sample() => [
      for (final t in [...templates[Template.morning]!, ...templates[Template.workday]!])
        act(t.name, t.start, t.end, days: t.days),
    ];

LogEntry done([int at = 0]) => LogEntry(status: LogStatus.done, at: at);
LogEntry partial([int amount = 50]) => LogEntry(status: LogStatus.partial, at: 0, amount: amount);
LogEntry skipped() => const LogEntry(status: LogStatus.skipped, at: 0);

void main() {
  final clock = FakeClock(at(6, 23));
  setUp(() => clock.current = at(6, 23));

  group('formatting', () {
    test('12-hour clock', () {
      expect(fmt12(0), '12:00 AM');
      expect(fmt12(360), '6:00 AM');
      expect(fmt12(720), '12:00 PM');
      expect(fmt12(13 * 60 + 5), '1:05 PM');
    });

    test('ranges collapse a shared suffix, across AM/PM they keep both', () {
      expect(fmtRangeMin(360, 420), '6:00 – 7:00 AM');
      expect(fmtRangeMin(11 * 60 + 30, 12 * 60 + 15), '11:30 AM – 12:15 PM');
      expect(fmtRangeMin(13 * 60, 13 * 60 + 45), '1:00 – 1:45 PM');
      expect(fmtRange(act('Yoga', '06:00', '07:00')), '6:00 – 7:00 AM');
    });

    test('durations', () {
      expect(dur(45), '45 min');
      expect(dur(60), '1 hr');
      expect(dur(105), '1 hr 45 min');
    });

    test('repeat labels', () {
      expect(repeatLabel([0, 1, 2, 3, 4, 5, 6]), 'Daily');
      expect(repeatLabel([4, 3, 2, 1, 0]), 'Mon–Fri');
      expect(repeatLabel([5, 6]), 'Weekends');
      expect(repeatLabel([4, 0, 2]), 'Mon, Wed, Fri');
      expect(repeatLabel([6]), 'Sun');
    });

    test('greeting and date header', () {
      expect(greeting(at(4, 59)), 'Good night');
      expect(greeting(at(5, 0)), 'Good morning');
      expect(greeting(at(12, 0)), 'Good afternoon');
      expect(greeting(at(17, 0)), 'Good evening');
      expect(dateHeader(clock.now()), 'Sunday, 4 October');
    });

    test('date helpers', () {
      expect(dateKey(clock.now()), today);
      expect(mon0(clock.now()), 6);
      expect(mon0(DateTime(2026, 9, 28)), 0);
      expect(dateKey(addDays(DateTime(2026, 10, 1, 23, 30), -1)), '2026-09-30');
      expect(parseDateKey('2026-10-04'), DateTime(2026, 10, 4));
      expect(minToHHMM(390), '06:30');
      expect(nowMin(at(6, 23, 30)), 383.5);
    });

    test('stableHash matches the web prototype', () {
      // Values from `hash()` in reference/web/app.js.
      expect(stableHash(''), 0);
      expect(stableHash('a'), 97);
      expect(stableHash('Yoga'), 2761360);
      expect(stableHash('2026-10-03Yoga'), 744947574);
      expect(stableHash('The quick brown fox jumps over the lazy dog'), 609428141);
    });
  });

  group('scheduledOn', () {
    test('needs the weekday and a creation date on or before the day', () {
      final a = act('Deep work', '08:00', '10:00', days: weekdays, createdAt: '2026-09-30');
      expect(scheduledOn(a, DateTime(2026, 10, 4)), isFalse); // Sunday
      expect(scheduledOn(a, DateTime(2026, 10, 1)), isTrue); // Thursday
      expect(scheduledOn(a, DateTime(2026, 9, 30)), isTrue); // creation day
      expect(scheduledOn(a, DateTime(2026, 9, 29)), isFalse); // before creation
    });
  });

  group('status (§6.2)', () {
    final yoga = act('Yoga', '06:00', '07:00');
    ItemStatus st(DateTime now, {LogEntry? log, String? early, Activity? a}) =>
        statusOf(a ?? yoga, log: log, now: now, earlyStartId: early);

    test('1. a log wins over everything', () {
      expect(st(at(6, 23), log: done()), ItemStatus.done);
      expect(st(at(9, 0), log: partial()), ItemStatus.partial);
      expect(st(at(5, 0), log: skipped()), ItemStatus.skipped);
    });

    test('2b. a window moved into the past is na on that day only', () {
      final moved = yoga.copyWith(naDate: today, naMin: 540);
      expect(st(at(9, 0), a: moved), ItemStatus.na);
      expect(st(DateTime(2026, 10, 5, 9, 0), a: moved), ItemStatus.missed);
      // Moved again to later the same day: a normal item.
      final later = moved.copyWith(start: '10:00', end: '11:00');
      expect(st(at(9, 30), a: later), ItemStatus.upcoming);
    });

    test('2. added after the window on its creation day is na', () {
      final late = act('Yoga', '06:00', '07:00', createdAt: today, createdMin: 420);
      expect(st(at(7, 0), a: late), ItemStatus.na);
      expect(st(at(22, 0), a: late), ItemStatus.na);
      // …but a log still wins,
      expect(st(at(22, 0), a: late, log: done()), ItemStatus.done);
      // created mid-window is a normal item,
      final mid = act('Yoga', '06:00', '07:00', createdAt: today, createdMin: 383);
      expect(st(at(6, 23), a: mid), ItemStatus.now);
      expect(st(at(7, 30), a: mid), ItemStatus.missed);
      // and only on the creation day.
      final yesterday = act('Yoga', '06:00', '07:00', createdAt: '2026-10-03', createdMin: 1200);
      expect(st(at(8, 0), a: yesterday), ItemStatus.missed);
    });

    test('3. inside the window is now (start inclusive, end exclusive)', () {
      expect(st(at(6, 0)), ItemStatus.now);
      expect(st(at(6, 59, 59)), ItemStatus.now);
      expect(st(at(7, 0)), ItemStatus.missed);
    });

    test('4. early start makes an upcoming item now', () {
      expect(st(at(5, 30), early: 'yoga'), ItemStatus.now);
      expect(st(at(5, 30), early: 'other'), ItemStatus.upcoming);
      // Early start never revives a window that has ended.
      expect(st(at(7, 30), early: 'yoga'), ItemStatus.missed);
    });

    test('5. before the window is upcoming; 6. after it is missed', () {
      expect(st(at(5, 59, 59)), ItemStatus.upcoming);
      expect(st(at(23, 0)), ItemStatus.missed);
    });

    test("today's list is scheduled items sorted by start, then name", () {
      final items = todayItems(
        activities: [
          act('Walk', '07:00', '07:30'),
          act('Deep work', '08:00', '10:00', days: weekdays),
          act('Yoga', '06:00', '07:00'),
          act('Coffee', '07:00', '07:15'),
        ],
        logs: {},
        now: at(6, 23),
      );
      expect(items.map((i) => i.activity.name), ['Yoga', 'Coffee', 'Walk']);
      expect(items.first.inWindow, isTrue);
      expect(items.first.status, ItemStatus.now);
    });
  });

  group('NOW card (§6.3)', () {
    NowCard card(DateTime now, {Logs logs = const {}, String? early, List<Activity>? acts}) {
      final activities = acts ?? sample();
      return nowCard(
        hasActivities: activities.isNotEmpty,
        items: todayItems(activities: activities, logs: logs, now: now, earlyStartId: early),
        nm: nowMin(now),
      );
    }

    test('no activities → empty; none today → free day', () {
      expect(card(at(6, 23), acts: []).kind, NowCardKind.empty);
      expect(
        card(at(6, 23), acts: [act('Deep work', '08:00', '10:00', days: weekdays)]).kind,
        NowCardKind.freeDay,
      );
    });

    test('06:23 → active Yoga, 37 min remaining', () {
      final c = card(at(6, 23));
      expect(c.kind, NowCardKind.active);
      expect(c.focus!.activity.name, 'Yoga');
      expect(c.focus!.e - nowMin(at(6, 23)), 37);
      expect(c.next!.activity.name, 'Get ready');
    });

    test('07:04 → active Get ready; once logged → resolved with up next', () {
      final c = card(at(7, 4));
      expect(c.kind, NowCardKind.active);
      expect(c.focus!.activity.name, 'Get ready');

      final r = card(at(7, 4), logs: {
        today: {'get-ready': done(424)},
      });
      expect(r.kind, NowCardKind.resolved);
      expect(r.focus!.status, ItemStatus.done);
      expect(r.next!.activity.name, 'Breakfast');
    });

    test('12:20 → free time before Lunch', () {
      final c = card(at(12, 20));
      expect(c.kind, NowCardKind.freeTime);
      expect(c.focus, isNull);
      expect(c.next!.activity.name, 'Lunch');
      expect(c.next!.s - nowMin(at(12, 20)), 40);
    });

    test('23:00 → wrap-up, happy only at ≥ 60 % done or partial', () {
      final meh = card(at(23, 0));
      expect(meh.kind, NowCardKind.wrapUp);
      expect((meh.doneCount, meh.total, meh.good), (0, 8, false));

      final good = card(at(23, 0), logs: {
        today: {
          'wake-up': done(),
          'drink-water': done(),
          'yoga': done(),
          'get-ready': partial(),
          'breakfast': partial(),
          'lunch': skipped(),
        },
      });
      expect((good.doneCount, good.total, good.good), (5, 8, true));
    });

    test('wrap-up total leaves out na items', () {
      final acts = [
        act('Yoga', '06:00', '07:00', createdAt: today, createdMin: 600),
        act('Lunch', '13:00', '13:45', createdAt: today, createdMin: 600),
      ];
      final c = card(at(23, 0), acts: acts, logs: {
        today: {'lunch': done()},
      });
      expect((c.doneCount, c.total, c.good), (1, 1, true));
    });

    test('overlapping windows pick the first in sorted order', () {
      final c = card(at(6, 30), acts: [
        act('Stretch', '06:15', '06:45'),
        act('Yoga', '06:00', '07:00'),
      ]);
      expect(c.focus!.activity.name, 'Yoga');
    });

    test('early start shows the upcoming item as active', () {
      final c = card(at(12, 20), early: 'lunch');
      expect(c.kind, NowCardKind.active);
      expect(c.focus!.activity.name, 'Lunch');
      expect(c.focus!.inWindow, isFalse);
      expect(c.next!.activity.name, 'Reading');
    });

    test('an item finished early is no longer up next', () {
      final logs = {
        today: {'lunch': done(745)},
      };
      final c = card(at(12, 25), logs: logs);
      expect(c.kind, NowCardKind.freeTime);
      expect(c.next!.activity.name, 'Reading');
      // …and with nothing else left, the day wraps up.
      final last = card(at(20, 0), logs: {
        today: {'meditation': done(1200)},
      });
      expect(last.kind, NowCardKind.wrapUp);
    });

    test('tomorrow line', () {
      expect(firstTomorrow(sample(), at(23, 0)), 'Wake up at 5:45 AM');
      expect(
        firstTomorrow([act('Run', '06:00', '07:00', days: [5, 6])], at(23, 0)),
        'a free day',
      );
    });
  });

  group('missed prompt (§6.4)', () {
    TodayItem? prompt(DateTime now, {Logs logs = const {}, Set<String> snoozed = const {}}) =>
        missedPromptCandidate(
          todayItems(activities: sample(), logs: logs, now: now),
          nowMin(now),
          snoozed: snoozed,
        );

    test('asks about the most recently ended missed item', () {
      expect(prompt(at(6, 23))!.activity.name, 'Drink water');
      expect(prompt(at(8, 5))!.activity.name, 'Breakfast');
    });

    test('skips snoozed, logged and askMissed = false items', () {
      expect(prompt(at(8, 5), snoozed: {'breakfast'})!.activity.name, 'Get ready');
      expect(
        prompt(at(8, 5), logs: {
          today: {'breakfast': skipped(), 'get-ready': done()},
        })!
            .activity
            .name,
        'Yoga',
      );
      final quiet = [act('Yoga', '06:00', '07:00', askMissed: false)];
      expect(
        missedPromptCandidate(
          todayItems(activities: quiet, logs: {}, now: at(7, 30)),
          nowMin(at(7, 30)),
        ),
        isNull,
      );
    });

    test('only within 3 hours of the window ending', () {
      // Breakfast ended 08:00: still asked at 10:59, not at 11:00.
      expect(prompt(at(10, 59))!.activity.name, 'Breakfast');
      expect(prompt(at(11, 0)), isNull);
    });

    test('never asks about na or in-progress items', () {
      final acts = [act('Yoga', '06:00', '07:00', createdAt: today, createdMin: 450)];
      expect(
        missedPromptCandidate(
          todayItems(activities: acts, logs: {}, now: at(7, 40)),
          nowMin(at(7, 40)),
        ),
        isNull,
      );
      expect(prompt(at(5, 46)), isNull);
    });
  });

  group('stats (§6.5)', () {
    final yoga = act('Yoga', '06:00', '07:00');
    final reading = act('Reading', '15:00', '15:45');
    final week = DateTime(2026, 9, 28);

    Stats run(List<Activity> acts, Logs logs, {DateTime? now, DateTime? from, DateTime? to}) =>
        computeStats(
          activities: acts,
          logs: logs,
          from: from ?? week,
          to: to ?? addDays(from ?? week, 7),
          now: now ?? at(23, 30),
        );

    test('partial counts as half; shown count is done + partial', () {
      final s = run([yoga], {
        '2026-09-28': {'yoga': done()},
        '2026-09-29': {'yoga': done()},
        '2026-09-30': {'yoga': partial()},
        '2026-10-01': {'yoga': skipped()},
        '2026-10-02': {'yoga': done()},
        // 3rd and 4th: no check-in.
      });
      expect((s.sched, s.done, s.partial), (7, 3, 1));
      expect(s.pct, 50); // (3 + 0.5) / 7
      expect(s.shown, 4);
      expect(s.rows.single.pct, 50);
    });

    test("today's unfinished windows don't count unless logged", () {
      // 06:23 Sunday: Yoga is in progress, Reading hasn't started.
      final early = run([yoga, reading], {}, now: at(6, 23), from: DateTime(2026, 10, 4));
      expect(early.sched, 0);
      expect(early.pct, isNull);

      final logged = run([yoga, reading], {
        today: {'yoga': done()},
      }, now: at(6, 23), from: DateTime(2026, 10, 4));
      expect((logged.sched, logged.pct), (1, 100));

      final later = run([yoga, reading], {}, now: at(7, 0), from: DateTime(2026, 10, 4));
      expect((later.sched, later.pct), (1, 0));
    });

    test('future days and days before creation are ignored', () {
      final fresh = act('Yoga', '06:00', '07:00', createdAt: '2026-10-03');
      final s = run([fresh], {}, now: at(23, 30), to: DateTime(2026, 10, 12));
      expect(s.sched, 2); // 3rd and 4th only
    });

    test('na on the creation day is skipped unless it has a log', () {
      final late = act('Yoga', '06:00', '07:00', createdAt: today, createdMin: 600);
      expect(run([late], {}).sched, 0);
      final s = run([late], {
        today: {'yoga': done()},
      });
      expect((s.sched, s.pct), (1, 100));
    });

    test('logs of deleted activities are ignored', () {
      final logs = {
        '2026-09-28': {'yoga': done(), 'gone': done()},
        '2026-09-29': {'gone': partial()},
      };
      final s = run([yoga], logs, now: DateTime(2026, 9, 29, 23));
      expect((s.sched, s.done, s.partial), (2, 1, 0));
      expect(s.rows.map((r) => r.activity.id), ['yoga']);
    });

    test('week insights: label, delta against the previous week, highlights', () {
      final logs = <String, Map<String, LogEntry>>{
        // previous week (21–27 Sep): Yoga 7/7, Reading 0/7 → 50 %
        for (var d = 21; d <= 27; d++) '2026-09-${pad2(d)}': {'yoga': done()},
        // this week (28 Sep – 4 Oct): Yoga 7/7, Reading 3 done + 1 partial of 7 → 75 %
        '2026-09-28': {'yoga': done(), 'reading': done()},
        '2026-09-29': {'yoga': done(), 'reading': done()},
        '2026-09-30': {'yoga': done(), 'reading': done()},
        '2026-10-01': {'yoga': done(), 'reading': partial()},
        '2026-10-02': {'yoga': done()},
        '2026-10-03': {'yoga': done()},
        '2026-10-04': {'yoga': done()},
      };
      final i = computeInsights(
        activities: [reading, yoga],
        logs: logs,
        now: at(23, 30),
        range: InsightsRange.week,
      );
      expect(i.label, '28 Sep – 4 Oct');
      expect(i.current.pct, 75); // (10 + 0.5) / 14
      expect((i.current.shown, i.current.sched), (11, 14));
      expect(i.delta, 25);
      expect(i.rows.map((r) => (r.activity.name, r.pct)), [('Yoga', 100), ('Reading', 50)]);
      expect(i.best!.activity.name, 'Yoga');
      expect(i.worst!.activity.name, 'Reading');
    });

    test('month insights: calendar month and previous month', () {
      final logs = <String, Map<String, LogEntry>>{
        for (var d = 21; d <= 30; d++) '2026-09-${pad2(d)}': {'yoga': done()}, // Sept 10/10
        '2026-10-01': {'yoga': done()},
        '2026-10-02': {'yoga': partial()}, // Oct: (1 + 0.5) / 4 → 38 %
      };
      final i = computeInsights(
        activities: [yoga],
        logs: logs,
        now: at(23, 30),
        range: InsightsRange.month,
      );
      expect(i.label, 'October 2026');
      expect((i.current.sched, i.current.pct), (4, 38));
      expect(i.delta, 38 - 100);
      expect(i.best, isNull); // needs ≥ 2 activities with data
    });

    test('delta is hidden without previous data; empty without current data', () {
      final fresh = act('Yoga', '06:00', '07:00', createdAt: '2026-10-01');
      final i = computeInsights(
        activities: [fresh],
        logs: {},
        now: at(23, 30),
        range: InsightsRange.week,
      );
      expect(i.delta, isNull);
      expect(i.isEmpty, isFalse);

      final none = computeInsights(
        activities: [act('Yoga', '06:00', '07:00', createdAt: today)],
        logs: {},
        now: at(5, 0),
        range: InsightsRange.week,
      );
      expect(none.isEmpty, isTrue);
    });

    test('ties: most consistent is the earlier start, most missed the later', () {
      final i = computeInsights(
        activities: [reading, yoga],
        logs: {},
        now: at(23, 30),
        range: InsightsRange.week,
      );
      expect(i.best!.activity.name, 'Yoga');
      expect(i.worst!.activity.name, 'Reading');
    });
  });

  group('sample data (§7.7)', () {
    test('is deterministic, covers 13 days and leaves today empty', () {
      final acts = sample();
      final a = demoLogs(acts, at(9, 0)), b = demoLogs(acts, at(21, 0));
      expect(a.keys.toList(), b.keys.toList());
      expect(a.length, demoDays);
      expect(a.containsKey(today), isFalse);
      expect(a.keys.first, '2026-09-21');
      expect(a.keys.last, '2026-10-03');
      for (final k in a.keys) {
        expect(a[k]!.map((id, e) => MapEntry(id, e.status)),
            b[k]!.map((id, e) => MapEntry(id, e.status)));
      }
    });

    test('follows the hash rule', () {
      final acts = sample();
      final logs = demoLogs(acts, at(9, 0));
      final yoga = acts.firstWhere((a) => a.name == 'Yoga');
      for (final key in logs.keys) {
        final x = (stableHash('${key}Yoga') % 100) / 100;
        final entry = logs[key]![yoga.id];
        if (x < .78) {
          expect(entry!.status, LogStatus.done);
          expect(entry.at, 415);
        } else if (x < .86) {
          expect((entry!.status, entry.amount), (LogStatus.partial, 50));
        } else if (x < .94) {
          expect((entry!.status, entry.at), (LogStatus.skipped, 420));
        } else {
          expect(entry, isNull);
        }
      }
      // Weekday-only items never get weekend logs.
      final deep = acts.firstWhere((a) => a.name == 'Deep work');
      expect(logs['2026-10-03']!.containsKey(deep.id), isFalse); // Saturday
    });
  });

  group('parity with the web prototype (§13.9)', () {
    // Expected values come from running reference/web/app.js's own
    // loadDemo() + stats() with its clock fixed at 23:30 on 4 Oct 2026.
    List<(String, int, int, int, int)> rows(Stats s) => [
          for (final r in s.rows) (r.activity.name, r.done, r.partial, r.sched, r.pct),
        ];

    test('week', () {
      final acts = sample();
      final i = computeInsights(
        activities: acts,
        logs: demoLogs(acts, at(23, 30)),
        now: at(23, 30),
        range: InsightsRange.week,
      );
      expect((i.current.sched, i.current.done, i.current.partial, i.current.pct), (71, 45, 2, 65));
      expect(i.delta, 65 - 75);
      expect(rows(i.current), [
        ('Wake up', 4, 0, 7, 57),
        ('Drink water', 5, 0, 7, 71),
        ('Yoga', 5, 0, 7, 71),
        ('Get ready', 6, 0, 7, 86),
        ('Breakfast', 6, 0, 7, 86),
        ('Deep work', 4, 0, 5, 80),
        ('Break', 3, 0, 5, 60),
        ('Study', 5, 0, 5, 100),
        ('Lunch', 2, 2, 7, 43),
        ('Reading', 4, 0, 7, 57),
        ('Meditation', 1, 0, 7, 14),
      ]);
      expect((i.best!.activity.name, i.worst!.activity.name), ('Study', 'Meditation'));
    });

    test('month', () {
      final acts = sample();
      final i = computeInsights(
        activities: acts,
        logs: demoLogs(acts, at(23, 30)),
        now: at(23, 30),
        range: InsightsRange.month,
      );
      expect((i.current.sched, i.current.done, i.current.partial, i.current.pct), (38, 23, 1, 62));
      expect(i.delta, 62 - 73);
      expect(rows(i.current), [
        ('Wake up', 3, 0, 4, 75),
        ('Drink water', 2, 0, 4, 50),
        ('Yoga', 3, 0, 4, 75),
        ('Get ready', 3, 0, 4, 75),
        ('Breakfast', 3, 0, 4, 75),
        ('Deep work', 2, 0, 2, 100),
        ('Break', 1, 0, 2, 50),
        ('Study', 2, 0, 2, 100),
        ('Lunch', 1, 1, 4, 38),
        ('Reading', 2, 0, 4, 50),
        ('Meditation', 1, 0, 4, 25),
      ]);
    });
  });

  group('editor helpers (§7.5)', () {
    test('repeat mode', () {
      expect(repeatMode(allDays), RepeatMode.daily);
      expect(repeatMode(weekdays), RepeatMode.weekdays);
      expect(repeatMode([0, 2, 4]), RepeatMode.custom);
    });

    test('suggested start: end of the latest activity, else next half hour', () {
      expect(suggestStart(sample(), at(6, 23)), '21:15');
      expect(suggestStart([], at(6, 23)), '06:30');
      expect(suggestStart([], at(6, 30)), '06:30');
      expect(suggestStart([], at(23, 50)), '23:30');
      expect(suggestStart([act('Late', '23:00', '23:55')], at(6, 0)), '23:30');
    });

    test('neighbour hint: overlap wins, else what follows', () {
      final acts = sample();
      String hint(String s, String e, [List<int> days = allDays]) => neighbourHint(
          id: null, start: toMin(s), end: toMin(e), days: days, activities: acts);
      expect(hint('05:15', '05:45'), ' · Wake up follows at 5:45 AM');
      expect(hint('07:15', '07:45'), ' · overlaps Get ready');
      // Deep work is Mon–Fri: no overlap on weekends, and what follows is by time.
      expect(hint('08:30', '09:00', [5, 6]), ' · Break follows at 10:00 AM');
      expect(hint('21:15', '21:45'), '');
      // Editing an activity doesn't overlap itself.
      expect(
        neighbourHint(
            id: 'yoga', start: 360, end: 420, days: allDays, activities: acts),
        ' · Get ready follows at 7:00 AM',
      );
    });
  });

  group('bubble lines (§9.7)', () {
    test('are stable for a seed and fill placeholders', () {
      final a = pickLine(LineKind.now, 'yoga$today', {'m': 23, 'r': '37 min', 'n': 'Yoga'});
      final b = pickLine(LineKind.now, 'yoga$today', {'m': 23, 'r': '37 min', 'n': 'Yoga'});
      expect(a, b);
      expect(a.contains('{'), isFalse);
      expect(
        pickLine(LineKind.free, 'x', {'next': 'Lunch', 'in': '40 min'}),
        anyOf('Free time. Breathe — Lunch starts in 40 min.', 'A little gap. Lunch is up in 40 min.'),
      );
      expect(pickLine(LineKind.wrapGood, today, {'d': 6, 't': 8}),
          'That’s a wrap! 6 of 8 done today.');
    });

    test('tone: no guilt', () {
      final all = bubbleLines.values.expand((l) => l).join(' ').toLowerCase();
      for (final banned in ['fail', 'streak', 'lazy', 'shame']) {
        expect(all.contains(banned), isFalse, reason: banned);
      }
    });
  });

  group('notification plan (§10.2)', () {
    List<PlannedNotification> plan(DateTime now, {Logs logs = const {}, List<Activity>? acts}) =>
        planNotifications(activities: acts ?? sample(), logs: logs, enabled: true, now: now);

    test('start, 10-minute and end reminders with the right copy', () {
      final p = plan(at(5, 0), acts: [act('Yoga', '06:00', '07:00')])
          .where((n) => n.date == today)
          .toList();
      expect(p.map((n) => (n.kind, n.at, n.title, n.body)), [
        (NotifKind.start, at(6, 0), 'Yoga starts now', '6:00 – 7:00 AM'),
        (NotifKind.nearEnd, at(6, 50), 'Yoga ends in 10 minutes', 'Wrap up whenever you’re ready.'),
        (NotifKind.end, at(7, 0), 'Did you finish Yoga?', 'One tap keeps your week accurate.'),
      ]);
    });

    test('skips the past, logged activities, short windows and disabled reminders', () {
      // Mid-window: the start reminder is in the past.
      final mid = plan(at(6, 23), acts: [act('Yoga', '06:00', '07:00')])
          .where((n) => n.date == today);
      expect(mid.map((n) => n.kind), [NotifKind.nearEnd, NotifKind.end]);

      // Within 5 s of now is not scheduled.
      final edge = plan(at(5, 59, 57), acts: [act('Yoga', '06:00', '07:00')])
          .where((n) => n.date == today);
      expect(edge.map((n) => n.kind), [NotifKind.nearEnd, NotifKind.end]);

      // Logged today → nothing today, still scheduled tomorrow.
      final logged = plan(at(5, 0), acts: [act('Yoga', '06:00', '07:00')], logs: {
        today: {'yoga': done()},
      });
      expect(logged.any((n) => n.date == today), isFalse);
      expect(logged.where((n) => n.date == '2026-10-05').length, 3);

      // A 10-minute window has no "ends in 10 minutes" reminder.
      final short = plan(at(5, 0), acts: [act('Water', '05:50', '06:00')])
          .where((n) => n.date == today);
      expect(short.map((n) => n.kind), [NotifKind.start, NotifKind.end]);

      expect(
        planNotifications(activities: sample(), logs: {}, enabled: false, now: at(5, 0)),
        isEmpty,
      );
    });

    test('live ids: yesterday and today, unlogged, existing activities only', () {
      final yoga = act('Yoga', '06:00', '07:00');
      final lunch = act('Lunch', '13:00', '13:45');
      final live = liveNotificationIds(
        activities: [yoga, lunch],
        logs: {
          today: {'yoga': done()},
        },
        now: at(9, 0),
      );
      bool has(String id, String date, NotifKind k) => live.contains(notificationId(id, date, k));
      expect(has('yoga', today, NotifKind.start), isFalse); // logged → stale
      expect(has('yoga', '2026-10-03', NotifKind.end), isTrue);
      expect(has('lunch', today, NotifKind.nearEnd), isTrue);
      expect(has('gone', today, NotifKind.end), isFalse); // deleted → stale
      expect(has('lunch', '2026-10-02', NotifKind.end), isFalse); // too old
      expect(live.length, 9);
    });

    test('covers three days, sorted, capped at 60, with stable unique ids', () {
      final p = plan(at(5, 0));
      expect(p.length, maxScheduled);
      expect(p.map((n) => n.date).toSet(), {today, '2026-10-05', '2026-10-06'});
      for (var i = 1; i < p.length; i++) {
        expect(p[i].at.isBefore(p[i - 1].at), isFalse);
      }
      expect(p.map((n) => n.id).toSet().length, p.length);
      expect(p.every((n) => n.id >= 0 && n.id <= 0x7fffffff), isTrue);
      expect(notificationId('yoga', today, NotifKind.end), plan(at(5, 0)).firstWhere((n) {
        return n.actId == 'yoga' && n.date == today && n.kind == NotifKind.end;
      }).id);
    });
  });
}
