import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/liturgy_music_search.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

/// Mesmos casos de app: src/modules/liturgy/__tests__/liturgy-music-search.test.ts
Hymn option(
  int id,
  String title, {
  String albumNames = 'Coletânea Teste',
  List<int> hymnalTracks = const [],
  String? lyric,
}) => Hymn(
  id: id,
  title: title,
  albumNames: albumNames,
  hymnalTracks: hymnalTracks,
  lyric: lyric,
);

final catalog = [
  option(
    1285,
    'A Única Esperança',
    lyric:
        'Há um só Deus Uma verdade, uma missão Há um clamor no mundo Por salvação',
  ),
  option(82, 'Medley - Quão Bom/Satisfação', hymnalTracks: const [82]),
  option(
    2179,
    'Sangue Precioso De Cristo',
    lyric: 'Só Cristo pode salvar o pecador',
  ),
  option(500, 'Missao Para Todos', albumNames: 'Importações .slja'),
  option(
    424,
    'Sublime Graça',
    hymnalTracks: const [424],
    lyric: 'Maravilhosa graça',
  ),
];

void main() {
  group('normalize', () {
    test('remove acentos, pontuação e normaliza case', () {
      expect(
        LiturgyMusicSearch.normalize('  A Única, Esperança! '),
        'a unica esperanca',
      );
    });
  });

  group('levenshteinWithin', () {
    test('distância dentro do limite', () {
      expect(
        LiturgyMusicSearch.levenshteinWithin('esperansa', 'esperanca', 1),
        isTrue,
      );
      expect(
        LiturgyMusicSearch.levenshteinWithin('kitten', 'sitten', 1),
        isTrue,
      );
    });
    test('distância acima do limite', () {
      expect(
        LiturgyMusicSearch.levenshteinWithin('esperansa', 'esperanca', 0),
        isFalse,
      );
      expect(LiturgyMusicSearch.levenshteinWithin('abc', 'xyz', 1), isFalse);
    });
  });

  group('search', () {
    test(
      "fuzzy troca de letras: 'unica esperansa' acha 'A Única Esperança'",
      () {
        expect(
          LiturgyMusicSearch.search(catalog, 'unica esperansa').first.id,
          1285,
        );
      },
    );

    test("ordem das palavras não importa: 'Esperança unica'", () {
      expect(
        LiturgyMusicSearch.search(catalog, 'Esperança unica').first.id,
        1285,
      );
    });

    test('ranking título > número > letra', () {
      expect(LiturgyMusicSearch.search(catalog, '424').first.id, 424);
      expect(LiturgyMusicSearch.search(catalog, 'graça').first.id, 424);
    });

    test("trecho da letra acha a música ('só Cristo')", () {
      final results = LiturgyMusicSearch.search(catalog, 'só Cristo');
      expect(results.any((h) => h.id == 2179), isTrue);
    });

    test('busca exata em título continua funcionando', () {
      expect(LiturgyMusicSearch.search(catalog, 'Missao').first.id, 500);
    });

    test('coletânea também é buscada', () {
      expect(LiturgyMusicSearch.search(catalog, 'slja').first.id, 500);
    });

    test('query vazia não retorna nada', () {
      expect(LiturgyMusicSearch.search(catalog, '   '), isEmpty);
    });

    test('sem letra indexada, música não quebra a busca', () {
      expect(LiturgyMusicSearch.search(catalog, 'Medley').first.id, 82);
    });

    test('limita a 50 resultados', () {
      final many = [
        for (var i = 0; i < 80; i++) option(10000 + i, 'Hino Esperança $i'),
      ];
      expect(LiturgyMusicSearch.search(many, 'Esperança'), hasLength(50));
    });

    test('número: hinário atual antes do 1996 e mostra o número buscado', () {
      final hymnals = [
        option(1, 'Do hinário de 1996', hymnalTracks: const [300, 12]),
        option(2, 'Do hinário atual', hymnalTracks: const [12, 400]),
      ];
      final results = LiturgyMusicSearch.search(hymnals, '12');
      expect(results.map((h) => h.id), [2, 1]);
      expect(results.map((h) => h.number), [12, 12]);
    });
  });
}
