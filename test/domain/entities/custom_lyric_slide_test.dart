import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_lyric_slide.dart';

void main() {
  test('CustomLyricSlide aceita JSON completo e round-trip', () {
    final slide = CustomLyricSlide.fromJson({
      'id_lyric': 7.0,
      'lyric': 'Primeira linha',
      'aux_lyric': 'Apoio',
      'time': '01:02.003',
      'order': 2.0,
    });

    expect(slide.id, 7);
    expect(slide.text, 'Primeira linha');
    expect(slide.toJson(), {
      'id_lyric': 7,
      'lyric': 'Primeira linha',
      'aux_lyric': 'Apoio',
      'time': '01:02.003',
      'order': 2,
    });
  });

  test('CustomLyricSlide defaulta dados legados ausentes', () {
    final slide = CustomLyricSlide.fromJson({});
    expect(slide.id, 0);
    expect(slide.text, isEmpty);
    expect(slide.order, 0);
    expect(slide.toJson().containsKey('aux_lyric'), isFalse);
    expect(slide.toJson().containsKey('time'), isFalse);
  });

  test('split e background respeitam blocos, override e herança', () {
    expect(
      CustomLyricSlide.splitIntoSlides(' A\n\n\n B \n \n   \nC '),
      ['A', 'B', 'C'],
    );
    expect(effectiveSlideBg<String>({0: 'capa'}, 3), 'capa');
    expect(effectiveSlideBg<String>({0: 'capa', 3: 'ponte'}, 3), 'ponte');
    expect(effectiveSlideBg<String>({}, 0), isNull);
  });

  test('msToDbTime formata minuto, segundo e milissegundo', () {
    expect(msToDbTime(0), '00:00.000');
    expect(msToDbTime(62003), '01:02.003');
  });
}
