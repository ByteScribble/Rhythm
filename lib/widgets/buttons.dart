import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Tap target with a pressed state: no ripple, optional scale to .98.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.scale = false,
    this.label,
    this.selected,
    this.excludeChildSemantics = false,
  });

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool pressed) builder;
  final bool scale;

  /// Semantic label (required for icon-only buttons).
  final String? label;
  final bool? selected;
  final bool excludeChildSemantics;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget child = widget.builder(context, _down && enabled);
    if (widget.scale) {
      child = AnimatedScale(
        scale: _down && enabled ? .98 : 1,
        duration: Motion.of(context, Motion.fast),
        child: child,
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      selected: widget.selected,
      excludeSemantics: widget.excludeChildSemantics,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: child,
      ),
    );
  }
}

/// Centres button content; the button hugs it unless its parent sets a width.
class _Hug extends StatelessWidget {
  const _Hug({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(widthFactor: 1, heightFactor: 1, child: child);
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({required this.label, required this.style, this.icon, this.iconColor});

  final String label;
  final TextStyle style;
  final Widget? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconTheme(data: IconThemeData(size: 18, color: iconColor ?? style.color), child: icon!),
          const SizedBox(width: Sp.x8),
        ],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ],
    );
  }
}

/// Filled call to action: one per screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 48,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// 48, or 52 in footers.
  final double height;

  /// Destructive confirmation.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Pressable(
      onTap: onPressed,
      scale: true,
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: Sp.x20),
        decoration: BoxDecoration(
          color: !enabled
              ? AppColors.border
              : danger
                  ? (pressed ? AppColors.danger : AppColors.dangerInk)
                  : (pressed ? AppColors.primaryPressed : AppColors.primary),
          borderRadius: Rad.controlAll,
        ),
        child: _Hug(
          child: _ButtonContent(
            label: label,
            icon: icon == null ? null : Icon(icon),
            style: AppText.button.copyWith(color: enabled ? AppColors.onPrimary : AppColors.text3),
          ),
        ),
      ),
    );
  }
}

/// White, bordered button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 48,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Any widget; sized 18.
  final Widget? icon;
  final double height;

  /// Smaller text and padding (the 44 px "Start early").
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      scale: true,
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        constraints: BoxConstraints(minHeight: height),
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : Sp.x16),
        decoration: BoxDecoration(
          color: pressed ? AppColors.subtle : AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: Rad.controlAll,
        ),
        child: _Hug(
          child: _ButtonContent(
            label: label,
            icon: icon,
            iconColor: AppColors.text,
            style: compact ? AppText.buttonSm.copyWith(fontSize: 14) : AppText.buttonSm,
          ),
        ),
      ),
    );
  }
}

enum TextButtonTone { primary, muted, danger }

/// Borderless text action, 44 px tall.
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = TextButtonTone.primary,
    this.style,
  });

  final String label;
  final VoidCallback? onPressed;
  final TextButtonTone tone;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      TextButtonTone.primary => AppColors.primary,
      TextButtonTone.muted => AppColors.text2,
      TextButtonTone.danger => AppColors.dangerInk,
    };
    return Pressable(
      onTap: onPressed,
      builder: (context, pressed) => AnimatedOpacity(
        duration: Motion.of(context, Motion.fast),
        opacity: pressed ? .6 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: Sp.x12),
          child: _Hug(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (style ?? AppText.buttonSm).copyWith(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// 44 × 44 white icon button (header actions).
class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;

  /// Spoken label and tooltip.
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Pressable(
        onTap: onPressed,
        label: label,
        builder: (context, pressed) => AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: pressed ? AppColors.subtle : AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: Rad.controlAll,
          ),
          child: Icon(icon, size: 20, color: AppColors.text),
        ),
      ),
    );
  }
}

/// 44 × 44 borderless icon button (row "⋮").
class GhostIconButton extends StatelessWidget {
  const GhostIconButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Pressable(
        onTap: onPressed,
        label: label,
        builder: (context, pressed) => AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: pressed ? AppColors.subtle : AppColors.subtle.withValues(alpha: 0),
            borderRadius: const BorderRadius.all(Radius.circular(Rad.tileSm)),
          ),
          child: Icon(icon, size: 20, color: AppColors.text2),
        ),
      ),
    );
  }
}

/// 44 px outlined pill (template shortcuts).
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      builder: (context, pressed) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: pressed ? AppColors.subtle : AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: Rad.pillAll,
        ),
        child: Center(
          widthFactor: 1,
          child: Text(label, style: AppText.secondary.copyWith(color: AppColors.text)),
        ),
      ),
    );
  }
}

/// Segmented control: a track with a white thumb under the selected option.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.expand = false,
    this.label,
  });

  /// `(value, label)` pairs.
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Equal-width segments filling the row (40 px tall) instead of hugging
  /// their labels (38 px).
  final bool expand;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final inset = expand ? 4.0 : 3.0;
    Widget segment((T, String) o) {
      final selected = o.$1 == value;
      return Pressable(
        onTap: () => onChanged(o.$1),
        selected: selected,
        // The tap target is the full height of the track (≥ 44); the thumb
        // is drawn inset.
        builder: (context, pressed) => Padding(
          padding: EdgeInsets.symmetric(vertical: inset),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            constraints: BoxConstraints(minHeight: expand ? 40 : 38),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : AppColors.surface.withValues(alpha: 0),
              borderRadius: const BorderRadius.all(Radius.circular(Rad.segment)),
              boxShadow: selected ? Shadows.s1 : null,
            ),
            child: Text(
              o.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.secondary.copyWith(
                color: selected ? AppColors.text : AppColors.text2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    final gap = expand ? Sp.x4 : 2.0;
    return Semantics(
      container: true,
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: inset),
        decoration: const BoxDecoration(color: AppColors.track, borderRadius: Rad.controlAll),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (final (i, o) in options.indexed) ...[
              if (i > 0) SizedBox(width: gap),
              if (expand) Expanded(child: segment(o)) else segment(o),
            ],
          ],
        ),
      ),
    );
  }
}
