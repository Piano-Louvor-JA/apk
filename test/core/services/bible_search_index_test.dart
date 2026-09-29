library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/bible_search_index.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';

void main() {
  late Directory dir;
  late CatalogCache cache;
  late BibleSearchIndex index;

  final books = [
    const BibleBook(
      id: 1,
      name: 'Gênesis',
      abbreviation: 'gn',
      chapters: 3,
      bookNumber: 1,
    ),
    const BibleBook(
      id: 4,
      name: 'João',
      abbreviation: 'jo',
      chapters: 1,
      bookNumber: 43,
      languageId: 'pt',
    ),
  ];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('bible_search_test');
    cache = CatalogCache(dir, now: () => DateTime(2026, 8, 21));
    index = BibleSearchIndex(cache);
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  void seedChapter(
    int version,
    int book,
    int chapter,
    Map<String, String> verses,
  ) {
    cache.write('bible_${version}_${book}_$chapter', verses);
  }

  test('índice vazio não retorna nada', () async {
    final results = await index.search('amor', 1, books);
    expect(results, isEmpty);
  });

  test('busca encontra verso em outro livro/capítulo', () async {
    seedChapter(1, 1, 1, {'1': 'No princípio criou Deus os céus.'});
    seedChapter(1, 4, 3, {'16': 'Porque Deus amou o mundo de tal maneira'});

    final results = await index.search('amou', 1, books);

    expect(results, isNotEmpty);
    expect(results.first.bookName, 'João');
    expect(results.first.chapter, 3);
    expect(results.first.verse, 16);
    expect(results.first.reference, 'João 3:16');
  });

  test('busca ignora acentos e caixa', () async {
    seedChapter(1, 4, 3, {'16': 'Porque Deus amou o mundo'});
    final results = await index.search('AMOU', 1, books);
    expect(results, hasLength(1));
  });

  test('busca com menos de 3 caracteres não roda', () async {
    seedChapter(1, 4, 3, {'16': 'Porque Deus amou o mundo'});
    expect(await index.search('am', 1, books), isEmpty);
  });

  test('match por palavra inicial pesa mais que substring', () async {
    seedChapter(1, 1, 1, {
      '1': 'No princípio',
      '2': 'amar é o dom supremo, reaparece',
    });
    final results = await index.search('amar', 1, books);
    expect(results.first.verse, 2);
  });

  test('limita resultados', () async {
    final verses = <String, String>{};
    for (var i = 1; i <= 50; i++) {
      verses['$i'] = 'o amor de Deus permanece $i';
    }
    seedChapter(1, 1, 1, verses);
    final results = await index.search('amor', 1, books, limit: 10);
    expect(results, hasLength(10));
  });

  test('cachedChapters lista apenas a versão pedida', () async {
    seedChapter(1, 1, 1, {'1': 'a'});
    seedChapter(2, 1, 1, {'1': 'b'});
    final v1 = index.cachedChapters(1);
    expect(v1, [(1, 1)]);
  });

  test('snippet corta textos longos', () async {
    seedChapter(1, 1, 1, {'1': 'a' * 150});
    final results = await index.search('aaa', 1, books);
    expect(results, hasLength(1));
    expect(results.first.snippet.length, lessThanOrEqualTo(91));
    expect(results.first.snippet.endsWith('…'), isTrue);
  });

  test('não encontra texto ausente', () async {
    seedChapter(1, 1, 1, {'1': 'No princípio'});
    expect(await index.search('samaritano', 1, books), isEmpty);
  });

  test('listKeys do cache expõe capítulos', () async {
    seedChapter(1, 1, 2, {'1': 'x'});
    expect(cache.listKeys(), contains('bible_1_1_2'));
  });

  test('cache noop (web) retorna vazio', () async {
    final noopIndex = BibleSearchIndex(const CatalogCache.noop());
    expect(noopIndex.cachedChapters(1), isEmpty);
    expect(await noopIndex.search('amor', 1, books), isEmpty);
  });
}
