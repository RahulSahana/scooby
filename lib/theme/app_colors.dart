import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color cardColor;
  final Color primary;
  final Color secondary;
  final Color primaryText;
  final Color secondaryText;
  final Color accentIcon;
  final Color warningAmber;
  final Color warningSurface;
  final Color criticalRed;
  final Color criticalSurface;
  final Color cardBorder;
  final Color nightInk;

  const AppColors({
    required this.background,
    required this.cardColor,
    required this.primary,
    required this.secondary,
    required this.primaryText,
    required this.secondaryText,
    required this.accentIcon,
    required this.warningAmber,
    required this.warningSurface,
    required this.criticalRed,
    required this.criticalSurface,
    required this.cardBorder,
    required this.nightInk,
  });

  static const light = AppColors(
    background: Color(0xFFF4F7F6),
    cardColor: Color(0xFFFFFFFF),
    primary: Color(0xFF00897B),
    secondary: Color(0xFF3479C9),
    primaryText: Color(0xFF111827),
    secondaryText: Color(0xFF64748B),
    accentIcon: Color(0xFF00897B),
    warningAmber: Color(0xFFF59E0B),
    warningSurface: Color(0xFFFEF3C7),
    criticalRed: Color(0xFFDC3D36),
    criticalSurface: Color(0xFFFEE2E2),
    cardBorder: Color(0xFFE5ECE9),
    nightInk: Color(0xFF142B3B),
  );

  static const dark = AppColors(
    background: Color(0xFF0E1722),
    cardColor: Color(0xFF162334),
    primary: Color(0xFF2DD4BF),
    secondary: Color(0xFF78AFFF),
    primaryText: Color(0xFFF8FAFC),
    secondaryText: Color(0xFF94A3B8),
    accentIcon: Color(0xFF2DD4BF),
    warningAmber: Color(0xFFFBBF24),
    warningSurface: Color(0xFF322514),
    criticalRed: Color(0xFFF87171),
    criticalSurface: Color(0xFF381A1C),
    cardBorder: Color(0xFF223347),
    nightInk: Color(0xFF111E2E),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? cardColor,
    Color? primary,
    Color? secondary,
    Color? primaryText,
    Color? secondaryText,
    Color? accentIcon,
    Color? warningAmber,
    Color? warningSurface,
    Color? criticalRed,
    Color? criticalSurface,
    Color? cardBorder,
    Color? nightInk,
  }) {
    return AppColors(
      background: background ?? this.background,
      cardColor: cardColor ?? this.cardColor,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      accentIcon: accentIcon ?? this.accentIcon,
      warningAmber: warningAmber ?? this.warningAmber,
      warningSurface: warningSurface ?? this.warningSurface,
      criticalRed: criticalRed ?? this.criticalRed,
      criticalSurface: criticalSurface ?? this.criticalSurface,
      cardBorder: cardBorder ?? this.cardBorder,
      nightInk: nightInk ?? this.nightInk,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;

    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      accentIcon: Color.lerp(accentIcon, other.accentIcon, t)!,
      warningAmber: Color.lerp(warningAmber, other.warningAmber, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      criticalRed: Color.lerp(criticalRed, other.criticalRed, t)!,
      criticalSurface: Color.lerp(criticalSurface, other.criticalSurface, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      nightInk: Color.lerp(nightInk, other.nightInk, t)!,
    );
  }
}