import 'package:flutter/material.dart';

import '../data/logic.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/activity_icon.dart';
import '../widgets/bubble.dart';
import '../widgets/buddy.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/chips.dart';
import '../widgets/progress_bar.dart';
import '../widgets/status_node.dart';
import 'actions.dart';
import 'editor_screen.dart';
import 'sheets/checkin_sheet.dart';
import 'sheets/missed_sheet.dart';
import 'sheets/settings_sheet.dart';

/// The default tab: what's happening now and how today is going.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onOpenRoutine, required this.onOpenInsights});

  final VoidCallback onOpenRoutine;
  final VoidCallback onOpenInsights;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = store.now, nm = nowMin(now), date = dateKey(now);
    final items = store.today;
    final card = nowCard(hasActivities: store.activities.isNotEmpty, items: items, nm: nm);
    final top = MediaQuery.paddingOf(context).top + Sp.x28;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(Sp.screen, top, Sp.screen, 0),
      child: ScreenHeader(
        eyebrow: greeting(now),
        title: 'Today',
        subtitle: dateHeader(now),
        actions: [
          AppIconButton(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onPressed: () => showSettingsSheet(context),
          ),
          AppIconButton(
            icon: Icons.add_rounded,
            label: 'Add activity',
            onPressed: () => openEditor(context),
          ),
        ],
      ),
    );

    if (card.kind == NowCardKind.empty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              art: const _EmptyArt(),
              title: 'Your day is empty.',
              message: 'Add your first activity and we’ll help you stay on track.',
              children: [
                PrimaryButton(
                  label: 'Add activity',
                  icon: Icons.add_rounded,
                  onPressed: () => openEditor(context),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: Sp.x8),
                  child: Column(
                    spacing: Sp.x8,
                    children: [
                      Text('Or start from a template', style: AppText.meta),
                      Wrap(
                        spacing: Sp.x8,
                        runSpacing: Sp.x8,
                        alignment: WrapAlignment.center,
                        children: [
                          PillButton(
                            label: 'Morning routine',
                            onPressed: () => AppActions.of(context).addTemplate(Template.morning),
                          ),
                          PillButton(
                            label: 'Workday',
                            onPressed: () => AppActions.of(context).addTemplate(Template.workday),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final resolved = items.where((i) => i.resolved).length;
    int count(ItemStatus s) => items.where((i) => i.status == s).length;
    final done = count(ItemStatus.done),
        partial = count(ItemStatus.partial),
        missed = count(ItemStatus.missed);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Sp.x32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Sp.x28,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Sp.x12,
              children: [
                // Floor, so the label never runs ahead of the status-bar clock.
                SectionLabel(
                    card.kind == NowCardKind.active ? 'Now' : 'Now · ${fmt12(nm.floor())}'),
                _NowCardView(
                  card: card,
                  now: now,
                  onOpenRoutine: onOpenRoutine,
                  onOpenInsights: onOpenInsights,
                ),
              ],
            ),
          ),
          if (items.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Sp.x8,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.screen),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Expanded(child: SectionLabel('Today')),
                      Text(
                        '$resolved of ${items.length} done',
                        style: AppText.meta.copyWith(fontFeatures: AppText.tabular),
                      ),
                    ],
                  ),
                ),
                if (done + partial + missed > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.screen),
                    child: Wrap(
                      spacing: Sp.x8,
                      runSpacing: Sp.x8,
                      children: [
                        if (done > 0) StatusChip(ChipKind.done, label: '$done completed'),
                        if (partial > 0) StatusChip(ChipKind.partial, label: '$partial partial'),
                        if (missed > 0) StatusChip(ChipKind.missed, label: '$missed to check in'),
                      ],
                    ),
                  ),
                Padding(
                  // Rows have 8 px of their own padding, so content lines up
                  // with the sections above.
                  padding: const EdgeInsets.symmetric(horizontal: Sp.screen - Sp.x8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, item) in items.indexed)
                        _TimelineRow(
                          key: ValueKey('row-${item.activity.id}-${item.status.name}-$date'),
                          item: item,
                          index: index,
                          count: items.length,
                          nm: nm,
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyArt extends StatelessWidget {
  const _EmptyArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 88,
      child: CustomPaint(
        painter: const _DashedCircle(),
        child: Center(
          child: IconTile.activity('sun', size: 56, active: true, radius: Rad.group),
        ),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  const _DashedCircle();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = (Offset.zero & size).deflate(.5);
    const dashes = 44;
    const step = 6.283185307179586 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * step, step * .55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle oldDelegate) => false;
}

// ---------- the NOW card ----------

Mood _moodFor(ItemStatus s) => switch (s) {
      ItemStatus.done => Mood.done,
      ItemStatus.partial => Mood.partial,
      ItemStatus.skipped => Mood.skipped,
      ItemStatus.missed => Mood.missed,
      _ => Mood.now,
    };

ChipKind _chipFor(ItemStatus s) => switch (s) {
      ItemStatus.done => ChipKind.done,
      ItemStatus.partial => ChipKind.partial,
      ItemStatus.skipped => ChipKind.skipped,
      ItemStatus.missed => ChipKind.missed,
      ItemStatus.now => ChipKind.now,
      _ => ChipKind.upcoming,
    };

class _NowCardView extends StatelessWidget {
  const _NowCardView({
    required this.card,
    required this.now,
    required this.onOpenRoutine,
    required this.onOpenInsights,
  });

  final NowCard card;
  final DateTime now;
  final VoidCallback onOpenRoutine;
  final VoidCallback onOpenInsights;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final nm = nowMin(now), date = dateKey(now), weekday = dayNames[mon0(now)];

    Widget titleBlock(String title, String sub, {bool large = false}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
            Text(
              sub,
              style: large ? AppText.bodySm.copyWith(color: AppColors.text2) : AppText.secondary,
            ),
          ],
        );

    switch (card.kind) {
      case NowCardKind.empty:
        return const SizedBox.shrink();

      case NowCardKind.freeDay:
        return NowCardFrame(
          key: ValueKey('free-day-$date'),
          children: [
            BuddyRow(mood: Mood.skipped, size: 52, text: 'Nothing planned for $weekday. Enjoy the day.'),
            titleBlock('A free day', 'No activities repeat on ${weekday}s.'),
            SecondaryButton(label: 'View routine', onPressed: onOpenRoutine),
          ],
        );

      case NowCardKind.active:
        final focus = card.focus!, a = focus.activity;
        final total = focus.e - focus.s;
        final elapsed = (nm - focus.s).clamp(0, total).toDouble();
        final left = (focus.e - nm).clamp(0, total).toDouble();
        final line = focus.inWindow
            ? pickLine(LineKind.now, '${a.id}$date', {
                'm': elapsed.floor() < 1 ? 1 : elapsed.floor(),
                'r': dur(left.ceil()),
                'n': a.name,
              })
            : earlyStartLine;
        final num13 = AppText.meta.copyWith(height: 16 / 13, fontFeatures: AppText.tabular);
        return NowCardFrame(
          key: ValueKey('now-${a.id}-$date'),
          children: [
            BuddyRow(mood: Mood.now, size: 52, text: line),
            Row(
              children: [
                IconTile.activity(a.icon, size: 44, active: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title),
                      Text(
                        fmtRange(a),
                        style: AppText.secondary.copyWith(fontFeatures: AppText.tabular),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (focus.inWindow)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: Sp.x8,
                children: [
                  ProgressBar(value: elapsed / total),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: dur(left.ceil()),
                              style: const TextStyle(
                                  color: AppColors.text, fontWeight: FontWeight.w500),
                            ),
                            const TextSpan(text: ' remaining'),
                          ]),
                          style: num13,
                        ),
                      ),
                      Text('Ends ${fmtParts(focus.e).t}', style: num13),
                    ],
                  ),
                ],
              )
            else
              Text('Scheduled ${fmtRange(a)}', style: num13),
            Row(
              spacing: Sp.x8,
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Mark complete',
                    icon: Icons.check_rounded,
                    onPressed: () => AppActions.of(context).logCheckin(a.id, LogStatus.done),
                  ),
                ),
                SecondaryButton(
                  label: 'More',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onPressed: () => showCheckinSheet(context, a.id),
                ),
              ],
            ),
          ],
        );

      case NowCardKind.resolved:
        final focus = card.focus!, a = focus.activity, st = focus.status, log = focus.log;
        return NowCardFrame(
          key: ValueKey('res-${a.id}-${st.name}-$date'),
          children: [
            BuddyRow(
              mood: _moodFor(st),
              size: 56,
              text: pickLine(lineKindFor(st), '${a.id}$date${st.name}', {'n': a.name}),
              sparkle: st == ItemStatus.done,
            ),
            Row(
              children: [
                Expanded(
                  child: titleBlock(
                    a.name,
                    log != null && log.at > 0 ? 'Logged at ${fmt12(log.at)}' : fmtRange(a),
                  ),
                ),
                const SizedBox(width: Sp.x8),
                StatusChip(_chipFor(st)),
              ],
            ),
            if (card.next != null) ...[
              const Hairline(),
              _UpNextRow(next: card.next!, nm: nm, startEarly: false),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: AppTextButton(
                label: 'Undo',
                onPressed: () => AppActions.of(context).clearCheckin(a.id),
              ),
            ),
          ],
        );

      case NowCardKind.freeTime:
        final next = card.next!;
        final wait = dur((next.s - nm).ceil());
        return NowCardFrame(
          key: ValueKey('free-$date'),
          children: [
            BuddyRow(
              mood: Mood.now,
              size: 52,
              text: pickLine(
                  LineKind.free, '$date${next.activity.id}', {'next': next.activity.name, 'in': wait}),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                const StatusChip(ChipKind.free),
                titleBlock('Nothing scheduled right now', 'Your next activity starts in $wait.',
                    large: true),
              ],
            ),
            const Hairline(),
            _UpNextRow(next: next, nm: nm, startEarly: true),
          ],
        );

      case NowCardKind.wrapUp:
        final good = card.good;
        return NowCardFrame(
          key: ValueKey('wrap-$date-$good'),
          children: [
            BuddyRow(
              mood: good ? Mood.done : Mood.partial,
              size: 56,
              text: pickLine(good ? LineKind.wrapGood : LineKind.wrapMeh, date,
                  {'d': card.doneCount, 't': card.total}),
              sparkle: good,
            ),
            titleBlock(
              'That’s today',
              'Rest well. Tomorrow starts with ${firstTomorrow(store.activities, now)}.',
            ),
            SecondaryButton(label: 'See this week', onPressed: onOpenInsights),
          ],
        );
    }
  }
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({required this.next, required this.nm, required this.startEarly});

  final TodayItem next;
  final double nm;
  final bool startEarly;

  @override
  Widget build(BuildContext context) {
    final a = next.activity;
    return Row(
      children: [
        IconTile.activity(a.icon, size: 40),
        const SizedBox(width: Sp.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Up next · in ${dur((next.s - nm).ceil())}', style: AppText.meta),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: a.name),
                  TextSpan(
                    text: ' · ${fmt12(next.s)}',
                    style: AppText.secondary.copyWith(fontFeatures: AppText.tabular),
                  ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyMedium,
              ),
            ],
          ),
        ),
        if (startEarly) ...[
          const SizedBox(width: Sp.x8),
          SecondaryButton(
            label: 'Start early',
            height: 44,
            compact: true,
            onPressed: () => AppActions.of(context).startEarly(a.id),
          ),
        ],
      ],
    );
  }
}

// ---------- timeline ----------

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    super.key,
    required this.item,
    required this.index,
    required this.count,
    required this.nm,
  });

  final TodayItem item;
  final int index;
  final int count;
  final double nm;

  static const double _timeWidth = 48;
  static const double _nodeWidth = 24;
  static const double _pad = Sp.x8;
  static const double _gap = Sp.x12;

  void _open(BuildContext context) {
    final id = item.activity.id;
    switch (item.status) {
      case ItemStatus.upcoming || ItemStatus.na:
        openEditor(context, id: id);
      case ItemStatus.missed:
        showMissedSheet(context, id);
      default:
        showCheckinSheet(context, id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = item.activity, st = item.status;
    final reactions = StoreScope.of(context).reactions;
    final isNow = st == ItemStatus.now;

    final (String text, Color color) = switch (st) {
      ItemStatus.done => ('Completed', AppColors.successInk),
      ItemStatus.partial => (
          'Partially done${item.log?.amount != null ? ' · ${item.log!.amount}%' : ''}',
          AppColors.warningInk
        ),
      ItemStatus.skipped => ('Skipped', AppColors.text2),
      ItemStatus.missed => ('Missed · no check-in', AppColors.dangerInk),
      ItemStatus.now => (
          item.inWindow ? 'Now · ${dur((item.e - nm).ceil())} left' : 'Now · started early',
          AppColors.primaryPressed
        ),
      ItemStatus.na => ('Added after this window', AppColors.text2),
      ItemStatus.upcoming => (
          '${index > 0 ? 'Upcoming' : 'Up first'} · ${dur(item.e - item.s)}',
          AppColors.text2
        ),
    };
    final muted = item.resolved || st == ItemStatus.na;
    final time = fmtParts(item.s);

    Widget? face;
    if (reactions != Reactions.off) {
      face = switch (st) {
        ItemStatus.done => const PopIn(child: Buddy(Mood.done, size: 28, still: true)),
        ItemStatus.partial => const PopIn(child: Buddy(Mood.partial, size: 28)),
        ItemStatus.skipped => const PopIn(child: Buddy(Mood.skipped, size: 28, still: true)),
        ItemStatus.missed => const PopIn(child: Buddy(Mood.missed, size: 28)),
        _ => null,
      };
    }

    final spoken = switch (st) {
      ItemStatus.done => 'completed',
      ItemStatus.partial => 'partially done',
      ItemStatus.skipped => 'skipped',
      ItemStatus.missed => 'missed, no check-in',
      ItemStatus.now => 'now',
      ItemStatus.na => 'added after this window',
      ItemStatus.upcoming => 'upcoming',
    };

    return Pressable(
      onTap: () => _open(context),
      label: '${a.name}, ${fmt12(item.s)}, $spoken',
      excludeChildSemantics: true,
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.of(context, Motion.base),
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          color: isNow
              ? AppColors.primarySoft
              : pressed
                  ? AppColors.track
                  : AppColors.primarySoft.withValues(alpha: 0),
          borderRadius: Rad.rowAll,
        ),
        child: CustomPaint(
          painter: _Connector(
            x: _pad + _timeWidth + _gap + _nodeWidth / 2,
            first: index == 0,
            last: index == count - 1,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: Sp.x8),
            child: Row(
              children: [
                SizedBox(
                  width: _timeWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time.t,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: AppText.meta.copyWith(height: 16 / 13, fontFeatures: AppText.tabular),
                      ),
                      Text(
                        time.ap,
                        style: AppText.meta.copyWith(fontSize: 11, height: 13 / 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _gap),
                SizedBox(width: _nodeWidth, child: Center(child: StatusNode(st))),
                const SizedBox(width: _gap + Sp.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 1,
                    children: [
                      Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          color: muted ? AppColors.text2 : AppColors.text,
                          fontWeight: isNow ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta.copyWith(
                          color: color,
                          fontWeight: isNow ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (face != null) ...[const SizedBox(width: Sp.x8), face],
                if (st == ItemStatus.missed)
                  Padding(
                    padding: const EdgeInsets.only(left: Sp.x12, right: Sp.x4),
                    child: Text(
                      'Update',
                      style: AppText.secondary
                          .copyWith(color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 2 px line joining timeline nodes: from the first node's centre to the
/// last one's.
class _Connector extends CustomPainter {
  const _Connector({required this.x, required this.first, required this.last});

  final double x;
  final bool first;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    if (first && last) return;
    final mid = size.height / 2;
    canvas.drawRect(
      Rect.fromLTRB(x - 1, first ? mid : 0, x + 1, last ? mid : size.height),
      Paint()..color = AppColors.border,
    );
  }

  @override
  bool shouldRepaint(_Connector old) => old.x != x || old.first != first || old.last != last;
}
