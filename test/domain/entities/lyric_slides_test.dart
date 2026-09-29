import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/lyric_slides.dart';

void main() {
  group('LyricSlide.parseTime', () {
    test('HH:MM:SS padrão', () {
      expect(LyricSlide.parseTime('00:00:08'), Duration(seconds: 8));
      expect(
        LyricSlide.parseTime('00:01:30'),
        Duration(minutes: 1, seconds: 30),
      );
      expect(
        LyricSlide.parseTime('01:05:30'),
        Duration(hours: 1, minutes: 5, seconds: 30),
      );
    });

    test('MM:SS (sem horas)', () {
      expect(LyricSlide.parseTime('01:30'), Duration(minutes: 1, seconds: 30));
      expect(LyricSlide.parseTime('00:08'), Duration(seconds: 8));
      expect(LyricSlide.parseTime('05:00'), Duration(minutes: 5));
    });

    test('HH:MM:SS.ss (com fração de segundo)', () {
      expect(LyricSlide.parseTime('00:00:08.5'), Duration(milliseconds: 8500));
      expect(
        LyricSlide.parseTime('00:01:30.250'),
        Duration(minutes: 1, seconds: 30, milliseconds: 250),
      );
    });

    test('MM:SS.ss (com fração de segundo)', () {
      expect(
        LyricSlide.parseTime('01:30.5'),
        Duration(minutes: 1, seconds: 30, milliseconds: 500),
      );
    });

    test('numérico puro (segundos)', () {
      expect(LyricSlide.parseTime('8'), Duration(seconds: 8));
      expect(LyricSlide.parseTime('90'), Duration(seconds: 90));
      expect(LyricSlide.parseTime('0'), Duration.zero);
      expect(LyricSlide.parseTime('8.5'), Duration(milliseconds: 8500));
    });

    test('null e vazio', () {
      expect(LyricSlide.parseTime(null), isNull);
      expect(LyricSlide.parseTime(''), isNull);
    });

    test('numérico puro é válido (segundos)', () {
      expect(LyricSlide.parseTime('01'), Duration(seconds: 1));
    });

    test('intervalo com 4 partes não parseia', () {
      expect(LyricSlide.parseTime('00:00:00:00'), isNull);
    });
  });

  group('LyricSlides.indexAt', () {
    test('timestamps em MM:SS sincronizam', () {
      final slides = LyricSlides([
        LyricSlide.cover(title: 'Test'),
        LyricSlide(text: 'V1', time: Duration(seconds: 10), order: 1),
        LyricSlide(text: 'V2', time: Duration(seconds: 30), order: 2),
        LyricSlide(text: 'V3', time: Duration(minutes: 1), order: 3),
      ]);
      expect(slides.indexAt(Duration.zero), 0);
      expect(slides.indexAt(Duration(seconds: 5)), 0);
      expect(slides.indexAt(Duration(seconds: 10)), 1);
      expect(slides.indexAt(Duration(seconds: 25)), 1);
      expect(slides.indexAt(Duration(seconds: 30)), 2);
      expect(slides.indexAt(Duration(seconds: 60)), 3);
    });

    test('sem timestamps retorna sempre 0', () {
      final slides = LyricSlides([
        LyricSlide.cover(title: 'Test'),
        LyricSlide(text: 'V1', order: 1),
        LyricSlide(text: 'V2', order: 2),
      ]);
      expect(slides.indexAt(Duration(seconds: 30)), 0);
      expect(slides.indexAt(Duration(minutes: 5)), 0);
    });
  });
}
