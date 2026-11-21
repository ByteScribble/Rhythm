import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';
import 'buddy.dart' show PopIn;
import 'chips.dart';

/// 20 px timeline node; shape and glyph differ per status (§9.3).
class StatusNode extends StatelessWidget {
  const StatusNode(this.status, {super.key});

  final ItemStatus status;

  static const double size = 20;

  @override
  Widget build(BuildContext context) {
    Widget circle({
      required Color fill,
      Color? ring,
      double ringWidth = 1.5,
      Widget? child,
      List<BoxShadow>? halo,
    }) =>
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: ring == null ? null : Border.all(color: ring, width: ringWidth),
            boxShadow: halo,
          ),
          child: child,
        );

    return ExcludeSemantics(
      child: switch (status) {
        ItemStatus.done => PopIn(
            child: circle(
              fill: AppColors.success,
              child: const GlyphIcon(Glyph.check, size: 12, color: AppColors.onPrimary),
            ),
          ),
        ItemStatus.partial => PopIn(
            child: circle(
              fill: AppColors.surface,
              ring: AppColors.warning,
              ringWidth: 2,
              child: const CustomPaint(size: Size.square(14), painter: _LeftHalf()),
            ),
          ),
        ItemStatus.now => circle(
            fill: AppColors.surface,
            ring: AppColors.primary,
            ringWidth: 2,
            halo: const [BoxShadow(color: AppColors.primaryRing, spreadRadius: 4)],
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
          ),
        ItemStatus.skipped => circle(
            fill: AppColors.subtle,
            ring: AppColors.borderStrong,
            child: const GlyphIcon(Glyph.dash, size: 10, color: AppColors.text2),
          ),
        ItemStatus.missed => circle(
            fill: AppColors.surface,
            ring: AppColors.danger,
            child: const GlyphIcon(Glyph.cross, size: 10, color: AppColors.dangerInk),
          ),
        ItemStatus.upcoming || ItemStatus.na => circle(
            fill: AppColors.surface,
            ring: AppColors.borderStrong,
          ),
      },
    );
  }
}

/// The left half of a disc, for the "partial" node.
class _LeftHalf extends CustomPainter {
  const _LeftHalf();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      Offset.zero & size,
      1.5707963267948966,
      3.141592653589793,
      true,
      Paint()..color = AppColors.warning,
    );
  }

  @override
  bool shouldRepaint(_LeftHalf oldDelegate) => false;
}
