library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/global_search_service.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

Hymn _hymn(int id, String? title, {int? number, String? lyric}) => Hymn(
  id: id,
  title: title,
  number: number,
  lyric: lyric,
  hasInstrumental: false,
);

void main() {
  group('GlobalSearchService.fuzzyScore', () {
    test('pontua 0 quando query vazia', () {
      final score = GlobalSearchService.fuzzyScore('', 'Qualquer Coisa');
      expect(score, 0);
    });

    test('pontua 0 quando alvo vazio', () {
      final score = GlobalSearchService.fuzzyScore('amor', '');
      expect(score, 0);
    });

    test('match exato de titulo tem score maior que match parcial', () {
      final exato = GlobalSearchService.fuzzyScore(
        'Cheio de Amor',
        'Cheio de Amor',
      );
      final parcial = GlobalSearchService.fuzzyScore(
        'Cheio de Amor',
        'Cheio de Amor (Reprise)',
      );
      expect(exato, greaterThan(parcial));
    });

    test('match no inicio do titulo pontua mais que no meio', () {
      final inicio = GlobalSearchService.fuzzyScore('Amor', 'Amor de Deus');
      final meio = GlobalSearchService.fuzzyScore('Amor', 'Grande Amor');
      expect(inicio, greaterThan(meio));
    });

    test('ignora acentos e caixa', () {
      final comAcento = GlobalSearchService.fuzzyScore(
        'coracao',
        'Coração Sagrado',
      );
      expect(comAcento, greaterThan(0));
    });
  });

  group('GlobalSearchService.searchHymns', () {
    test('retorna vazio com query curta', () {
      final service = GlobalSearchService();
      expect(service.searchHymns('am', hymns: const []), isEmpty);
    });

    test('busca por numero retorna hino correspondente', () {
      final service = GlobalSearchService();
      final hymns = [_hymn(1, 'Louvor ao Senhor', number: 100)];
      final results = service.searchHymns('100', hymns: hymns);
      expect(results, hasLength(1));
      expect((results.first.item as Hymn).id, 1);
    });

    test('busca por titulo normaliza acentos', () {
      final service = GlobalSearchService();
      final hymns = [_hymn(2, 'Coração Sagrado')];
      final results = service.searchHymns('coracao', hymns: hymns);
      expect(results, hasLength(1));
    });

    test('busca por trecho de letra encontra hino', () {
      final service = GlobalSearchService();
      final hymns = [
        _hymn(3, 'Hino A', lyric: 'Jesus me ama, sim ele ama'),
        _hymn(4, 'Hino B', lyric: 'Outra letra qualquer'),
      ];
      final results = service.searchHymns('jesus me ama', hymns: hymns);
      expect(results, hasLength(1));
      expect((results.first.item as Hymn).id, 3);
    });

    test('resultados ordenados por score desc', () {
      final service = GlobalSearchService();
      final hymns = [_hymn(5, 'Grande Amor'), _hymn(6, 'Amor')];
      final results = service.searchHymns('Amor', hymns: hymns);
      expect((results.first.item as Hymn).id, 6);
    });

    test('limita resultados ao maximo', () {
      final service = GlobalSearchService(maxResults: 2);
      final hymns = List.generate(10, (i) => _hymn(i, 'Amor $i'));
      final results = service.searchHymns('Amor', hymns: hymns);
      expect(results.length, lessThanOrEqualTo(2));
    });
  });

  group('GlobalSearchService.searchBible', () {
    test('encontra versiculo por texto', () {
      final service = GlobalSearchService();
      final verses = <BibleVerseRef>[
        const BibleVerseRef(
          bookId: 43,
          bookName: 'João',
          chapter: 3,
          verse: 16,
          text: 'Porque Deus amou o mundo de tal maneira',
        ),
      ];
      final results = service.searchBible('amou o mundo', verses: verses);
      expect(results, hasLength(1));
      expect((results.first.item as BibleVerseRef).bookName, 'João');
    });

    test('referencia formatada como Joao 3:16', () {
      const ref = BibleVerseRef(
        bookId: 43,
        bookName: 'João',
        chapter: 3,
        verse: 16,
        text: 'texto',
      );
      expect(ref.reference, 'João 3:16');
    });

    test('normalizacao ignora acentos na busca biblica', () {
      final service = GlobalSearchService();
      final verses = <BibleVerseRef>[
        const BibleVerseRef(
          bookId: 19,
          bookName: 'Salmos',
          chapter: 23,
          verse: 1,
          text: 'O Senhor é o meu pastor',
        ),
      ];
      final results = service.searchBible(
        'senhor e o meu pastor',
        verses: verses,
      );
      expect(results, hasLength(1));
    });
  });

  group('GlobalSearchResult', () {
    test('groupKey separa hinos e biblia', () {
      final hymnResult = GlobalSearchResult(
        item: _hymn(1, 'Hino'),
        score: 10,
        snippet: 'Hino',
      );
      final verseResult = GlobalSearchResult(
        item: const BibleVerseRef(
          bookId: 1,
          bookName: 'Gênesis',
          chapter: 1,
          verse: 1,
          text: 'No princípio',
        ),
        score: 10,
        snippet: 'No princípio',
      );
      expect(hymnResult.groupKey, isNot(equals(verseResult.groupKey)));
    });
  });
}
