import 'package:flutter/material.dart';

import '../../data/logic.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../theme/tokens.dart';
import '../../widgets/activity_icon.dart';
import '../../widgets/buddy.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chips.dart';
import '../../widgets/sheet.dart';
import '../actions.dart';
import 'checkin_sheet.dart';

enum _Answer { done, partial, skipped }

/// "Did you complete Yoga?" — asked when a window ended without a check-in.
///
/// Anything short of an answer (Ask me later, swipe down, back, tap outside)
/// snoozes the question for 15 minutes.
Future<void> showMissedSheet(BuildContext context, String id) async {
  final actions = AppActions.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final activity = actions.store.activity(id);
  if (activity == null) return;
  final answer = await showAppSheet<_Answer>(
    context,
    builder: (_) => _MissedSheet(activity: activity),
  );
  switch (answer) {
    case _Answer.done:
      actions.logCheckin(id, LogStatus.done);
    case _Answer.skipped:
      actions.logCheckin(id, LogStatus.skipped);
    case _Answer.partial:
      final saved =
          navigator.mounted && await showCheckinSheet(navigator.context, id, partial: true);
      if (!saved) actions.store.snooze(id);
    case null:
      actions.store.snooze(id);
  }
}

class _MissedSheet extends StatelessWidget {
  const _MissedSheet({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final reactions = StoreScope.of(context).reactions;
    void answer(_Answer a) => Navigator.of(context).pop(a);
    return SheetColumn(
      children: [
        Column(
          spacing: Sp.x12,
          children: [
            if (reactions == Reactions.off)
              IconTile.activity(activity.icon, size: 56, radius: Rad.group)
            else
              Buddy(Mood.missed, size: 72, talk: reactions == Reactions.on),
            Column(
              spacing: 6,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Did you complete ${activity.name}?',
                    textAlign: TextAlign.center,
                    style: AppText.title.copyWith(letterSpacing: 0),
                  ),
                ),
                Text(
                  'The ${fmtRange(activity)} window ended.\nA quick answer keeps your week accurate.',
                  textAlign: TextAlign.center,
                  style: AppText.bodySm.copyWith(color: AppColors.text2),
                ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Sp.x8,
          children: [
            PrimaryButton(
              label: 'Yes, done',
              icon: Icons.check_rounded,
              height: 52,
              onPressed: () => answer(_Answer.done),
            ),
            Row(
              spacing: Sp.x8,
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Partially',
                    icon: const GlyphIcon(Glyph.half, size: 16, color: AppColors.warningInk),
                    height: 52,
                    onPressed: () => answer(_Answer.partial),
                  ),
                ),
                Expanded(
                  child: SecondaryButton(
                    label: 'No',
                    height: 52,
                    onPressed: () => answer(_Answer.skipped),
                  ),
                ),
              ],
            ),
          ],
        ),
        Center(
          child: AppTextButton(
            label: 'Ask me later',
            tone: TextButtonTone.muted,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
