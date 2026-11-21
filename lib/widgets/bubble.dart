import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import 'buddy.dart';

/// What the buddy "says". Pops in once per mount.
class SpeechBubble extends StatefulWidget {
  const SpeechBubble(this.text, {super.key});

  final String text;

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.bubbleDelay + Motion.bubble,
  );
  late final Animation<double> _in = CurvedAnimation(
    parent: _c,
    curve: Interval(
      Motion.bubbleDelay.inMilliseconds / (Motion.bubbleDelay + Motion.bubble).inMilliseconds,
      1,
      curve: Motion.curve,
    ),
  );
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
        child: Transform.translate(
          offset: Offset(0, 4 * (1 - _in.value)),
          child: Transform.scale(scale: .92 + .08 * _in.value, child: child),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.track),
          // The small corner is the tail, pointing at the face.
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(Rad.group),
            topRight: Radius.circular(Rad.group),
            bottomRight: Radius.circular(Rad.group),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Text(
          widget.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.secondary.copyWith(color: AppColors.text),
        ),
      ),
    );
  }
}

/// Face + speech bubble, following the Reactions setting: On → both,
/// Quiet → face only, Off → nothing.
class BuddyRow extends StatelessWidget {
  const BuddyRow({
    super.key,
    required this.mood,
    required this.size,
    required this.text,
    this.sparkle = false,
  });

  final Mood mood;
  final double size;
  final String text;
  final bool sparkle;

  @override
  Widget build(BuildContext context) {
    final reactions = StoreScope.of(context).reactions;
    if (reactions == Reactions.off) return const SizedBox.shrink();
    final on = reactions == Reactions.on;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Buddy(mood, size: size, talk: on, sparkle: sparkle),
        if (on) ...[
          const SizedBox(width: 10),
          Expanded(child: SpeechBubble(text)),
        ],
      ],
    );
  }
}
