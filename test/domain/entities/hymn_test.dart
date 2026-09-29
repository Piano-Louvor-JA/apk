library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

void main() {
  group('Hymn', () {
    group('parseDurationMs', () {
      test('número (segundos) → milissegundos', () {
        expect(Hymn.parseDurationMs(187.5), 187500);
        expect(Hymn.parseDurationMs(0), 0);
        expect(Hymn.parseDurationMs(60), 60000);
      });

      test('string numérica (segundos)', () {
        expect(Hymn.parseDurationMs('187.5'), 187500);
        expect(Hymn.parseDurationMs('60'), 60000);
      });

      test('formato MM:SS', () {
        expect(Hymn.parseDurationMs('3:07'), 187000);
        expect(Hymn.parseDurationMs('0:30'), 30000);
        expect(Hymn.parseDurationMs('10:00'), 600000);
      });

      test('formato HH:MM:SS', () {
        expect(Hymn.parseDurationMs('1:02:03'), 3723000);
        expect(Hymn.parseDurationMs('0:00:45'), 45000);
      });

      test('null ou vazio retorna null', () {
        expect(Hymn.parseDurationMs(null), isNull);
        expect(Hymn.parseDurationMs(''), isNull);
        expect(Hymn.parseDurationMs('   '), isNull);
      });

      test('formato inválido retorna null', () {
        expect(Hymn.parseDurationMs('abc'), isNull);
        expect(Hymn.parseDurationMs('x:y:z'), isNull);
      });
    });

    group('fromJson', () {
      test('campos principais com tipos numéricos', () {
        final h = Hymn.fromJson({
          'id_music': 42,
          'name': 'Coroai',
          'track': 1,
          'duration': 187.5,
          'has_instrumental_music': 1,
          'url_instrumental_music': '/musics/42.mp3',
        });

        expect(h.id, 42);
        expect(h.title, 'Coroai');
        expect(h.number, 1);
        expect(h.durationMs, 187500);
        expect(h.hasInstrumental, isTrue);
        expect(h.urlInstrumental, '/musics/42.mp3');
        expect(h.lyric, isNull);
      });

      test('fromJson le letra quando disponivel', () {
        final h = Hymn.fromJson({
          'id_music': 274,
          'name': 'Ó Deus de Amor',
          'track': 1,
          'lyric': 'Ó Deus de amor\r\nvimos nós Te adorar',
        });

        expect(h.lyric, contains('Ó Deus de amor'));
        expect(h.lyric, contains('vimos nós Te adorar'));
      });

      test('fromJson normaliza lista ordenada de estrofes da API music', () {
        final hymn = Hymn.fromJson({
          'id_music': 274,
          'name': 'Ó Deus de Amor',
          'lyric': [
            {'order': 4, 'show_slide': 1, 'lyric': 'Segunda estrofe'},
            {'order': 2, 'show_slide': 0, 'lyric': 'Não projetar'},
            {'order': 1, 'show_slide': 1, 'lyric': 'Primeira estrofe'},
            {'order': 5, 'show_slide': 1, 'lyric': ''},
          ],
        });

        expect(hymn.lyric, 'Primeira estrofe\n\nSegunda estrofe');
      });

      test(
        'fromJson retorna null quando lista de letra nao tem blocos visiveis',
        () {
          final hymn = Hymn.fromJson({
            'id_music': 1,
            'lyric': [
              {'order': 1, 'show_slide': 0, 'lyric': 'Oculta'},
              {'order': 2, 'show_slide': 1, 'lyric': ''},
            ],
          });

          expect(hymn.lyric, isNull);
        },
      );

      test('campos como string (compatibilidade)', () {
        final h = Hymn.fromJson({
          'id_music': '42',
          'name': 'Graças Dou',
          'track': '10',
          'duration': '3:30',
          'has_instrumental_music': 'true',
        });

        expect(h.id, 42);
        expect(h.number, 10);
        expect(h.durationMs, 210000);
        expect(h.hasInstrumental, isTrue);
      });

      test('has_instrumental false com 0', () {
        final h = Hymn.fromJson({'id_music': 1, 'has_instrumental_music': 0});
        expect(h.hasInstrumental, isFalse);
      });

      test('campos ausentes usam defaults', () {
        final h = Hymn.fromJson({'id_music': 99});
        expect(h.id, 99);
        expect(h.title, isNull);
        expect(h.number, isNull);
        expect(h.durationMs, isNull);
        expect(h.hasInstrumental, isFalse);
        expect(h.urlInstrumental, isNull);
      });
    });

    group('toJson', () {
      test('round-trip', () {
        final original = Hymn(
          id: 1,
          title: 'Teste',
          number: 5,
          durationMs: 180000,
          hasInstrumental: true,
          urlInstrumental: '/test.mp3',
          lyric: 'Letra de teste',
        );
        final json = original.toJson();
        final restored = Hymn.fromJson(json);
        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.number, original.number);
        expect(restored.hasInstrumental, original.hasInstrumental);
        expect(restored.lyric, original.lyric);
      });
    });

    group('formattedDuration', () {
      test('formato curto M:SS', () {
        expect(const Hymn(id: 0, durationMs: 187000).formattedDuration, '3:07');
        expect(const Hymn(id: 0, durationMs: 0).formattedDuration, '0:00');
      });

      test('formato longo H:MM:SS', () {
        expect(
          const Hymn(id: 0, durationMs: 3723000).formattedDuration,
          '1:02:03',
        );
      });

      test('sem duração retorna string vazia', () {
        expect(const Hymn(id: 0).formattedDuration, '');
      });
    });

    test('igualdade por id', () {
      expect(const Hymn(id: 1), const Hymn(id: 1));
      expect(const Hymn(id: 1) == const Hymn(id: 2), isFalse);
    });
  });
}
