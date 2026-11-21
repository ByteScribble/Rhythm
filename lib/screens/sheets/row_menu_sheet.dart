import 'package:flutter/material.dart';

import '../../data/logic.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cards.dart';
import '../../widgets/sheet.dart';
import '../actions.dart';
import '../editor_screen.dart';

enum _Choice { edit, duplicate, delete }

/// Options for one routine row: Edit, Duplicate, Delete.
Future<void> showRowMenu(BuildContext context, String id) async {
  final actions = AppActions.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final activity = actions.store.activity(id);
  if (activity == null) return;
  final choice = await showAppSheet<_Choice>(
    context,
    builder: (_) => _RowMenu(activity: activity),
  );
  switch (choice) {
    case _Choice.edit:
      if (navigator.mounted) await openEditor(navigator.context, id: id);
    case _Choice.duplicate:
      actions.duplicate(id);
    case _Choice.delete:
      actions.delete(id);
    case null:
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    void pick(_Choice c) => Navigator.of(context).pop(c);
    return SheetColumn(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                activity.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sheetTitle,
              ),
            ),
            Text('${fmtRange(activity)} · ${repeatLabel(activity.days)}', style: AppText.secondary),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MenuRow(label: 'Edit', onTap: () => pick(_Choice.edit)),
            const Hairline(),
            MenuRow(label: 'Duplicate', onTap: () => pick(_Choice.duplicate)),
            const Hairline(),
            MenuRow(label: 'Delete', danger: true, onTap: () => pick(_Choice.delete)),
          ],
        ),
        Center(
          child: AppTextButton(
            label: 'Cancel',
            tone: TextButtonTone.muted,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

/// A 52 px text row in a menu or list group.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.padding = const EdgeInsets.symmetric(horizontal: Sp.x4),
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        constraints: const BoxConstraints(minHeight: 52),
        padding: padding,
        alignment: Alignment.centerLeft,
        color: pressed ? AppColors.bg : AppColors.bg.withValues(alpha: 0),
        child: Text(
          label,
          style: AppText.body.copyWith(color: danger ? AppColors.dangerInk : AppColors.text),
        ),
      ),
    );
  }
}
