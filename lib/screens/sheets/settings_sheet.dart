import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../services/reminders.dart';
import '../../theme/tokens.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cards.dart';
import '../../widgets/sheet.dart';
import '../../widgets/switch_row.dart';
import '../actions.dart';
import '../buddy_gallery.dart';
import 'row_menu_sheet.dart' show MenuRow;

enum _Result { sample, erase, gallery }

/// Settings: reactions, reminders, sample data, erase.
Future<void> showSettingsSheet(BuildContext context) async {
  final actions = AppActions.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final result = await showAppSheet<_Result>(context, builder: (_) => const _SettingsSheet());
  switch (result) {
    case _Result.sample:
      actions.loadSample();
    case _Result.erase:
      actions.eraseAll();
    case _Result.gallery:
      if (navigator.mounted) {
        unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const BuddyGallery())));
      }
    case null:
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _confirmErase = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final reminders = RemindersScope.of(context);
    final settings = store.settings;
    final denied = reminders.notificationsAllowed == false;
    final showExactHint = settings.notify &&
        !denied &&
        !reminders.exactAllowed &&
        !settings.exactHintDismissed;

    return SheetColumn(
      children: [
        Semantics(
          header: true,
          child: GestureDetector(
            // Debug builds only: long-press the title for the face gallery.
            onLongPress: kDebugMode ? () => Navigator.of(context).pop(_Result.gallery) : null,
            child: Text('Settings', style: AppText.sheetTitle),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Sp.x8,
          children: [
            Text('Reactions', style: AppText.fieldLabel),
            Segmented<Reactions>(
              label: 'Reactions',
              expand: true,
              value: settings.reactions,
              options: const [
                (Reactions.on, 'On'),
                (Reactions.quiet, 'Quiet'),
                (Reactions.off, 'Off'),
              ],
              onChanged: store.setReactions,
            ),
            Text(
              'On: animated face that talks. Quiet: face only. Off: classic icons.',
              style: AppText.meta,
            ),
          ],
        ),
        ListGroup(
          children: [
            SwitchRow(
              title: 'Reminders',
              subtitle: settings.notify && denied
                  ? 'Turn on in system settings'
                  : 'Start, 10 min before end, and check-ins',
              value: settings.notify,
              onChanged: (on) {
                store.setNotify(on);
                if (on) reminders.requestPermission();
              },
            ),
            if (showExactHint)
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.x16, Sp.x12, Sp.x4, Sp.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reminders may arrive a few minutes late.', style: AppText.meta),
                    Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-Sp.x12, 0),
                          child: AppTextButton(
                            label: 'Allow exact alarms',
                            onPressed: reminders.requestExactAlarms,
                          ),
                        ),
                        const Spacer(),
                        AppTextButton(
                          label: 'Dismiss',
                          tone: TextButtonTone.muted,
                          onPressed: () => store
                              .updateSettings(settings.copyWith(exactHintDismissed: true)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (_confirmErase)
          Container(
            padding: const EdgeInsets.all(Sp.x16),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: Rad.groupAll,
              border: Border.all(color: AppColors.dangerSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Sp.x12,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Erase everything? This can’t be undone.',
                    style: AppText.bodyMedium.copyWith(color: AppColors.dangerInk),
                  ),
                ),
                Row(
                  spacing: Sp.x8,
                  children: [
                    AppTextButton(
                      label: 'Keep my data',
                      tone: TextButtonTone.muted,
                      onPressed: () => setState(() => _confirmErase = false),
                    ),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Erase everything',
                        danger: true,
                        onPressed: () => Navigator.of(context).pop(_Result.erase),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          ListGroup(
            children: [
              MenuRow(
                label: 'Load sample routine',
                padding: const EdgeInsets.symmetric(horizontal: Sp.x16),
                onTap: () => Navigator.of(context).pop(_Result.sample),
              ),
              MenuRow(
                label: 'Erase all data',
                danger: true,
                padding: const EdgeInsets.symmetric(horizontal: Sp.x16),
                onTap: () => setState(() => _confirmErase = true),
              ),
            ],
          ),
        Center(
          child: AppTextButton(
            label: 'Done',
            tone: TextButtonTone.muted,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
