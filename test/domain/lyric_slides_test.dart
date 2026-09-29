library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/lyric_slides.dart';

void main() {
  group('LyricSlides (espelho Media.js)', () {
    test('monta capa + estrofes com times e carry-over de imagem', () {
      final slides = LyricSlides.fromApi(
        musicName: 'Nosso Sol é Jesus',
        coverUrl: '/images/capa.jpg',
        raw: [
          {
            'lyric': 'O nosso sol\r\nVeio iluminar',
            'time': '00:00:08',
            'instrumental_time': '00:00:10',
            'url_image': '/images/hasd_132B.jpg',
            'show_slide': '1',
            'order': '1',
          },
          {
            'lyric': 'O caminho que\r\nvamos andar',
            'time': '00:00:17',
            'instrumental_time': '00:00:19',
            'url_image': null, // herda a anterior
            'show_slide': '1',
            'order': '3',
          },
          {
            'lyric': 'Slide oculto',
            'time': '00:00:25',
            'show_slide': '0', // fora
            'order': '2',
          },
        ],
      );

      expect(slides.slides, hasLength(3)); // capa + 2 visíveis
      // Capa primeiro
      expect(slides.slides.first.text, 'Nosso Sol é Jesus');
      expect(slides.slides.first.time, Duration.zero);
      // Ordenação por order (1 antes de 3), oculto removido
      expect(slides.slides[1].order, 1);
      expect(slides.slides[1].time, const Duration(seconds: 8));
      expect(slides.slides[1].instrumentalTime, const Duration(seconds: 10));
      // Carry-over: slide 2 sem imagem herda hasd_132B
      expect(slides.slides[2].imageUrl, '/images/hasd_132B.jpg');
      expect(slides.slides[2].time, const Duration(seconds: 17));
    });

    test('indexAt sincroniza posição do áudio ao slide certo', () {
      final slides = LyricSlides.fromApi(
        musicName: 'M',
        raw: const [
          {'lyric': 'A', 'time': '00:00:08', 'show_slide': '1', 'order': '1'},
          {'lyric': 'B', 'time': '00:00:17', 'show_slide': '1', 'order': '2'},
        ],
      );

      expect(slides.indexAt(const Duration(seconds: 2)), 0); // capa
      expect(slides.indexAt(const Duration(seconds: 9)), 1); // A
      expect(slides.indexAt(const Duration(seconds: 20)), 2); // B
    });

    test('indexAt instrumental usa instrumental_time', () {
      final slides = LyricSlides.fromApi(
        musicName: 'M',
        raw: const [
          {
            'lyric': 'A',
            'time': '00:00:08',
            'instrumental_time': '00:00:30',
            'show_slide': '1',
            'order': '1',
          },
        ],
      );

      // 10s no cantado já trocou; no instrumental ainda é capa
      expect(slides.indexAt(const Duration(seconds: 10)), 1);
      expect(
        slides.indexAt(const Duration(seconds: 10), instrumental: true),
        0,
      );
    });

    test('parseTime aceita formatos da API e rejeita lixo', () {
      expect(LyricSlide.parseTime('00:00:34'), const Duration(seconds: 34));
      expect(
        LyricSlide.parseTime('00:02:17'),
        const Duration(minutes: 2, seconds: 17),
      );
      expect(LyricSlide.parseTime(null), isNull);
      expect(LyricSlide.parseTime(''), isNull);
      expect(LyricSlide.parseTime('abc'), isNull);
    });
  });
}
