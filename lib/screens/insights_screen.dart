import 'package:flutter/material.dart';

import '../data/logic.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/activity_icon.dart';
import '../widgets/buddy.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/chips.dart';
import '../widgets/progress_bar.dart';

/// How consistent the week or month has been.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  InsightsRange _range = InsightsRange.week;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final faces = store.reactions != Reactions.off;
    final data = computeInsights(
      activities: store.activities,
      logs: store.logs,
      now: store.now,
      range: _range,
    );
    final unit = _range == InsightsRange.week ? 'week' : 'month';
    final top = MediaQuery.paddingOf(context).top + Sp.x28;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(Sp.screen, top, Sp.screen, 0),
      child: ScreenHeader(
        title: 'Insights',
        subtitle: data.label,
        actions: [
          Segmented<InsightsRange>(
            label: 'Range',
            value: _range,
            options: const [(InsightsRange.week, 'Week'), (InsightsRange.month, 'Month')],
            onChanged: (r) => setState(() => _range = r),
          ),
        ],
      ),
    );

    if (data.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              art: faces
                  ? const Buddy(Mood.now, size: 64)
                  : IconTile.activity('focus', size: 56, active: true, radius: Rad.group),
              title: 'Nothing to show yet',
              message: 'Insights appear once your first activity window has passed.',
            ),
          ),
        ],
      );
    }

    final total = data.current, pct = total.pct!, delta = data.delta;
    final best = data.best, worst = data.worst;

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
                SectionLabel('This $unit'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text('$pct%', style: AppText.stat),
                          Text(
                            'Overall completion · ${total.shown} of ${total.sched}',
                            style: AppText.secondary.copyWith(fontFeatures: AppText.tabular),
                          ),
                        ],
                      ),
                    ),
                    if (delta != null)
                      Padding(
                        padding: const EdgeInsets.only(left: Sp.x12, bottom: Sp.x4),
                        child: StatusChip(
                          delta >= 0 ? ChipKind.done : ChipKind.skipped,
                          glyph: delta >= 0 ? Glyph.up : Glyph.down,
                          label: '${delta.abs()}% vs last $unit',
                        ),
                      ),
                  ],
                ),
                ProgressBar(value: pct / 100, height: 8, trackColor: AppColors.border),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Sp.x12,
              children: [
                const SectionLabel('By activity'),
                ListGroup(children: [for (final r in data.rows) _ActivityRow(row: r)]),
              ],
            ),
          ),
          if (best != null && worst != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.screen),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: Sp.x12,
                  children: [
                    Expanded(
                      child: _Highlight(
                        glyph: Glyph.check,
                        glyphBg: AppColors.successSoft,
                        glyphFg: AppColors.successInk,
                        face: faces ? const Buddy(Mood.done, size: 32, still: true) : null,
                        label: 'Most consistent',
                        name: best.activity.name,
                        detail: '${best.pct}% this $unit',
                      ),
                    ),
                    Expanded(
                      child: _Highlight(
                        glyph: Glyph.clock,
                        glyphBg: AppColors.subtle,
                        glyphFg: AppColors.label,
                        face: faces
                            ? Buddy(worst.pct < 50 ? Mood.missed : Mood.partial, size: 32)
                            : null,
                        label: 'Most missed',
                        name: worst.activity.name,
                        detail:
                            '${worst.pct}%${worst.pct < 60 ? ' · try another time?' : ' · still solid'}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.row});

  final StatRow row;

  @override
  Widget build(BuildContext context) {
    final pct = row.pct;
    final value = AppText.secondary.copyWith(height: 22 / 14, fontFeatures: AppText.tabular);
    return Semantics(
      label: '${row.activity.name}, ${row.shown} of ${row.sched}, $pct percent',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    row.activity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMedium,
                  ),
                ),
                const SizedBox(width: Sp.x12),
                Text('${row.shown} / ${row.sched} ', style: value),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.textScalerOf(context).scale(40)),
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.right,
                    style: value.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            // Never red: a low bar is just a lighter blue.
            ProgressBar(
              value: pct / 100,
              height: 6,
              color: pct < 50 ? AppColors.primaryMuted : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.glyph,
    required this.glyphBg,
    required this.glyphFg,
    required this.face,
    required this.label,
    required this.name,
    required this.detail,
  });

  final Glyph glyph;
  final Color glyphBg;
  final Color glyphFg;
  final Widget? face;
  final String label;
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SmallCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Sp.x12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: glyphBg,
                  borderRadius: const BorderRadius.all(Radius.circular(Rad.tileSm)),
                ),
                child: GlyphIcon(glyph, size: 16, color: glyphFg, stroke: 2.25),
              ),
              ?face,
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(label, style: AppText.meta),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.navTitle.copyWith(height: 24 / 17),
              ),
              Text(
                detail,
                style: AppText.meta.copyWith(color: AppColors.label, fontFeatures: AppText.tabular),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
