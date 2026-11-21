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

class _CheckinResult {
  const _CheckinResult.log(LogStatus this.status, {this.amount, this.note});
  const _CheckinResult.clear()
      : status = null,
        amount = null,
        note = null;

  /// Null = clear the check-in.
  final LogStatus? status;
  final int? amount;
  final String? note;
}

/// "How did Yoga go?" — Completed / Partially completed / Skipped.
///
/// [date] defaults to today; [partial] opens straight in partial mode.
/// Returns true when a check-in was saved or cleared.
Future<bool> showCheckinSheet(
  BuildContext context,
  String id, {
  String? date,
  bool partial = false,
}) async {
  final actions = AppActions.of(context);
  final activity = actions.store.activity(id);
  if (activity == null) return false;
  final result = await showAppSheet<_CheckinResult>(
    context,
    builder: (_) => _CheckinSheet(
      activity: activity,
      log: actions.store.logFor(id, date: date),
      startPartial: partial,
    ),
  );
  if (result == null) return false;
  final status = result.status;
  if (status == null) {
    actions.clearCheckin(id, date: date);
  } else {
    actions.logCheckin(id, status, amount: result.amount, note: result.note, date: date);
  }
  return true;
}

class _CheckinSheet extends StatefulWidget {
  const _CheckinSheet({required this.activity, required this.log, required this.startPartial});

  final Activity activity;
  final LogEntry? log;
  final bool startPartial;

  @override
  State<_CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends State<_CheckinSheet> {
  late bool _partial = widget.startPartial;
  late int _amount = widget.log?.amount ?? 50;
  late final TextEditingController _note = TextEditingController(text: widget.log?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _finish(_CheckinResult r) => Navigator.of(context).pop(r);

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final reactions = StoreScope.of(context).reactions;
    final faces = reactions != Reactions.off;

    Widget lead(Mood mood, Glyph glyph, Color bg, Color fg) => faces
        ? Buddy(mood, size: 36, still: mood != Mood.partial)
        : Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: GlyphIcon(glyph, size: 16, color: fg, stroke: 2.25),
          );

    return SheetColumn(
      children: [
        Row(
          children: [
            if (faces)
              Buddy(
                _partial ? Mood.partial : Mood.now,
                key: ValueKey(_partial),
                size: 52,
                talk: reactions == Reactions.on,
              )
            else
              IconTile.activity(a.icon, size: 44, active: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('How did ${a.name} go?', style: AppText.sheetTitle),
                  ),
                  Text(
                    _partial
                        ? 'Some is better than none — how much?'
                        : '${fmtRange(a)} · One tap saves it',
                    style: AppText.secondary.copyWith(fontFeatures: AppText.tabular),
                  ),
                ],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Sp.x8,
          children: [
            _Option(
              lead: lead(Mood.done, Glyph.check, AppColors.successSoft, AppColors.successInk),
              title: 'Completed',
              description: 'Finished as planned',
              onTap: () => _finish(const _CheckinResult.log(LogStatus.done)),
            ),
            _Option(
              lead: lead(Mood.partial, Glyph.half, AppColors.warningSoft, AppColors.warningInk),
              title: 'Partially completed',
              description: 'Did some of it — that counts',
              selected: _partial,
              onTap: () => setState(() => _partial = true),
            ),
            _Option(
              lead: lead(Mood.skipped, Glyph.dash, AppColors.subtle, AppColors.label),
              title: 'Skipped',
              description: 'Not today',
              onTap: () => _finish(const _CheckinResult.log(LogStatus.skipped)),
            ),
          ],
        ),
        if (_partial) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Sp.x8,
            children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'How much did you do? '),
                  TextSpan(
                    text: 'Optional',
                    style: AppText.fieldLabel
                        .copyWith(color: AppColors.text2, fontWeight: FontWeight.w400),
                  ),
                ]),
                style: AppText.fieldLabel,
              ),
              Row(
                spacing: Sp.x8,
                children: [
                  for (final v in const [25, 50, 75])
                    Expanded(
                      child: _AmountChip(
                        value: v,
                        selected: _amount == v,
                        onTap: () => setState(() => _amount = v),
                      ),
                    ),
                ],
              ),
              _NoteField(controller: _note),
            ],
          ),
          Row(
            spacing: Sp.x8,
            children: [
              AppTextButton(
                label: 'Cancel',
                tone: TextButtonTone.muted,
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: PrimaryButton(
                  label: 'Save as partial',
                  onPressed: () => _finish(
                    _CheckinResult.log(LogStatus.partial, amount: _amount, note: _note.text),
                  ),
                ),
              ),
            ],
          ),
        ] else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.log != null)
                AppTextButton(
                  label: 'Clear check-in',
                  tone: TextButtonTone.danger,
                  onPressed: () => _finish(const _CheckinResult.clear()),
                )
              else
                const SizedBox.shrink(),
              AppTextButton(
                label: 'Cancel',
                tone: TextButtonTone.muted,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.lead,
    required this.title,
    required this.description,
    required this.onTap,
    this.selected = false,
  });

  final Widget lead;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      selected: selected,
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: Sp.x16, vertical: Sp.x8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.warningTint
              : pressed
                  ? AppColors.bg
                  : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.warning : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: Rad.rowAll,
        ),
        child: Row(
          children: [
            SizedBox(width: 36, child: Center(child: lead)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppText.bodyMedium),
                  Text(description, style: AppText.meta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({required this.value, required this.selected, required this.onTap});

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      selected: selected,
      label: '$value percent',
      excludeChildSemantics: true,
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: Rad.controlAll,
        ),
        child: Text(
          '$value%',
          style: AppText.secondary.copyWith(
            color: selected ? AppColors.primaryPressed : AppColors.text,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontFeatures: AppText.tabular,
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: Rad.controlAll,
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: controller,
      maxLength: 120,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      style: AppText.body,
      decoration: InputDecoration(
        hintText: 'Add a note',
        hintStyle: AppText.body.copyWith(color: AppColors.text2),
        counterText: '',
        filled: true,
        fillColor: AppColors.inputTint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: Sp.x16, vertical: 13),
        enabledBorder: border(AppColors.border, 1),
        focusedBorder: border(AppColors.primary, 1.5),
      ),
    );
  }
}
