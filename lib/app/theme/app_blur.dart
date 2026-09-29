/// Tokens de glass morphism / backdrop blur.
///
/// Fonte: pianolouvorja/app/src/design-system/tokens/blur.ts
///
/// Intensidade contínua do slider (0-100). Default: 60.
/// Fórmulas (replicadas do Electron):
///   blurPx = 4 + (intensity / 100) * 24  → range: 4-28px
///   fillAlpha = 42 + (intensity / 100) * 40 → range: 42%-82%
library;

abstract final class AppBlur {
  static const double defaultIntensity = 60;

  /// Converte intensidade 0-100 para sigma do BackdropFilter.
  static double blurSigma(double intensity) {
    return 4 + (intensity / 100) * 24;
  }

  /// Converte intensidade 0-100 para alpha do fill (0.0-1.0).
  static double fillAlpha(double intensity) {
    return (42 + (intensity / 100) * 40) / 100;
  }

  /// Limita intensidade entre 0 e 100.
  static double clamp(double value) {
    if (!value.isFinite) return defaultIntensity;
    return value.clamp(0, 100).roundToDouble();
  }
}
