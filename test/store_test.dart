import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/data/clock.dart';
import 'package:rhythm/data/logic.dart';
import 'package:rhythm/data/models.dart';
import 'package:rhythm/data/store.dart';

/// Sunday 4 Oct 2026.
DateTime at(int h, int m) => DateTime(2026, 10, 4, h, m);
const today = '2026-10-04';

void main() {
  late FakeClock clock;
  late MemoryStorage storage;
  late AppStore store;

  AppStore fresh() => AppStore(clock: clock, storage: storage, random: Random(7));

  setUp(() async {
    clock = FakeClock(at(6, 23));
    storage = MemoryStorage();
    store = fresh();
    await store.load();
  });

  ActivityDraft draft(String name, String start, String end, {List<int>? days}) =>
      ActivityDraft(name: name, start: start, end: end, days: days);

  Activity byName(String name) => store.activities.firstWhere((a) => a.name == name);

  group('persistence', () {
    test('JSON round-trip keeps activities, logs and settings', () async {
      await store.addTemplate(Template.morning);
      final yoga = byName('Yoga');
      await store.logStatus(yoga.id, LogStatus.partial, amount: 75, note: '  half the flow ');
      await store.logStatus(byName('Wake up').id, LogStatus.done);
      await store.setReactions(Reactions.quiet);
      await store.setNotify(false);

      final doc = jsonDecode(storage.values[dataKey]!) as Map<String, dynamic>;
      expect(doc['schema'], 1);
      expect((doc['activities'] as List).length, 5);
      expect(doc['logs'][today][yoga.id],
          {'status': 'partial', 'at': 383, 'amount': 75, 'note': 'half the flow'});
      expect(doc['settings'], {'reactions': 'quiet', 'notify': false});

      final again = fresh();
      await again.load();
      expect(again.activities.map((a) => a.toJson()), store.activities.map((a) => a.toJson()));
      expect(again.logFor(yoga.id)!.toJson(), store.logFor(yoga.id)!.toJson());
      expect(again.logFor(byName('Wake up').id)!.status, LogStatus.done);
      expect(again.settings.reactions, Reactions.quiet);
      expect(again.settings.notify, isFalse);
    });

    test('corrupt or malformed data starts empty and never throws', () async {
      for (final bad in ['{not json', '[]', '"x"', '{"activities": 3, "logs": [], "settings": 1}']) {
        storage.values[dataKey] = bad;
        final s = fresh();
        await s.load();
        expect(s.activities, isEmpty, reason: bad);
        expect(s.settings.reactions, Reactions.on);
        expect(s.settings.notify, isTrue);
      }
    });

    test('unusable entries are dropped, the rest survives', () async {
      storage.values[dataKey] = jsonEncode({
        'activities': [
          {'id': 'a1', 'name': 'Yoga', 'icon': 'yoga', 'start': '06:00', 'end': '07:00', 'days': [0, 6], 'createdAt': '2026-10-01'},
          {'id': 'a2', 'name': 'Backwards', 'start': '07:00', 'end': '06:00', 'days': [0]},
          {'id': 'a3', 'name': 'No days', 'start': '07:00', 'end': '08:00', 'days': []},
          {'id': 'a4', 'name': 'Odd icon', 'icon': '??', 'start': '7:00', 'end': '08:00', 'days': [1]},
          'junk',
        ],
        'logs': {
          today: {'a1': {'status': 'done', 'at': 400}, 'x': {'status': 'missed'}},
          'not-a-date': {'a1': {'status': 'done'}},
        },
      });
      final s = fresh();
      await s.load();
      expect(s.activities.map((a) => a.id), ['a1']);
      expect(s.logs.keys, [today]);
      expect(s.logs[today]!.keys, ['a1']);
    });

    test('every mutation is written before its future completes', () async {
      await store.saveDraft(draft('Walk', '18:00', '18:30'));
      expect(storage.values[dataKey], contains('"Walk"'));
      await store.deleteActivity(byName('Walk').id);
      expect(storage.values[dataKey], isNot(contains('"Walk"')));
    });
  });

  group('activities', () {
    test('create stamps id, creation day and minute', () async {
      final a = await store.saveDraft(draft('  Evening walk ', '18:00', '18:30', days: [4, 0, 2, 0]));
      expect(a.id, matches(RegExp(r'^[0-9a-z]{7}$')));
      expect(a.name, 'Evening walk');
      expect(a.days, [0, 2, 4]);
      expect((a.createdAt, a.createdMin), (today, 383));
      expect((a.remindStart, a.remindEnd, a.askMissed), (true, true, true));
    });

    test('edit keeps identity and creation stamp', () async {
      clock.current = DateTime(2026, 10, 1, 9, 0);
      final a = await store.saveDraft(draft('Walk', '18:00', '18:30'));
      clock.current = at(6, 23);
      final d = ActivityDraft.from(a)
        ..name = 'Long walk'
        ..end = '19:00'
        ..askMissed = false;
      final b = await store.saveDraft(d);
      expect(store.activities.length, 1);
      expect((b.id, b.name, b.end, b.askMissed), (a.id, 'Long walk', '19:00', false));
      expect((b.createdAt, b.createdMin), ('2026-10-01', 540));
      expect(b.naDate, isNull);
    });

    test('moving a window into the past shows it as na today, without a prompt', () async {
      clock.current = DateTime(2026, 9, 28, 9, 0);
      final a = await store.saveDraft(draft('Walk', '18:00', '18:30'));
      await store.logStatus(a.id, LogStatus.done);
      clock.current = at(12, 0);
      expect(store.today.single.status, ItemStatus.upcoming);

      await store.saveDraft(ActivityDraft.from(a)
        ..start = '08:00'
        ..end = '08:30');
      expect(store.today.single.status, ItemStatus.na);
      expect(store.missedPrompt, isNull);
      // History before the edit still counts.
      expect(store.activity(a.id)!.createdAt, '2026-09-28');
      final week = computeStats(
        activities: store.activities,
        logs: store.logs,
        from: DateTime(2026, 9, 28),
        to: DateTime(2026, 10, 5),
        now: clock.now(),
      );
      expect((week.sched, week.done), (6, 1));

      // Tomorrow it is a normal item again.
      clock.current = DateTime(2026, 10, 5, 9, 0);
      store.tick();
      expect(store.today.single.status, ItemStatus.missed);
    });

    test('renaming an already-missed activity leaves it missed', () async {
      clock.current = DateTime(2026, 10, 1, 9, 0);
      final a = await store.saveDraft(draft('Yoga', '06:00', '07:00'));
      clock.current = at(8, 0);
      await store.saveDraft(ActivityDraft.from(a)..name = 'Morning yoga');
      expect(store.today.single.status, ItemStatus.missed);
    });

    test('delete keeps logs, removes it from lists and stats; undo restores', () async {
      await store.loadDemo();
      final yoga = byName('Yoga');
      final before = store.activities.length;
      final logged = store.logs.values.where((d) => d.containsKey(yoga.id)).length;
      expect(logged, greaterThan(0));

      final victim = await store.deleteActivity(yoga.id);
      expect(victim!.id, yoga.id);
      expect(store.activities.length, before - 1);
      expect(store.today.any((i) => i.activity.id == yoga.id), isFalse);
      expect(store.logs.values.where((d) => d.containsKey(yoga.id)).length, logged);
      final stats = computeInsights(
          activities: store.activities, logs: store.logs, now: clock.now(), range: InsightsRange.month);
      expect(stats.rows.any((r) => r.activity.id == yoga.id), isFalse);

      await store.restoreActivity(victim);
      expect(store.activities.length, before);
      expect(store.activity(yoga.id)!.name, 'Yoga');
      expect(await store.deleteActivity('nope'), isNull);
    });

    test('duplicate copies with a new id, name and creation stamp', () async {
      clock.current = DateTime(2026, 10, 1, 9, 0);
      final a = await store.saveDraft(draft('Yoga', '06:00', '07:00', days: [0, 6]));
      clock.current = at(6, 23);
      final c = await store.duplicateActivity(a.id);
      expect(c!.id, isNot(a.id));
      expect((c.name, c.start, c.end), ('Yoga (copy)', '06:00', '07:00'));
      expect(c.days, [0, 6]);
      expect((c.createdAt, c.createdMin), (today, 383));

      final long = await store.saveDraft(draft('x' * 40, '08:00', '09:00'));
      final lc = await store.duplicateActivity(long.id);
      expect(lc!.name.length, 40);
      expect(lc.name.endsWith(' (copy)'), isTrue);
    });
  });

  group('check-ins', () {
    late Activity yoga;
    setUp(() async {
      await store.loadDemo();
      yoga = byName('Yoga');
    });

    test('done → undo restores the active state', () async {
      expect(store.today.firstWhere((i) => i.activity.id == yoga.id).status, ItemStatus.now);
      final previous = await store.logStatus(yoga.id, LogStatus.done);
      expect(previous, isNull);
      final log = store.logFor(yoga.id)!;
      expect((log.status, log.at, log.amount, log.note), (LogStatus.done, 383, null, null));
      expect(store.today.firstWhere((i) => i.activity.id == yoga.id).status, ItemStatus.done);

      await store.setLog(yoga.id, previous);
      expect(store.logFor(yoga.id), isNull);
      expect(store.logs.containsKey(today), isFalse);
      expect(store.today.firstWhere((i) => i.activity.id == yoga.id).status, ItemStatus.now);
    });

    test('changing a check-in returns the previous one so undo can restore it', () async {
      await store.logStatus(yoga.id, LogStatus.partial, amount: 25);
      final previous = await store.logStatus(yoga.id, LogStatus.skipped);
      expect((previous!.status, previous.amount), (LogStatus.partial, 25));
      await store.setLog(yoga.id, previous);
      expect(store.logFor(yoga.id)!.amount, 25);
    });

    test('partial keeps amount and a trimmed note of at most 120 chars', () async {
      await store.logStatus(yoga.id, LogStatus.partial, amount: 75, note: ' ${'n' * 200} ');
      final log = store.logFor(yoga.id)!;
      expect((log.status, log.amount, log.note!.length), (LogStatus.partial, 75, 120));
      await store.logStatus(yoga.id, LogStatus.partial);
      expect((store.logFor(yoga.id)!.amount, store.logFor(yoga.id)!.note), (50, null));
    });

    test('early start is in-memory and ends with a check-in', () async {
      clock.current = at(12, 20);
      final lunch = byName('Lunch');
      store.startEarly(lunch.id);
      expect(store.today.firstWhere((i) => i.activity.id == lunch.id).status, ItemStatus.now);
      await store.logStatus(lunch.id, LogStatus.done);
      expect(store.earlyStartId, isNull);
    });

    test('snooze hides the prompt for 15 minutes', () async {
      clock.current = at(8, 5);
      final first = store.missedPrompt!;
      expect(first.activity.name, 'Breakfast');
      store.snooze(first.activity.id);
      expect(store.missedPrompt!.activity.name, 'Get ready');
      clock.advance(const Duration(minutes: 14));
      expect(store.missedPrompt!.activity.name, 'Get ready');
      clock.advance(const Duration(minutes: 1));
      expect(store.missedPrompt!.activity.name, 'Breakfast');
    });

    test('midnight rollover clears early start and snoozes', () async {
      clock.current = at(12, 20);
      store.startEarly(byName('Lunch').id);
      clock.current = at(23, 59);
      store.snooze(byName('Meditation').id);
      final rev = store.revision;
      var notified = 0;
      store.addListener(() => notified++);

      store.tick();
      expect((store.earlyStartId, store.revision, notified), (byName('Lunch').id, rev, 1));

      clock.current = DateTime(2026, 10, 5, 0, 0, 30);
      store.tick();
      expect(store.earlyStartId, isNull);
      expect(store.revision, rev + 1);
      expect(store.todayKey, '2026-10-05');
      expect(notified, 2);
    });
  });

  group('templates and sample data', () {
    test('adding a template twice does not duplicate', () async {
      await store.addTemplate(Template.morning);
      await store.addTemplate(Template.morning);
      expect(store.activities.length, 5);
      await store.addTemplate(Template.workday);
      expect(store.activities.length, 11);
      expect(byName('Deep work').days, weekdays);
    });

    test('a template added at 06:23 marks ended windows as na (§13.3)', () async {
      await store.addTemplate(Template.morning);
      final st = {for (final i in store.today) i.activity.name: i.status};
      expect(st, {
        'Wake up': ItemStatus.na,
        'Drink water': ItemStatus.na,
        'Yoga': ItemStatus.now,
        'Get ready': ItemStatus.upcoming,
        'Breakfast': ItemStatus.upcoming,
      });
      expect(store.missedPrompt, isNull);
    });

    test('sample routine: both templates, backdated, 13 days of logs, none today', () async {
      await store.saveDraft(draft('Old', '10:00', '11:00'));
      await store.loadDemo();
      expect(store.activities.length, 11);
      expect(store.activities.every((a) => a.createdAt == '2026-09-21' && a.createdMin == null), isTrue);
      expect(store.logs.length, 13);
      expect(store.logs.containsKey(today), isFalse);

      // Deterministic: a second load gives the same statuses per activity name.
      Map<String, String> shape() => {
            for (final d in store.logs.entries)
              for (final e in d.value.entries)
                '${d.key}/${store.activity(e.key)!.name}': e.value.status.name,
          };
      final first = shape();
      await store.loadDemo();
      expect(shape(), first);
    });

    test('erase removes activities and logs but keeps settings', () async {
      await store.loadDemo();
      await store.setReactions(Reactions.off);
      await store.eraseAll();
      expect(store.activities, isEmpty);
      expect(store.logs, isEmpty);
      expect(store.settings.reactions, Reactions.off);
      final again = fresh();
      await again.load();
      expect(again.activities, isEmpty);
    });
  });

  group('notification actions (§10.4)', () {
    late Activity yoga;
    setUp(() async {
      await store.loadDemo();
      yoga = byName('Yoga');
    });

    Future<void> queue(String actId, LogStatus s, {String date = today, int at = 425, int n = 0}) =>
        PendingAction(actId: actId, date: date, status: s, atMinutes: at)
            .enqueue(storage, stamp: DateTime(2026, 10, 4, 7, 5, n));

    test('queued actions are applied in order, then cleared', () async {
      await queue(yoga.id, LogStatus.skipped, n: 1);
      await queue(yoga.id, LogStatus.done, n: 2);
      await queue(byName('Breakfast').id, LogStatus.partial, at: 481, n: 3);

      expect(await store.drainPendingActions(), 3);
      expect((store.logFor(yoga.id)!.status, store.logFor(yoga.id)!.at), (LogStatus.done, 425));
      final b = store.logFor(byName('Breakfast').id)!;
      expect((b.status, b.amount, b.at), (LogStatus.partial, 50, 481));
      expect(await storage.readPrefix(pendingActionsPrefix), isEmpty);
      expect(storage.values[dataKey], contains('"at":425'));
      expect(await store.drainPendingActions(), 0);
    });

    test('an action for an earlier date is logged under that date', () async {
      clock.current = DateTime(2026, 10, 5, 0, 10);
      store.tick();
      await queue(byName('Meditation').id, LogStatus.done, at: 5);
      await store.drainPendingActions();
      expect(store.logFor(byName('Meditation').id, date: today)!.status, LogStatus.done);
      expect(store.logFor(byName('Meditation').id), isNull);
    });

    test('buttons map to check-ins; other buttons and bad payloads do not', () {
      final now = DateTime(2026, 10, 4, 7, 5, 20);
      PendingAction? map(String? action, [String? payload]) => pendingActionFor(
          actionId: action,
          payload: payload ?? '{"actId":"abc","date":"2026-10-04","kind":"end","at":1}',
          now: now);
      final yes = map(NotifAction.done)!;
      expect((yes.actId, yes.date, yes.status, yes.atMinutes), ('abc', today, LogStatus.done, 425));
      expect(map(NotifAction.partial)!.status, LogStatus.partial);
      expect(map(NotifAction.skip)!.status, LogStatus.skipped);
      expect(map(NotifAction.start), isNull); // opens the app instead
      expect(map(null), isNull); // body tap
      expect(map(NotifAction.done, '{oops'), isNull);
      expect(map(NotifAction.done, '{"date":"2026-10-04"}'), isNull);
      // Round-trips through the queue format.
      final again = PendingAction.tryDecode(yes.encode())!;
      expect((again.actId, again.date, again.status, again.atMinutes),
          (yes.actId, yes.date, yes.status, yes.atMinutes));
    });

    test('unknown activities and junk are dropped silently', () async {
      await queue('deleted', LogStatus.done);
      storage.values['${pendingActionsPrefix}junk'] = '{oops';
      final rev = store.revision;
      expect(await store.drainPendingActions(), 0);
      expect(store.revision, rev);
      expect(await storage.readPrefix(pendingActionsPrefix), isEmpty);
    });
  });
}
