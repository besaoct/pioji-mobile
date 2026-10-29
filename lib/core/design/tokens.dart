import 'package:flutter/material.dart';

/// Palette 9 "Assam green iOS". The only place colour values live.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.fill,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.separator,
    required this.accent,
    required this.accentFill,
    required this.onAccent,
    required this.accentTint,
    required this.success,
    required this.warning,
    required this.danger,
    required this.dangerFill,
    required this.barDeep,
    required this.cardShadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color fill;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color separator;
  final Color accent;
  final Color accentFill;
  final Color onAccent;
  final Color accentTint;
  final Color success;
  final Color warning;
  final Color danger;
  final Color dangerFill;

  /// Bottom edge colour of the tab bar shadow.
  final Color barDeep;
  final List<BoxShadow> cardShadow;

  static const light = AppColors(
    background: Color(0xFFF0F3F1),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    fill: Color(0x1F768079),
    textPrimary: Color(0xFF121815),
    textSecondary: Color(0xFF4F5853),
    textTertiary: Color(0xFF6B756F),
    separator: Color(0xFFE2E7E4),
    accent: Color(0xFF1F5A43),
    accentFill: Color(0xFF1F5A43),
    onAccent: Color(0xFFFFFFFF),
    accentTint: Color(0x141F5A43),
    success: Color(0xFF2E7D4F),
    warning: Color(0xFF9A6200),
    danger: Color(0xFFB3261E),
    dangerFill: Color(0xFFB3261E),
    barDeep: Color(0xFFC9D3CD),
    cardShadow: AppShadow.card,
  );

  static const dark = AppColors(
    background: Color(0xFF0A0D0B),
    surface: Color(0xFF181D1A),
    surfaceRaised: Color(0xFF222824),
    fill: Color(0xFF3A423D),
    textPrimary: Color(0xFFEEF3F0),
    textSecondary: Color(0xFFABB5AF),
    textTertiary: Color(0xFF87918B),
    separator: Color(0xFF28302C),
    accent: Color(0xFF4FB487),
    accentFill: Color(0xFF237A57),
    onAccent: Color(0xFFFFFFFF),
    accentTint: Color(0x244FB487),
    success: Color(0xFF4CC27F),
    warning: Color(0xFFE5B040),
    danger: Color(0xFFFF6B60),
    dangerFill: Color(0xFFB3261E),
    barDeep: Color(0xFF000000),
    cardShadow: AppShadow.none,
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(covariant AppColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

abstract final class AppSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Horizontal screen gutter.
  static const screenH = 16.0;

  /// Minimum tap target and list row height.
  static const rowMinH = 48.0;
}

abstract final class AppRadius {
  static const control = 11.0;
  static const card = 14.0;
  static const sheet = 20.0;
  static const tile = 7.0;

  static const controlBorder =
      RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(control)));
  static const cardBorder =
      RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(card)));
}

abstract final class AppShadow {
  static const card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x09000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const none = <BoxShadow>[];
}
