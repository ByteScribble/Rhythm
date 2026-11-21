import 'package:flutter/material.dart';

import '../data/logic.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/activity_icon.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import 'editor_screen.dart';
import 'sheets/row_menu_sheet.dart';

/// Every activity, grouped by time of day. Always chronological.
class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  static const _groups = [
    ('Morning', 0, 720),
    ('Afternoon', 720, 1020),
    ('Evening', 1020, 1440),
  ];

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final acts = sortedByStart(store.activities);
    final n = acts.length;
    final top = MediaQuery.paddingOf(context).top + Sp.x28;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(Sp.screen, top, Sp.screen, 0),
      child: ScreenHeader(
        title: 'Routine',
        subtitle: n == 0
            ? 'Build the shape of your day'
            : '$n ${n == 1 ? 'activity' : 'activities'} · repeats automatically',
        actions: [
          AppIconButton(
            icon: Icons.add_rounded,
            label: 'Add activity',
            onPressed: () => openEditor(context),
          ),
        ],
      ),
    );

    if (acts.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              art: IconTile.activity('focus', size: 56, active: true, radius: Rad.group),
              title: 'No routines yet',
              message: 'Activities you add here repeat on the days you choose.',
              children: [
                PrimaryButton(label: 'Add activity', onPressed: () => openEditor(context)),
              ],
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Sp.x32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Sp.x28,
        children: [
          header,
          for (final (name, from, to) in _groups)
            if (acts.any((a) => a.startMin >= from && a.startMin < to))
              _Group(
                name: name,
                activities: [
                  for (final a in acts)
                    if (a.startMin >= from && a.startMin < to) a,
                ],
              ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.name, required this.activities});

  final String name;
  final List<Activity> activities;

  @override
  Widget build(BuildContext context) {
    final n = activities.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Sp.x8,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: SectionLabel(name)),
                Text('$n ${n == 1 ? 'activity' : 'activities'}', style: AppText.meta),
              ],
            ),
          ),
          ListGroup(children: [for (final a in activities) _RoutineRow(activity: a)]),
        ],
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final start = fmt12(a.startMin);
    final detail = '${repeatLabel(a.days)} · ${dur(a.endMin - a.startMin)}';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.only(left: Sp.x16, right: Sp.x4),
        child: Row(
          children: [
            Expanded(
              child: Pressable(
                onTap: () => openEditor(context, id: a.id),
                label: '${a.name}, $start, $detail',
                excludeChildSemantics: true,
                builder: (context, pressed) => AnimatedOpacity(
                  duration: Motion.of(context, Motion.fast),
                  opacity: pressed ? .6 : 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Row(
                      children: [
                        SizedBox(
                          width: MediaQuery.textScalerOf(context).scale(72),
                          child: Text(
                            start,
                            maxLines: 1,
                            softWrap: false,
                            style: AppText.secondary.copyWith(fontFeatures: AppText.tabular),
                          ),
                        ),
                        const SizedBox(width: Sp.x8),
                        IconTile.activity(a.icon, size: 36),
                        const SizedBox(width: Sp.x12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(a.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
                              Text(detail,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            GhostIconButton(
              icon: Icons.more_vert_rounded,
              label: 'Options for ${a.name}',
              onPressed: () => showRowMenu(context, a.id),
            ),
          ],
        ),
      ),
    );
  }
}
