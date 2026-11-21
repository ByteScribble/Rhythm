import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The small shapes that carry status alongside colour.
enum Glyph { check, half, dash, cross, dot, clock, up, down }

/// Draws a [Glyph] on a 24-unit grid with round strokes.
class GlyphIcon extends StatelessWidget {
  const GlyphIcon(this.glyph, {super.key, this.size = 12, required this.color, this.stroke = 3});

  final Glyph glyph;
  final double size;
  final Color color;

  /// Stroke width on the 24-unit grid.
  final double stroke;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _GlyphPainter(glyph, color, stroke),
      );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color, this.stroke);

  final Glyph glyph;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    Path poly(List<double> p) {
      final path = Path()..moveTo(p[0], p[1]);
      for (var i = 2; i < p.length; i += 2) {
        path.lineTo(p[i], p[i + 1]);
      }
      return path;
    }

    switch (glyph) {
      case Glyph.check:
        canvas.drawPath(poly([5, 12.5, 9.5, 17, 19, 7.5]), line);
      case Glyph.dash:
        canvas.drawPath(poly([6, 12, 18, 12]), line);
      case Glyph.cross:
        canvas.drawPath(poly([7, 7, 17, 17]), line);
        canvas.drawPath(poly([17, 7, 7, 17]), line);
      case Glyph.dot:
        canvas.drawCircle(const Offset(12, 12), 6, fill);
      case Glyph.half:
        canvas.drawCircle(const Offset(12, 12), 9.6, line);
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 7.2),
          1.5707963267948966,
          3.141592653589793,
          true,
          fill,
        );
      case Glyph.clock:
        canvas.drawCircle(const Offset(12, 12), 8.5, line);
        canvas.drawPath(poly([12, 7.5, 12, 12, 15, 14]), line);
      case Glyph.up:
        canvas.drawPath(poly([12, 19, 12, 5]), line);
        canvas.drawPath(poly([6, 11, 12, 5, 18, 11]), line);
      case Glyph.down:
        canvas.drawPath(poly([12, 5, 12, 19]), line);
        canvas.drawPath(poly([6, 13, 12, 19, 18, 13]), line);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.stroke != stroke;
}

enum ChipKind { now, upcoming, done, partial, skipped, missed, free }

({Color bg, Color fg, Glyph? glyph}) _chipStyle(ChipKind k) => switch (k) {
      ChipKind.now => (bg: AppColors.primarySoft, fg: AppColors.primaryPressed, glyph: Glyph.dot),
      ChipKind.upcoming => (bg: AppColors.subtle, fg: AppColors.label, glyph: null),
      ChipKind.done => (bg: AppColors.successSoft, fg: AppColors.successInk, glyph: Glyph.check),
      ChipKind.partial => (bg: AppColors.warningSoft, fg: AppColors.warningInk, glyph: Glyph.half),
      ChipKind.skipped => (bg: AppColors.subtle, fg: AppColors.label, glyph: Glyph.dash),
      ChipKind.missed => (bg: AppColors.dangerSoft, fg: AppColors.dangerInk, glyph: Glyph.cross),
      ChipKind.free => (bg: AppColors.subtle, fg: AppColors.label, glyph: Glyph.clock),
    };

const Map<ChipKind, String> _chipWords = {
  ChipKind.now: 'Now',
  ChipKind.upcoming: 'Upcoming',
  ChipKind.done: 'Completed',
  ChipKind.partial: 'Partially done',
  ChipKind.skipped: 'Skipped',
  ChipKind.missed: 'Missed',
  ChipKind.free: 'Free time',
};

/// 28 px pill: a glyph plus a word, never colour alone.
class StatusChip extends StatelessWidget {
  const StatusChip(this.kind, {super.key, this.label, this.glyph});

  final ChipKind kind;

  /// Overrides the default word ("6 completed").
  final String? label;

  /// Overrides the default glyph (delta arrows).
  final Glyph? glyph;

  @override
  Widget build(BuildContext context) {
    final s = _chipStyle(kind);
    final g = glyph ?? s.glyph;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: s.bg, borderRadius: Rad.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (g != null) ...[
            g == Glyph.dot
                ? GlyphIcon(g, size: 6, color: s.fg)
                : GlyphIcon(g, size: 12, color: s.fg, stroke: g == Glyph.clock ? 2 : 3),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label ?? _chipWords[kind]!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.chip.copyWith(color: s.fg),
            ),
          ),
        ],
      ),
    );
  }
}
