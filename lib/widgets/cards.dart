import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 1 px hairline between rows.
class Hairline extends StatelessWidget {
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 1,
        child: ColoredBox(color: AppColors.track),
      );
}

/// Uppercase section label ("NOW", "BY ACTIVITY").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(text.toUpperCase(), style: AppText.section),
      );
}

/// The Now card: the only element on a screen with a soft shadow. Fades up
/// once when mounted.
class NowCardFrame extends StatefulWidget {
  const NowCardFrame({super.key, required this.children});

  final List<Widget> children;

  @override
  State<NowCardFrame> createState() => _NowCardFrameState();
}

class _NowCardFrameState extends State<NowCardFrame> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.pop);
  late final Animation<double> _in = CurvedAnimation(parent: _c, curve: Motion.curve);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _in,
      builder: (context, child) => Opacity(
        opacity: _in.value,
        child: Transform.translate(offset: Offset(0, 6 * (1 - _in.value)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(Sp.x20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: Rad.cardAll,
          boxShadow: Shadows.s2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: Sp.x20,
          children: widget.children,
        ),
      ),
    );
  }
}

/// Small white card (Insights highlights).
class SmallCard extends StatelessWidget {
  const SmallCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Sp.x16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: Rad.groupAll,
        ),
        child: child,
      );
}

/// White list group with hairline dividers between rows.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: Rad.groupAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const Hairline(),
              c,
            ],
          ],
        ),
      );
}

/// Screen header: optional eyebrow, big title, optional sub-line, actions on
/// the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              if (eyebrow != null) Text(eyebrow!, style: AppText.secondary),
              Semantics(header: true, child: Text(title, style: AppText.heading)),
              if (subtitle != null) Text(subtitle!, style: AppText.secondary),
            ],
          ),
        ),
        const SizedBox(width: Sp.x12),
        Row(mainAxisSize: MainAxisSize.min, spacing: Sp.x8, children: actions),
      ],
    );
  }
}

/// Centred empty-state block.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.art,
    required this.title,
    required this.message,
    this.children = const [],
  });

  final Widget art;
  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x12, Sp.x24, Sp.x12, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: Sp.x24,
        children: [
          art,
          Column(
            spacing: Sp.x8,
            children: [
              Text(title, textAlign: TextAlign.center, style: AppText.title.copyWith(letterSpacing: 0)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppText.bodySm.copyWith(color: AppColors.text2),
                ),
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}
