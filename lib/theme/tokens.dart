import 'package:flutter/material.dart';

/// Design tokens (REQUIREMENTS §8). Light theme only in v1; a dark theme is a
/// swap of [AppColors].
abstract final class AppColors {
  static const bg = Color(0xFFF6F8FB);
  static const surface = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFF1F4F8);
  static const track = Color(0xFFEEF1F5);
  static const border = Color(0xFFE7EBF0);
  static const borderStrong = Color(0xFFC9D0DB);

  static const text = Color(0xFF172033);
  static const label = Color(0xFF475467);
  static const text2 = Color(0xFF667085);

  /// Icons / disabled only — never readable copy.
  static const text3 = Color(0xFF98A2B3);

  static const primary = Color(0xFF3D6BE0);
  static const primaryPressed = Color(0xFF2F5BCB);
  static const primarySoft = Color(0xFFEDF3FF);
  static const primaryRing = Color(0xFFDCE6FD);
  static const primaryMuted = Color(0xFF8FA9EE);

  static const success = Color(0xFF34A36F);
  static const successInk = Color(0xFF1F7A52);
  static const successSoft = Color(0xFFEAF6EF);

  static const warning = Color(0xFFDFA247);
  static const warningInk = Color(0xFFA86A12);
  static const warningSoft = Color(0xFFFCF3E3);

  /// Selected "Partially completed" option row fill.
  static const warningTint = Color(0xFFFFFBF3);

  static const danger = Color(0xFFD9646A);
  static const dangerInk = Color(0xFFB9474D);
  static const dangerSoft = Color(0xFFFBEDEE);

  static const scrim = Color(0x52172033); // rgba(23,32,51,.32)

  /// Sheet grabber and switch "off" track.
  static const handle = Color(0xFFD5DAE1);

  /// Note field fill inside sheets.
  static const inputTint = Color(0xFFF9FAFC);

  static const toastBg = text;
  static const toastAction = Color(0xFF9DB8FF);
  static const onPrimary = Color(0xFFFFFFFF);

  // Buddy face details (§9.7).
  static const buddyInk = text;
  static const buddyCheek = Color(0xCCF4B4B8); // #F4B4B8 at 80 %
  static const buddyTongue = Color(0xFFE8838A);
  static const buddyTear = Color(0xFF7FA3EE);
}

/// Spacing scale.
abstract final class Sp {
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x28 = 28;
  static const double x32 = 32;

  /// Screen side padding.
  static const double screen = x20;
}

/// Corner radii.
abstract final class Rad {
  static const double tag = 6;
  static const double segment = 9;
  static const double tileSm = 10;
  static const double control = 12;
  static const double row = 14;
  static const double group = 16;
  static const double card = 20;
  static const double sheet = 28;
  static const double pill = 999;

  static const BorderRadius controlAll = BorderRadius.all(Radius.circular(control));
  static const BorderRadius rowAll = BorderRadius.all(Radius.circular(row));
  static const BorderRadius groupAll = BorderRadius.all(Radius.circular(group));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

abstract final class Shadows {
  /// Segment thumb, switch knob.
  static const s1 = [
    BoxShadow(color: Color(0x0F101828), offset: Offset(0, 1), blurRadius: 2),
  ];

  /// Now card only.
  static const s2 = [
    BoxShadow(color: Color(0x0D101828), offset: Offset(0, 6), blurRadius: 24),
  ];

  /// Sheets.
  static const s3 = [
    BoxShadow(color: Color(0x14101828), offset: Offset(0, -8), blurRadius: 32),
  ];
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const pop = Duration(milliseconds: 220);
  static const sheetIn = Duration(milliseconds: 240);
  static const sheetOut = Duration(milliseconds: 180);
  static const bubble = Duration(milliseconds: 260);
  static const bubbleDelay = Duration(milliseconds: 120);
  static const progress = Duration(milliseconds: 400);
  static const toast = Duration(milliseconds: 3200);

  static const curve = Cubic(.2, .8, .2, 1);
  static const exit = Cubic(.4, 0, 1, 1);

  /// True when the user asked the system to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Text styles (Geist).
abstract final class AppText {
  static const family = 'Geist';
  static const tabular = [FontFeature.tabularFigures()];

  static const _base = TextStyle(
    fontFamily: family,
    color: AppColors.text,
    fontWeight: FontWeight.w400,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle _s(double size, double line, {FontWeight? w, double? ls, Color? c}) =>
      _base.copyWith(
        fontSize: size,
        height: line / size,
        fontWeight: w,
        letterSpacing: ls == null ? null : ls * size,
        color: c,
      );

  static final stat = _s(48, 52, w: FontWeight.w600, ls: -.03).copyWith(fontFeatures: tabular);
  static final heading = _s(28, 34, w: FontWeight.w600, ls: -.02);
  static final title = _s(22, 28, w: FontWeight.w600, ls: -.01);
  static final sheetTitle = _s(20, 26, w: FontWeight.w600);
  static final navTitle = _s(17, 22, w: FontWeight.w600);
  static final body = _s(16, 22);
  static final bodyMedium = _s(16, 22, w: FontWeight.w500);
  static final bodySm = _s(15, 22);
  static final secondary = _s(14, 20, c: AppColors.text2);
  static final section = _s(13, 16, w: FontWeight.w600, ls: .06, c: AppColors.text2);
  static final meta = _s(13, 18, c: AppColors.text2);
  static final fieldLabel = _s(13, 16, w: FontWeight.w500, c: AppColors.label);
  static final caption = _s(12, 14, w: FontWeight.w500);
  static final button = _s(16, 22, w: FontWeight.w600);
  static final buttonSm = _s(15, 20, w: FontWeight.w500);
  static final chip = _s(13, 16, w: FontWeight.w500);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.danger,
    outline: AppColors.border,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppText.family,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textTheme: TextTheme(
      displaySmall: AppText.stat,
      headlineMedium: AppText.heading,
      titleLarge: AppText.title,
      titleMedium: AppText.navTitle,
      bodyLarge: AppText.body,
      bodyMedium: AppText.bodySm,
      bodySmall: AppText.meta,
      labelLarge: AppText.button,
      labelSmall: AppText.caption,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: AppColors.primaryRing,
      selectionHandleColor: AppColors.primary,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: AppColors.scrim,
      dragHandleColor: AppColors.handle,
      dragHandleSize: Size(36, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.sheet)),
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: Rad.cardAll),
      hourMinuteShape: const RoundedRectangleBorder(borderRadius: Rad.controlAll),
      dayPeriodShape: const RoundedRectangleBorder(borderRadius: Rad.controlAll),
      dialBackgroundColor: AppColors.subtle,
      helpTextStyle: AppText.fieldLabel,
    ),
  );
}
