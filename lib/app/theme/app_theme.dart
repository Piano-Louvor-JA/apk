/// ThemeData do app — temas dark e light baseados no design system.
///
/// Fonte: pianolouvorja/app/src/design-system/themes/ethereal.ts + luminous.ts
library;

import 'contrast.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_accents.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  /// Tema "Ethereal Lumens" (dark, padrão).
  static ThemeData dark({AccentColor accent = AppAccents.defaultAccent}) {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: accent.primary,
      onPrimary: EtherealLumensColors.onPrimary,
      secondary: accent.soft,
      onSecondary: EtherealLumensColors.onSurface,
      surface: EtherealLumensColors.surface,
      onSurface: EtherealLumensColors.onSurface,
      surfaceContainerHighest: EtherealLumensColors.surfaceElevated,
      surfaceContainerHigh: EtherealLumensColors.surfaceContainerHigh,
      surfaceContainerLow: EtherealLumensColors.surfaceContainer,
      surfaceContainer: EtherealLumensColors.surfaceCard,
      surfaceContainerLowest: EtherealLumensColors.background,
      onSurfaceVariant: EtherealLumensColors.onSurfaceVariant,
      outline: EtherealLumensColors.outline,
      outlineVariant: EtherealLumensColors.outlineStrong,
      error: const Color(0xFFCF6679),
      onError: const Color(0xFF690005),
    );

    return _baseTheme(colorScheme, Brightness.dark);
  }

  /// Tema "Luminous Clarity" (light).
  static ThemeData light({AccentColor accent = AppAccents.defaultAccent}) {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      // WCAG AA: primary do accent pode ter < 4.5:1 sobre surface clara
      // (ex: #2196F3 = 2.97:1) — escurece preservando a matiz ate passar.
      primary: ensureReadableOnLight(accent.primary),
      onPrimary: LuminousClarityColors.onPrimary,
      secondary: LuminousClarityColors.secondary,
      onSecondary: LuminousClarityColors.onSurface,
      surface: LuminousClarityColors.surface,
      onSurface: LuminousClarityColors.onSurface,
      surfaceContainerHighest: LuminousClarityColors.surfaceElevated,
      surfaceContainerHigh: LuminousClarityColors.surfaceContainerHigh,
      surfaceContainerLow: LuminousClarityColors.surfaceContainer,
      surfaceContainer: LuminousClarityColors.surfaceCard,
      surfaceContainerLowest: LuminousClarityColors.background,
      onSurfaceVariant: LuminousClarityColors.onSurfaceVariant,
      outline: LuminousClarityColors.outline,
      outlineVariant: LuminousClarityColors.outlineStrong,
      error: const Color(0xFFB3261E),
      onError: const Color(0xFFFFFFFF),
    );

    return _baseTheme(colorScheme, Brightness.light);
  }

  static ThemeData _baseTheme(ColorScheme scheme, Brightness brightness) {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: AppRadius.sm,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.sm,
          borderSide: BorderSide(color: scheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSpacing.navBarHeight,
        backgroundColor: scheme.surfaceContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(9999),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFF929292);
          }
          return const Color(0xFF7A7A7A);
        }),
        trackColor: const WidgetStatePropertyAll(Color(0xFF282828)),
      ),
    );
  }
}
