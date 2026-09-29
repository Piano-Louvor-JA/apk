library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/app/theme/contrast.dart';
import 'package:flutter/material.dart';

void main() {
  group('Contrast.ensureReadableOnLight', () {
    test('primary #2196F3 (2.97:1) e escurecido ate >= 4.5:1', () {
      const primary = Color(0xFF2196F3);
      final fixed = ensureReadableOnLight(primary);
      // O resultado deve ter contraste >= 4.5 com a surface clara F8F9FF
      expect(fixed, isNot(equals(primary)));
    });

    test('cor ja acessivel (#0061A4) permanece inalterada', () {
      const ok = Color(0xFF0061A4);
      expect(ensureReadableOnLight(ok), equals(ok));
    });

    test('resultado sempre atinge 4.5:1 sobre F8F9FF', () {
      for (final c in [
        const Color(0xFF2196F3),
        const Color(0xFF5B9BD5),
        const Color(0xFF4DB6AC),
        const Color(0xFFE0A84A),
      ]) {
        final fixed = ensureReadableOnLight(c);
        final ratio = contrastRatio(fixed, const Color(0xFFF8F9FF));
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'cor ${c.toARGB32().toRadixString(16)} ficou $ratio',
        );
      }
    });

    test('nao distorce demais: continua na mesma matiz', () {
      const primary = Color(0xFF2196F3);
      final fixed = ensureReadableOnLight(primary);
      final h1 = HSVColor.fromColor(primary).hue;
      final h2 = HSVColor.fromColor(fixed).hue;
      expect((h1 - h2).abs(), lessThan(15));
    });
  });
}
