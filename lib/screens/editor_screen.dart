import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;

import '../data/logic.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/activity_icon.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/switch_row.dart';
import '../widgets/toast.dart';
import 'actions.dart';

/// Opens the add (no [id]) or edit screen as a full-screen route that slides
/// up.
Future<void> openEditor(BuildContext context, {String? id}) {
  ToastScope.of(context).hide();
  final reduced = Motion.reduced(context);
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      transitionDuration: reduced ? Duration.zero : const Duration(milliseconds: 260),
      reverseTransitionDuration: reduced ? Duration.zero : Motion.sheetOut,
      pageBuilder: (context, _, _) => EditorScreen(id: id),
      transitionsBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Motion.curve, reverseCurve: Motion.exit),
        ),
        child: child,
      ),
    ),
  );
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, this.id});

  /// The activity to edit; null to create one.
  final String? id;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  ActivityDraft? _draft;
  late final TextEditingController _name;
  bool _submitted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draft != null) return;
    final store = StoreScope.read(context);
    final existing = widget.id == null ? null : store.activity(widget.id!);
    if (existing != null) {
      _draft = ActivityDraft.from(existing);
    } else {
      final start = suggestStart(store.activities, store.now);
      _draft = ActivityDraft(start: start, end: minToHHMM(toMin(start) + 30));
    }
    _name = TextEditingController(text: _draft!.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool start}) async {
    final d = _draft!;
    final current = toMin(start ? d.start : d.end);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: start ? 'Start time' : 'End time',
      // Always a 12-hour picker, whatever the device setting.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final value = minToHHMM(picked.hour * 60 + picked.minute);
      if (start) {
        d.start = value;
        if (toMin(d.end) <= toMin(d.start)) d.end = minToHHMM(toMin(d.start) + 30);
      } else {
        d.end = value;
      }
    });
  }

  void _setRepeat(RepeatMode mode) {
    final d = _draft!;
    setState(() {
      d.days = switch (mode) {
        RepeatMode.daily => [...allDays],
        RepeatMode.weekdays => [...weekdays],
        // Coming from Daily, Custom starts as Mon / Wed / Fri.
        RepeatMode.custom => d.days.length == 7 ? [0, 2, 4] : d.days,
      };
    });
  }

  void _save() {
    final d = _draft!..name = _name.text;
    if (!d.valid) {
      setState(() => _submitted = true);
      return;
    }
    final actions = AppActions.of(context);
    final isNew = d.isNew || actions.store.activity(d.id!) == null;
    final name = d.name.trim();
    unawaited(actions.store.saveDraft(d));
    Navigator.of(context).pop();
    actions.toast.show(isNew ? '$name added' : 'Changes saved');
    if (isNew) unawaited(actions.reminders.requestPermissionOnce());
  }

  void _delete() {
    final actions = AppActions.of(context);
    Navigator.of(context).pop();
    actions.delete(_draft!.id!);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = _draft!;
    final isNew = d.isNew;
    final mq = MediaQuery.of(context);
    final nameError = _submitted && _name.text.trim().isEmpty;
    final timeError = !d.timeValid;
    final daysError = _submitted && !d.daysValid;
    final length = toMin(d.end) - toMin(d.start);
    final hint = length > 0
        ? dur(length) +
            neighbourHint(
              id: d.id,
              start: toMin(d.start),
              end: toMin(d.end),
              days: d.days,
              activities: store.activities,
            )
        : '';
    final mode = repeatMode(d.days);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ---- top bar ----
          Padding(
            padding: EdgeInsets.fromLTRB(Sp.x12, mq.padding.top + Sp.x8, Sp.x12, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppTextButton(
                        label: 'Cancel',
                        style: AppText.body,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        isNew ? 'New activity' : 'Edit activity',
                        textAlign: TextAlign.center,
                        style: AppText.navTitle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 88),
                ],
              ),
            ),
          ),
          // ---- form ----
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(Sp.screen, Sp.x12, Sp.screen, Sp.x32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: Sp.x24,
                children: [
                  _Field(
                    label: 'Activity name',
                    error: nameError ? 'Give it a short name' : null,
                    child: _NameField(
                      controller: _name,
                      autofocus: isNew,
                      error: nameError,
                      onChanged: (_) {
                        if (_submitted) setState(() {});
                      },
                    ),
                  ),
                  _Field(
                    label: 'Icon',
                    child: LayoutBuilder(
                      builder: (context, c) {
                        const gap = Sp.x8;
                        final w = (c.maxWidth - gap * 5) / 6;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final k in iconKeys)
                              SizedBox(
                                width: w,
                                child: _IconChoice(
                                  iconKey: k,
                                  selected: d.icon == k,
                                  onTap: () => setState(() => d.icon = k),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: Sp.x8,
                    children: [
                      Row(
                        spacing: Sp.x12,
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Start time',
                              child: _TimeField(
                                label: 'Start time',
                                value: fmt12(toMin(d.start)),
                                onTap: () => _pickTime(start: true),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _Field(
                              label: 'End time',
                              child: _TimeField(
                                label: 'End time',
                                value: fmt12(toMin(d.end)),
                                error: timeError,
                                onTap: () => _pickTime(start: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (timeError)
                        _ErrorText('End time needs to be after ${fmt12(toMin(d.start))}')
                      else
                        Text(hint, style: AppText.meta),
                    ],
                  ),
                  _Field(
                    label: 'Repeat',
                    error: daysError ? 'Pick at least one day' : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: Sp.x12,
                      children: [
                        Segmented<RepeatMode>(
                          label: 'Repeat',
                          expand: true,
                          value: mode,
                          options: const [
                            (RepeatMode.daily, 'Daily'),
                            (RepeatMode.weekdays, 'Weekdays'),
                            (RepeatMode.custom, 'Custom'),
                          ],
                          onChanged: _setRepeat,
                        ),
                        LayoutBuilder(
                          // 44 px circles; a little smaller on narrow screens
                          // rather than clipping Sunday.
                          builder: (context, c) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var i = 0; i < 7; i++)
                                _DayChip(
                                  day: i,
                                  size: ((c.maxWidth - 6 * Sp.x4) / 7).clamp(32.0, 44.0),
                                  selected: d.days.contains(i),
                                  onTap: () => setState(() {
                                    d.days = d.days.contains(i)
                                        ? (d.days.where((x) => x != i).toList())
                                        : ([...d.days, i]..sort());
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Field(
                    label: 'Reminders',
                    child: ListGroup(
                      children: [
                        SwitchRow(
                          title: 'Notify at start',
                          value: d.remindStart,
                          onChanged: (v) => setState(() => d.remindStart = v),
                        ),
                        SwitchRow(
                          title: 'Notify before end',
                          subtitle: '10 min before',
                          value: d.remindEnd,
                          onChanged: (v) => setState(() => d.remindEnd = v),
                        ),
                        SwitchRow(
                          title: 'Ask if missed',
                          subtitle: 'A quick check-in when it ends',
                          value: d.askMissed,
                          onChanged: (v) => setState(() => d.askMissed = v),
                        ),
                      ],
                    ),
                  ),
                  if (!isNew)
                    Column(
                      spacing: Sp.x4,
                      children: [
                        AppTextButton(
                          label: 'Delete activity',
                          tone: TextButtonTone.danger,
                          onPressed: _delete,
                        ),
                        Text('Past history is kept either way.', style: AppText.meta),
                      ],
                    ),
                ],
              ),
            ),
          ),
          // ---- sticky footer ----
          Container(
            decoration: const BoxDecoration(
              color: AppColors.bg,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: EdgeInsets.fromLTRB(
              Sp.screen,
              Sp.x12,
              Sp.screen,
              Sp.x16 + (mq.viewInsets.bottom > 0 ? 0 : mq.padding.bottom),
            ),
            child: SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: isNew ? 'Create activity' : 'Save changes',
                height: 52,
                onPressed: _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.error});

  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Sp.x8,
        children: [
          ExcludeSemantics(child: Text(label, style: AppText.fieldLabel)),
          child,
          if (error != null) _ErrorText(error!),
        ],
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Text(text, style: AppText.meta.copyWith(color: AppColors.dangerInk)),
      );
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.autofocus,
    required this.error,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool autofocus;
  final bool error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: Rad.controlAll,
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLength: 40,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      style: AppText.body,
      decoration: InputDecoration(
        labelText: null,
        hintText: 'e.g. Evening walk',
        hintStyle: AppText.body.copyWith(color: AppColors.text2),
        semanticCounterText: '',
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: Sp.x16, vertical: 15),
        enabledBorder:
            error ? border(AppColors.danger, 1.5) : border(AppColors.border, 1),
        focusedBorder:
            error ? border(AppColors.danger, 1.5) : border(AppColors.primary, 1.5),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onTap, this.error = false});

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      label: '$label, $value',
      excludeChildSemantics: true,
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: Sp.x16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: pressed ? AppColors.subtle : AppColors.surface,
          border: Border.all(
            color: error ? AppColors.danger : AppColors.border,
            width: error ? 1.5 : 1,
          ),
          borderRadius: Rad.controlAll,
        ),
        child: Text(value, style: AppText.body.copyWith(fontFeatures: AppText.tabular)),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({required this.iconKey, required this.selected, required this.onTap});

  final String iconKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      selected: selected,
      label: '${activityIconNames[iconKey] ?? iconKey} icon',
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        height: 48,
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: Rad.controlAll,
        ),
        child: Icon(
          activityIcon(iconKey),
          size: 20,
          color: selected ? AppColors.primary : AppColors.label,
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      selected: selected,
      label: dayNames[day],
      excludeChildSemantics: true,
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          shape: BoxShape.circle,
        ),
        child: Text(
          dayShort[day],
          textScaler: TextScaler.noScaling,
          style: AppText.secondary.copyWith(
            color: selected ? AppColors.onPrimary : AppColors.text2,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
