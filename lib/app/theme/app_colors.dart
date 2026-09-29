/// Cores do design system LouvorJA PIANO.
///
/// Fonte: pianolouvorja/app/src/design-system/tokens/colors.ts
/// Tradução 1:1 dos tokens TypeScript/CSS para Flutter.
library;

import 'package:flutter/material.dart';

/// Cores de marca (fixas, não mudam com tema).
abstract final class AppBrandColors {
  /// Azul de ação / destaque.
  static const Color primary = Color(0xFF2196F3);

  /// Texto de marca em dark mode.
  static const Color primarySoft = Color(0xFF9ECAFF);

  /// Verde-água secundário.
  static const Color secondary = Color(0xFF78D6D2);

  /// Variante de azul.
  static const Color brandBlueAlt = Color(0xFF0097D7);

  /// Amarelo do logo oficial.
  static const Color brandYellow = Color(0xFFF8C800);
}

/// Cores do tema "Ethereal Lumens" (dark, padrão).
abstract final class EtherealLumensColors {
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceElevated = Color(0xFF1E1E1E);
  static const Color surfaceCard = Color(0xFF242424);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceVariant = Color(0xFF353534);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFBFC7D4);
  static const Color onPrimary = Color(0xFF003258);
  static const Color outline = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const Color outlineStrong = Color(
    0x1AFFFFFF,
  ); // rgba(255,255,255,0.10)
  static const Color tertiary = Color(0xFFFFB77B);
}

/// Cores do tema "Luminous Clarity" (light).
abstract final class LuminousClarityColors {
  static const Color background = Color(0xFFF8F9FF);
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFEEEEEF);
  static const Color surfaceContainerHigh = Color(0xFFE8E8EA);
  static const Color surfaceVariant = Color(0xFFDFE3EB);
  static const Color onSurface = Color(0xFF191C20);
  static const Color onSurfaceVariant = Color(0xFF43474E);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color outline = Color(0x0F000000); // rgba(0,0,0,0.06)
  static const Color outlineStrong = Color(0x1A000000); // rgba(0,0,0,0.10)
  static const Color primarySoft = Color(0xFF0061A4);
  static const Color secondary = Color(0xFF008F8B);
  static const Color tertiary = Color(0xFF6D3900);
}
