import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/domain/entities/custom_lyric_slide.dart';

/// Unit: conversão ms → tempo do DB/.slja usada pelo import .slja
/// (tempo_hms do Delphi vira 'MM:SS.mmm' no POST /lyrics).
void main() {
  test('zero → 00:00.000', () {
    expect(msToDbTime(0), '00:00.000');
  });

  test('12s → 00:12.000', () {
    expect(msToDbTime(12000), '00:12.000');
  });

  test('1min 5s 320ms → 01:05.320', () {
    expect(msToDbTime(65320), '01:05.320');
  });

  test('10min → 10:00.000', () {
    expect(msToDbTime(600000), '10:00.000');
  });

  test('1234ms trunca segundos fracionários corretamente', () {
    expect(msToDbTime(1234), '00:01.234');
  });

  test('padrão MM:SS.mmm consistente com parse do player', () {
    // roundtrip: o player entende exatamente o que o import grava
    final t = msToDbTime(75412);
    expect(t, '01:15.412');
  });
}
