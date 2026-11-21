import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Pill-shaped bar: 4 px on the Now card, 6 per activity, 8 overall.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.color = AppColors.primary,
    this.trackColor = AppColors.track,
  });

  /// 0–1.
  final double value;
  final double height;
  final Color color;

  /// `track` on white, `border` on the page background.
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1).toDouble()),
        duration: Motion.of(context, Motion.progress),
        curve: Motion.curve,
        builder: (context, v, _) => Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: trackColor, borderRadius: Rad.pillAll),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: Rad.pillAll),
            ),
          ),
        ),
      ),
    );
  }
}
