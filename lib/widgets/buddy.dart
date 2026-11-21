import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The buddy face's moods (§9.7).
enum Mood { now, done, partial, skipped, missed }

({Color fill, Color stroke}) _moodColors(Mood m) => switch (m) {
      Mood.now => (fill: AppColors.primarySoft, stroke: AppColors.primary),
      Mood.done => (fill: AppColors.successSoft, stroke: AppColors.success),
      Mood.partial => (fill: AppColors.warningSoft, stroke: AppColors.warning),
      Mood.skipped => (fill: AppColors.subtle, stroke: AppColors.text3),
      Mood.missed => (fill: AppColors.dangerSoft, stroke: AppColors.danger),
    };

/// A small face drawn in code that reacts to an activity's status.
///
/// Entry effects (jump, talk, sparkles) play once per mount, so key the widget
/// by `activityId + status` to replay them only when the status changes.
/// Purely decorative: meaning is always carried by text next to it.
class Buddy extends StatefulWidget {
  const Buddy(
    this.mood, {
    super.key,
    required this.size,
    this.talk = false,
    this.sparkle = false,
    this.still = false,
  });

  final Mood mood;
  final double size;

  /// Move the mouth for a moment after appearing.
  final bool talk;

  /// Sparkles around a `done` face.
  final bool sparkle;

  /// No idle motion.
  final bool still;

  @override
  State<Buddy> createState() => _BuddyState();
}

class _BuddyState extends State<Buddy> with SingleTickerProviderStateMixin {
  // One controller per face; it only supplies elapsed time to the painter.
  late final AnimationController _time =
      AnimationController(vsync: this, duration: const Duration(hours: 1));
  bool _reduced = false;

  bool get _small => widget.size <= 36;

  bool get _animated {
    if (_reduced || widget.still) return false;
    // A small happy face has no idle motion and nothing to blink.
    if (widget.mood == Mood.done && _small && !widget.talk && !widget.sparkle) return false;
    return true;
  }

  void _sync() {
    if (_animated) {
      if (!_time.isAnimating) _time.repeat();
    } else {
      _time.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.reduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(Buddy old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _BuddyPainter(
            mood: widget.mood,
            small: _small,
            talk: widget.talk,
            sparkle: widget.sparkle && widget.mood == Mood.done,
            time: _animated ? _time : null,
          ),
        ),
      ),
    );
  }
}

/// Value at [p] (0–1) on a keyframe track of `(position, value)` pairs, eased
/// between neighbours like a CSS animation.
double _track(double p, List<(double, double)> frames, Curve curve) {
  for (var i = 1; i < frames.length; i++) {
    final (p0, v0) = frames[i - 1];
    final (p1, v1) = frames[i];
    if (p <= p1) {
      final local = p1 == p0 ? 1.0 : ((p - p0) / (p1 - p0)).clamp(0.0, 1.0);
      return v0 + (v1 - v0) * curve.transform(local);
    }
  }
  return frames.last.$2;
}

double _loop(double t, double period) => (t % period) / period;

const _hump = [(0.0, 0.0), (0.5, 1.0), (1.0, 0.0)];
const _deg = math.pi / 180;

class _BuddyPainter extends CustomPainter {
  _BuddyPainter({
    required this.mood,
    required this.small,
    required this.talk,
    required this.sparkle,
    required this.time,
  }) : super(repaint: time);

  final Mood mood;
  final bool small;
  final bool talk;
  final bool sparkle;

  /// Null = draw the resting pose.
  final AnimationController? time;

  static const _jump = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    final moving = time != null;
    final t = moving ? (time!.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6 : 0.0;
    final w = size.width, k = w / 56;

    // ---- body motion (in logical px, like the CSS it was ported from) ----
    var dx = 0.0, dy = 0.0, rot = 0.0, sx = 1.0, sy = 1.0;
    if (moving) {
      switch (mood) {
        case Mood.now:
          dy = -3 * _track(_loop(t, 3), _hump, Curves.easeInOut);
        case Mood.done:
          if (small) break;
          if (t < _jump) {
            final p = t / _jump;
            dy = _track(p, const [(0, 0), (.25, -12), (.5, 0), (.7, -4), (1, 0)], Motion.curve);
            sx = _track(p, const [(0, 1), (.25, 1.06), (.5, 1.08), (.7, .98), (1, 1)], Motion.curve);
            sy = _track(p, const [(0, 1), (.25, 1.06), (.5, .92), (.7, 1.02), (1, 1)], Motion.curve);
          } else {
            dy = -3 * _track(_loop(t - _jump, 3), _hump, Curves.easeInOut);
          }
        case Mood.partial:
          rot = _deg *
              _track(_loop(t, 2.4), const [(0, 0), (.25, -7), (.75, 5), (1, 0)], Curves.easeInOut);
        case Mood.skipped:
          final p = _track(_loop(t, 3.2), _hump, Curves.easeInOut);
          dx = 2 * p;
          rot = 3 * _deg * p;
        case Mood.missed:
          final p = _track(_loop(t, 3.2), _hump, Curves.easeInOut);
          dy = 2 * p;
          rot = -4 * _deg * p;
      }
    }

    canvas.save();
    canvas.translate(dx, dy);
    if (rot != 0) {
      // Pivot near the bottom centre.
      canvas.translate(w * .5, w * .9);
      canvas.rotate(rot);
      canvas.translate(-w * .5, -w * .9);
    }
    if (sx != 1 || sy != 1) {
      canvas.translate(w / 2, w / 2);
      canvas.scale(sx, sy);
      canvas.translate(-w / 2, -w / 2);
    }
    canvas.scale(k);
    _face(canvas, t, moving);
    canvas.restore();

    if (sparkle && moving) _sparkles(canvas, w, t);
  }

  void _face(Canvas canvas, double t, bool moving) {
    final c = _moodColors(mood);
    final ink = Paint()
      ..color = AppColors.buddyInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = small ? 3.2 : 2.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final solid = Paint()..color = AppColors.buddyInk;

    const centre = Offset(28, 28);
    canvas.drawCircle(centre, 25, Paint()..color = c.fill);
    canvas.drawCircle(
      centre,
      25,
      Paint()
        ..color = c.stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = small ? 2.4 : 1.5,
    );

    final blink = moving
        ? _track(_loop(t, 4), const [(0, 1), (.9, 1), (.94, .1), (1, 1)], Curves.ease)
        : 1.0;
    // The mouth "talks" once: 8 half-cycles of 180 ms, starting after 120 ms.
    var mouth = 1.0;
    if (moving && talk && t >= .12 && t < .12 + 8 * .18) {
      mouth = 1 - .65 * _track(_loop(t - .12, .18), _hump, Curves.easeInOut);
    }

    void eyes(double lcy, double lry, double rcy, double rry, {double shift = 0}) {
      final rx = small ? 3.2 : 2.6;
      final mid = (lcy + rcy) / 2;
      canvas.save();
      canvas.translate(shift, mid);
      canvas.scale(1, blink);
      canvas.translate(0, -mid);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(21, lcy), width: rx * 2, height: lry * 2), solid);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(35, rcy), width: rx * 2, height: rry * 2), solid);
      canvas.restore();
    }

    void talking(Path path, void Function() draw) {
      if (mouth == 1) return draw();
      final cy = path.getBounds().center.dy;
      canvas.save();
      canvas.translate(0, cy);
      canvas.scale(1, mouth);
      canvas.translate(0, -cy);
      draw();
      canvas.restore();
    }

    Path quad(double x0, double y0, double cx, double cy, double x1, double y1) => Path()
      ..moveTo(x0, y0)
      ..quadraticBezierTo(cx, cy, x1, y1);

    switch (mood) {
      case Mood.now:
        final look = moving
            ? _track(_loop(t, 5), const [(0, 0), (.4, 0), (.5, 2.5), (.85, 2.5), (1, 0)],
                Curves.easeInOut)
            : 0.0;
        final ry = small ? 4.0 : 3.4;
        eyes(25, ry, 25, ry, shift: look);
        final m = quad(22, 35, 28, 40, 34, 35);
        talking(m, () => canvas.drawPath(m, ink));

      case Mood.done:
        canvas.drawPath(quad(16.5, 26, 20.5, 20.5, 24.5, 26), ink);
        canvas.drawPath(quad(31.5, 26, 35.5, 20.5, 39.5, 26), ink);
        final cheek = Paint()..color = AppColors.buddyCheek;
        canvas.drawCircle(const Offset(14.5, 32.5), 3, cheek);
        canvas.drawCircle(const Offset(41.5, 32.5), 3, cheek);
        final m = quad(19, 32, 28, 45, 37, 32)..close();
        talking(m, () {
          canvas.drawPath(m, solid);
          if (!small) {
            final tongue = Path()
              ..moveTo(23.5, 38)
              ..quadraticBezierTo(28, 35.5, 32.5, 38)
              ..quadraticBezierTo(28, 41.5, 23.5, 38)
              ..close();
            canvas.drawPath(tongue, Paint()..color = AppColors.buddyTongue);
          }
        });

      case Mood.partial:
        canvas.drawPath(quad(32, 18.5, 35.5, 16.5, 39, 18.5), ink);
        eyes(25.5, small ? 3.7 : 3.2, 24.5, small ? 3.9 : 3.4);
        final m = quad(21, 35, 28, 38.5, 35, 33);
        talking(m, () => canvas.drawPath(m, ink));

      case Mood.skipped:
        canvas.drawPath(quad(17.5, 26.5, 21, 28.8, 24.5, 26.5), ink);
        canvas.drawPath(quad(31.5, 26.5, 35, 28.8, 38.5, 26.5), ink);
        final m = quad(23, 36, 28, 37.5, 33, 36);
        talking(m, () => canvas.drawPath(m, ink));
        if (!small) {
          final z = TextPainter(
            text: const TextSpan(
              text: 'z',
              style: TextStyle(
                fontFamily: AppText.family,
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w700,
                color: AppColors.text3,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          z.paint(canvas, Offset(42, 14 - z.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
          z.dispose();
        }

      case Mood.missed:
        // Sad brows: inner ends higher.
        canvas.drawLine(const Offset(16.5, 23), const Offset(23.5, 20), ink);
        canvas.drawLine(const Offset(39.5, 23), const Offset(32.5, 20), ink);
        final ry = small ? 3.6 : 3.0;
        eyes(27, ry, 27, ry);
        final m = quad(21.5, 38.5, 28, 33, 34.5, 38.5);
        talking(m, () => canvas.drawPath(m, ink));
        // The tear drips and fades while moving; at rest it just sits there.
        var drop = 0.0, alpha = 1.0;
        if (moving) {
          final p = _loop(t, 2.2);
          drop = _track(p, const [(0, 0), (.8, 9), (1, 11)], Curves.easeIn);
          alpha = _track(p, const [(0, 0), (.2, 1), (.8, 1), (1, 0)], Curves.easeIn);
        }
        final tear = Path()
          ..moveTo(37, 30.5)
          ..quadraticBezierTo(39.2, 33.9, 37, 35.5)
          ..quadraticBezierTo(34.8, 33.9, 37, 30.5)
          ..close();
        canvas.drawPath(
          tear.shift(Offset(0, drop)),
          Paint()..color = AppColors.buddyTear.withValues(alpha: alpha),
        );
    }
  }

  void _sparkles(Canvas canvas, double w, double t) {
    void star(Offset centre, double size, Color color, double delay) {
      if (t < delay) return;
      final p = _loop(t - delay, 1.4);
      final scale = _track(p, const [(0, 0), (.4, 1), (1, .6)], Curves.easeOut);
      final turn = _track(p, const [(0, 0), (.4, 45), (1, 90)], Curves.easeOut) * _deg;
      final alpha = _track(p, const [(0, 0), (.4, 1), (1, 0)], Curves.easeOut);
      final u = size / 12;
      // Four-point star on a 12-unit grid, centred on the origin.
      final path = Path()
        ..moveTo(0, -6 * u)
        ..lineTo(1.4 * u, -1.4 * u)
        ..lineTo(6 * u, 0)
        ..lineTo(1.4 * u, 1.4 * u)
        ..lineTo(0, 6 * u)
        ..lineTo(-1.4 * u, 1.4 * u)
        ..lineTo(-6 * u, 0)
        ..lineTo(-1.4 * u, -1.4 * u)
        ..close();
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(turn);
      canvas.scale(scale);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
      canvas.restore();
    }

    star(Offset.zero, 12, AppColors.warning, 0);
    star(Offset(w + 3, 3), 10, AppColors.success, .45);
    star(Offset(w + 6, w - 6), 8, AppColors.primary, .9);
  }

  @override
  bool shouldRepaint(_BuddyPainter old) =>
      old.mood != mood ||
      old.small != small ||
      old.talk != talk ||
      old.sparkle != sparkle ||
      old.time != time;
}

/// Plays a small "pop" (scale .6 → 1.08 → 1) once when mounted.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child});

  final Widget child;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.pop);
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
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final p = _c.value;
        final scale = _track(p, const [(0, .6), (.7, 1.08), (1, 1)], Motion.curve);
        final opacity = _track(p, const [(0, .4), (1, 1)], Motion.curve);
        return Opacity(opacity: opacity, child: Transform.scale(scale: scale, child: child));
      },
    );
  }
}
