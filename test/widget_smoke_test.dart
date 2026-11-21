import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/app.dart';
import 'package:rhythm/data/clock.dart';
import 'package:rhythm/data/logic.dart';
import 'package:rhythm/data/models.dart';
import 'package:rhythm/data/store.dart';
import 'package:rhythm/screens/shell.dart';
import 'package:rhythm/services/reminders.dart';
import 'package:rhythm/widgets/buddy.dart';
import 'package:rhythm/widgets/bubble.dart';

/// Sunday 4 Oct 2026.
DateTime at(int h, int m) => DateTime(2026, 10, 4, h, m);

class Harness {
  Harness(this.tester, {DateTime? now}) : clock = FakeClock(now ?? at(6, 23));

  final WidgetTester tester;
  final FakeClock clock;
  final MemoryStorage storage = MemoryStorage();
  final NoReminders reminders = NoReminders();
  late final AppStore store = AppStore(clock: clock, storage: storage, random: Random(3));

  Future<void> start({bool demo = false, Template? template}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await store.load();
    if (demo) await store.loadDemo();
    if (template != null) await store.addTemplate(template);
    await tester.pumpWidget(RhythmApp(store: store, reminders: reminders));
    await settle();
  }

  /// Lets transitions finish. (Not pumpAndSettle: the faces never stop moving.)
  Future<void> settle() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pump();
    await tester.tap(f.first);
    await settle();
  }

  /// Moves the clock and lets the shell's 30-second ticker fire.
  Future<void> jumpTo(DateTime t) async {
    clock.current = t;
    await tester.pump(Shell.tickInterval);
    await settle();
  }

  /// Unmounts the app and runs out pending timers.
  Future<void> finish() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  ItemStatus status(String name) =>
      store.today.firstWhere((i) => i.activity.name == name).status;
}

void main() {
  testWidgets('empty state → template → active card (§13.2, §13.3)', (tester) async {
    final h = Harness(tester);
    await h.start();

    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Sunday, 4 October'), findsOneWidget);
    expect(find.text('Your day is empty.'), findsOneWidget);

    await h.tap(find.text('Morning routine'));
    expect(find.text('Template added'), findsOneWidget);
    expect(find.text('NOW'), findsOneWidget);
    expect(find.text('6:00 – 7:00 AM'), findsOneWidget);
    expect(find.textContaining('37 min', findRichText: true), findsWidgets);
    expect(find.text('Ends 7:00'), findsOneWidget);
    expect(find.text('Now · 37 min left'), findsOneWidget);
    expect(find.text('Added after this window'), findsNWidgets(2));
    expect(find.text('Upcoming · 30 min'), findsNWidgets(2));
    expect(find.text('0 of 5 done'), findsOneWidget);
    // Nothing was missed, so nothing is asked.
    expect(find.textContaining('Did you complete'), findsNothing);

    await h.finish();
  });

  testWidgets('mark complete, undo, and partial with amount (§13.4, §13.5)', (tester) async {
    final h = Harness(tester);
    await h.start(template: Template.morning);

    await h.tap(find.text('Mark complete'));
    expect(h.status('Yoga'), ItemStatus.done);
    expect(find.text('Nice — Yoga complete'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Logged at 6:23 AM'), findsOneWidget);
    expect(find.text('1 completed'), findsOneWidget);

    // A 30 s tick must not remount the resolved card (no replayed animations).
    final cardFace = find.descendant(of: find.byType(BuddyRow), matching: find.byType(Buddy));
    final faceState = tester.state(cardFace);
    await h.jumpTo(at(6, 24));
    expect(tester.state(cardFace), same(faceState));

    await h.tap(find.text('Undo').first);
    expect(h.status('Yoga'), ItemStatus.now);
    expect(find.text('Mark complete'), findsOneWidget);

    await h.tap(find.text('More'));
    expect(find.text('How did Yoga go?'), findsOneWidget);
    await h.tap(find.text('Partially completed'));
    expect(find.text('Some is better than none — how much?'), findsOneWidget);
    await h.tap(find.text('75%'));
    await tester.enterText(find.byType(TextField), 'Short on time');
    await h.tap(find.text('Save as partial'));

    expect(find.text('How did Yoga go?'), findsNothing);
    expect(find.text('Yoga saved as partial'), findsOneWidget);
    expect(find.text('Partially done · 75%'), findsOneWidget);
    final log = h.store.logFor(h.store.activities.firstWhere((a) => a.name == 'Yoga').id)!;
    expect((log.status, log.amount, log.note), (LogStatus.partial, 75, 'Short on time'));

    await h.finish();
  });

  testWidgets('missed prompt appears on a tick; later snoozes; answer logs (§13.6)', (tester) async {
    final h = Harness(tester);
    await h.start(demo: true);
    // 06:23 with history: Drink water (ended 06:00) is asked about first.
    await tester.pump(const Duration(seconds: 1));
    await h.settle();
    expect(find.text('Did you complete Drink water?'), findsOneWidget);
    await h.tap(find.text('No'));
    expect(h.status('Drink water'), ItemStatus.skipped);
    expect(find.text('Drink water skipped'), findsOneWidget);

    // Next tick: the one before it.
    await h.jumpTo(at(6, 24));
    expect(find.text('Did you complete Wake up?'), findsOneWidget);
    await h.tap(find.text('Ask me later'));
    expect(h.status('Wake up'), ItemStatus.missed);
    await h.jumpTo(at(6, 30));
    expect(find.textContaining('Did you complete'), findsNothing);

    // Yoga's window ends without a check-in → asked within 30 s.
    await h.jumpTo(at(7, 0));
    expect(find.text('Did you complete Yoga?'), findsOneWidget);
    expect(find.textContaining('6:00 – 7:00 AM window ended'), findsOneWidget);
    await h.tap(find.text('Yes, done'));
    expect(h.status('Yoga'), ItemStatus.done);

    // Dismissing by tapping outside counts as "later" too.
    await h.jumpTo(at(7, 31));
    expect(find.text('Did you complete Get ready?'), findsOneWidget);
    await tester.tapAt(const Offset(195, 40));
    await h.settle();
    expect(find.textContaining('Did you complete'), findsNothing);
    await h.jumpTo(at(7, 32));
    // Get ready is snoozed; Wake up's 15 minutes aren't over either… but they
    // are by 06:39+, so Wake up is asked again.
    expect(find.text('Did you complete Wake up?'), findsOneWidget);
    await h.tap(find.text('Partially'));
    expect(find.text('How did Wake up go?'), findsOneWidget);
    await h.tap(find.text('Save as partial'));
    expect(h.status('Wake up'), ItemStatus.partial);

    await h.finish();
  });

  testWidgets('routine: groups, add with validation, duplicate, delete + undo (§13.8)',
      (tester) async {
    final h = Harness(tester, now: at(12, 20));
    await h.start(demo: true);
    // Free time before Lunch.
    expect(find.text('Nothing scheduled right now'), findsOneWidget);
    expect(find.text('Up next · in 40 min'), findsOneWidget);

    await h.tap(find.text('Routine'));
    expect(find.text('11 activities · repeats automatically'), findsOneWidget);
    expect(find.text('MORNING'), findsOneWidget);
    expect(find.text('AFTERNOON'), findsOneWidget);
    expect(find.text('EVENING'), findsOneWidget);
    expect(find.text('Mon–Fri · 2 hr'), findsOneWidget);

    // Add: empty name is rejected, then fixed.
    await h.tap(find.byTooltip('Add activity').last);
    expect(find.text('New activity'), findsOneWidget);
    expect(find.text('9:15 PM'), findsOneWidget); // starts where the day ends
    await h.tap(find.text('Create activity'));
    expect(find.text('Give it a short name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Evening walk');
    await h.settle();
    expect(find.text('Give it a short name'), findsNothing);
    await h.tap(find.text('Custom'));
    await h.tap(find.bySemanticsLabel('Monday'));
    await h.tap(find.bySemanticsLabel('Wednesday'));
    await h.tap(find.bySemanticsLabel('Friday'));
    await h.tap(find.text('Create activity'));
    expect(find.text('Pick at least one day'), findsOneWidget);
    await h.tap(find.text('Daily'));
    await h.tap(find.text('Create activity'));
    expect(find.text('New activity'), findsNothing);
    expect(find.text('Evening walk added'), findsOneWidget);
    expect(h.store.activities.length, 12);
    final walk = h.store.activities.firstWhere((a) => a.name == 'Evening walk');
    expect((walk.start, walk.end, walk.icon), ('21:15', '21:45', 'walk'));

    // Edit shows an overlap hint against Meditation (21:00–21:15)? No: they
    // only touch. Open it and check the plain duration hint.
    await h.tap(find.text('Evening walk'));
    expect(find.text('Edit activity'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    await h.tap(find.text('Cancel'));

    // Duplicate, then delete the copy and undo.
    await h.tap(find.bySemanticsLabel('Options for Yoga'));
    await h.tap(find.text('Duplicate'));
    expect(find.text('Duplicated'), findsOneWidget);
    expect(find.text('Yoga (copy)'), findsOneWidget);
    await h.tap(find.bySemanticsLabel('Options for Yoga (copy)'));
    await h.tap(find.text('Delete'));
    expect(find.text('Yoga (copy) deleted'), findsOneWidget);
    expect(find.text('Yoga (copy)'), findsNothing);
    await h.tap(find.text('Undo'));
    expect(find.text('Yoga (copy)'), findsOneWidget);

    // Back goes to Today first.
    await tester.binding.handlePopRoute();
    await h.settle();
    expect(find.text('Nothing scheduled right now'), findsOneWidget);

    await h.finish();
  });

  testWidgets('insights match the stats rules for sample data (§13.9)', (tester) async {
    final h = Harness(tester, now: at(23, 0));
    await h.start(demo: true);
    // Meditation ended at 21:15 without a check-in, so it is asked about.
    await tester.pump(const Duration(seconds: 1));
    await h.settle();
    expect(find.text('Did you complete Meditation?'), findsOneWidget);
    await h.tap(find.text('Ask me later'));
    expect(find.text('That’s today'), findsOneWidget);
    expect(find.text('Rest well. Tomorrow starts with Wake up at 5:45 AM.'), findsOneWidget);

    await h.tap(find.text('See this week'));
    final week = computeInsights(
      activities: h.store.activities,
      logs: h.store.logs,
      now: h.clock.now(),
      range: InsightsRange.week,
    );
    expect(find.text('28 Sep – 4 Oct'), findsOneWidget);
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('${week.current.pct}%'), findsWidgets);
    expect(
      find.text('Overall completion · ${week.current.shown} of ${week.current.sched}'),
      findsOneWidget,
    );
    expect(find.text('${week.delta!.abs()}% vs last week'), findsOneWidget);
    expect(find.text('Most consistent'), findsOneWidget);
    expect(find.text('Most missed'), findsOneWidget);

    await h.tap(find.text('Month'));
    final month = computeInsights(
      activities: h.store.activities,
      logs: h.store.logs,
      now: h.clock.now(),
      range: InsightsRange.month,
    );
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('THIS MONTH'), findsOneWidget);
    expect(
      find.text('Overall completion · ${month.current.shown} of ${month.current.sched}'),
      findsOneWidget,
    );

    await h.finish();
  });

  testWidgets('settings: reactions quiet/off, sample data, erase with confirmation (§13.10)',
      (tester) async {
    final h = Harness(tester);
    await h.start(template: Template.morning);
    expect(find.byType(Buddy), findsWidgets);
    expect(find.byType(SpeechBubble), findsOneWidget);

    await h.tap(find.byTooltip('Settings'));
    expect(find.text('Settings'), findsOneWidget);
    await h.tap(find.text('Quiet'));
    expect(h.store.reactions, Reactions.quiet);
    await h.tap(find.text('Done'));
    expect(find.byType(SpeechBubble), findsNothing);
    expect(find.byType(Buddy), findsWidgets);

    await h.tap(find.byTooltip('Settings'));
    await h.tap(find.text('Off'));
    await h.tap(find.text('Done'));
    expect(find.byType(Buddy), findsNothing);
    // Sheets fall back to plain icons.
    await h.tap(find.text('More'));
    expect(find.text('How did Yoga go?'), findsOneWidget);
    expect(find.byType(Buddy), findsNothing);
    await h.tap(find.text('Cancel'));

    await h.tap(find.byTooltip('Settings'));
    await h.tap(find.text('Reminders'));
    expect(h.store.settings.notify, isFalse);
    await h.tap(find.text('Load sample routine'));
    expect(find.text('Sample routine loaded'), findsOneWidget);
    expect(h.store.activities.length, 11);
    expect(h.store.logs.length, 13);

    await h.jumpTo(at(6, 24));
    if (find.textContaining('Did you complete').evaluate().isNotEmpty) {
      await h.tap(find.text('Ask me later'));
    }
    await h.tap(find.byTooltip('Settings'));
    await h.tap(find.text('Erase all data'));
    expect(find.text('Erase everything? This can’t be undone.'), findsOneWidget);
    expect(h.store.activities.length, 11); // nothing happens before confirming
    await h.tap(find.text('Keep my data'));
    await h.tap(find.text('Erase all data'));
    await h.tap(find.text('Erase everything'));
    expect(find.text('All data erased'), findsOneWidget);
    expect(h.store.activities, isEmpty);
    expect(find.text('Your day is empty.'), findsOneWidget);

    await h.finish();
  });

  testWidgets('no overflow at 1.3× font scale; reduced motion settles', (tester) async {
    final h = Harness(tester);
    await h.store.load();
    await h.store.loadDemo();
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6; // clamped to 1.3
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(RhythmApp(store: h.store, reminders: h.reminders));
    // With animations disabled nothing loops, so the tree settles.
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2));
    Future<void> tap(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Did you complete Drink water?'), findsOneWidget);
    await tap(find.text('No'));
    expect(find.text('Did you complete Wake up?'), findsNothing); // not before the next tick
    await h.store.logStatus(
        h.store.activities.firstWhere((a) => a.name == 'Wake up').id, LogStatus.done);
    await tester.pumpAndSettle();
    await tap(find.text('More'));
    await tap(find.text('Partially completed'));
    await tap(find.text('Cancel'));
    for (final tab in ['Routine tab', 'Insights tab', 'Today tab']) {
      await tap(find.bySemanticsLabel(tab));
    }
    await tap(find.byTooltip('Add activity').first);
    expect(find.text('New activity'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await h.finish();
  });
}
