import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 48 × 28 switch.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.fast);
    return AnimatedContainer(
      duration: d,
      width: 48,
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? AppColors.primary : AppColors.handle,
        borderRadius: Rad.pillAll,
      ),
      child: AnimatedAlign(
        duration: d,
        curve: Motion.curve,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: Shadows.s1,
          ),
        ),
      ),
    );
  }
}

/// A titled row with a switch; the whole row toggles.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.x16, vertical: Sp.x8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppText.bodySm.copyWith(height: 20 / 15)),
                      if (subtitle != null) Text(subtitle!, style: AppText.meta),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.x12),
                Opacity(opacity: onChanged == null ? .5 : 1, child: AppSwitch(value: value)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
