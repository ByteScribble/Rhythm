import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Activity icon keys → bundled Material icons (§9.6).
const Map<String, IconData> activityIcons = {
  'sun': Icons.wb_twilight,
  'water': Icons.water_drop_outlined,
  'yoga': Icons.self_improvement,
  'shirt': Icons.checkroom,
  'coffee': Icons.coffee_outlined,
  'focus': Icons.center_focus_strong_outlined,
  'pause': Icons.pause_circle_outline,
  'book': Icons.menu_book_outlined,
  'bowl': Icons.rice_bowl_outlined,
  'bookmark': Icons.bookmark_border,
  'moon': Icons.bedtime_outlined,
  'walk': Icons.directions_walk,
};

const Map<String, String> activityIconNames = {
  'sun': 'Sunrise',
  'water': 'Water',
  'yoga': 'Yoga',
  'shirt': 'Clothes',
  'coffee': 'Coffee',
  'focus': 'Focus',
  'pause': 'Pause',
  'book': 'Book',
  'bowl': 'Meal',
  'bookmark': 'Bookmark',
  'moon': 'Moon',
  'walk': 'Walk',
};

IconData activityIcon(String key) => activityIcons[key] ?? Icons.center_focus_strong_outlined;

/// Rounded square holding an icon: 36 in lists, 40 for "up next", 44 on the
/// Now card.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.size = 44, this.active = false, this.radius});

  IconTile.activity(String iconKey, {super.key, this.size = 44, this.active = false, this.radius})
      : icon = activityIcon(iconKey);

  final IconData icon;
  final double size;

  /// Primary tint instead of neutral.
  final bool active;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : AppColors.subtle,
          borderRadius: BorderRadius.circular(radius ?? (size <= 36 ? Rad.tileSm : Rad.control)),
        ),
        child: Icon(
          icon,
          size: size <= 36 ? 18 : size * .5,
          color: active ? AppColors.primary : AppColors.label,
        ),
      ),
    );
  }
}
