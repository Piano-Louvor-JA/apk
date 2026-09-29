/// Utilidades de contraste WCAG 2.1 para o tema light.
///
/// O primary do accent (ex: #2196F3) tem 2.97:1 sobre a surface clara —
/// abaixo do minimo AA (4.5:1) para texto. [ensureReadableOnLight] escurece
/// a cor (mesma matiz) ate atingir o minimo.
library;

import 'dart:math' as math;
import 'dart:ui';

// ignore: unnecessary_import
import 'package:flutter/painting.dart' show HSVColor;

/// Luminancia relativa WCAG de uma cor.
double _luminance(Color c) {
  double lin(int v) {
    final s = v / 255.0;
    return s <= 0.04045
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  int chan(double d) => (d * 255.0).round().clamp(0, 255);
  return 0.2126 * lin(chan(c.r)) +
      0.7152 * lin(chan(c.g)) +
      0.0722 * lin(chan(c.b));
}

/// Razao de contraste WCAG entre duas cores (1..21).
double contrastRatio(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/// Escurece [color] (reduzindo value no HSV, mesma matiz) ate atingir
/// [minRatio] sobre [background]. Retorna inalterada se ja passa.
Color ensureReadableOnLight(
  Color color, {
  Color background = const Color(0xFFF8F9FF),
  double minRatio = 4.5,
}) {
  if (contrastRatio(color, background) >= minRatio) return color;

  final hsv = HSVColor.fromColor(color);
  var best = color;
  for (var v = hsv.value; v >= 0.0; v -= 0.01) {
    final candidate = hsv.withValue(v).toColor();
    best = candidate;
    if (contrastRatio(candidate, background) >= minRatio) break;
  }
  return best;
}
