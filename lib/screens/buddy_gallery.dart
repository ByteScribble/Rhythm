import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/bubble.dart';
import '../widgets/buddy.dart';
import '../widgets/buttons.dart';

/// Debug-only: every mood at every size used in the app.
class BuddyGallery extends StatefulWidget {
  const BuddyGallery({super.key});

  @override
  State<BuddyGallery> createState() => _BuddyGalleryState();
}

class _BuddyGalleryState extends State<BuddyGallery> {
  int _replay = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Sp.x20),
          children: [
            Row(
              children: [
                AppTextButton(label: 'Close', onPressed: () => Navigator.of(context).pop()),
                Expanded(
                  child: Text('Buddy gallery', textAlign: TextAlign.center, style: AppText.navTitle),
                ),
                AppTextButton(label: 'Replay', onPressed: () => setState(() => _replay++)),
              ],
            ),
            for (final mood in Mood.values) ...[
              const SizedBox(height: Sp.x24),
              Text(mood.name.toUpperCase(), style: AppText.section),
              const SizedBox(height: Sp.x12),
              KeyedSubtree(
                key: ValueKey('${mood.name}-$_replay'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Sp.x16,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: Sp.x16,
                      children: [
                        Buddy(mood, size: 72, talk: true, sparkle: true),
                        Buddy(mood, size: 56, talk: true),
                        Buddy(mood, size: 36),
                        PopIn(child: Buddy(mood, size: 28)),
                        Buddy(mood, size: 32, still: true),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Buddy(mood, size: 52, talk: true, sparkle: true),
                        const SizedBox(width: 10),
                        Expanded(child: SpeechBubble('This is how ${mood.name} sounds.')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
