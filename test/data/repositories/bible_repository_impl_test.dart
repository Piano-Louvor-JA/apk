// ignore_for_file: unused_element, unused_element_parameter
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/bible_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';

class _MockApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  final bool fail;
  final List<BibleBook> books;
  final List<BibleVersion> versions;
  final Map<String, String> chapterVerses;

  _MockApi({
    this.fail = false,
    this.books = const [
      BibleBook(
        id: 1,
        name: 'Gen',
        abbreviation: 'Gn',
        chapters: 50,
        bookNumber: 1,
      ),
      BibleBook(
        id: 2,
        name: 'Exo',
        abbreviation: 'Ex',
        chapters: 40,
        bookNumber: 2,
      ),
    ],
    this.versions = const [
      BibleVersion(id: 1, abbreviation: 'ARA', name: 'ARA'),
    ],
    this.chapterVerses = const {'1': 'v1', '2': 'v2'},
  });

  @override
  Future<List<BibleBook>> fetchBibleBooks() async {
    if (fail) throw Exception('network');
    return books;
  }

  @override
  Future<List<BibleVersion>> fetchBibleVersions() async {
    if (fail) throw Exception('network');
    return versions;
  }

  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async {
    if (fail) throw Exception('network');
    return chapterVerses;
  }

  @override
  Future<List<AlbumCategory>> fetchCategories() async => const [];
  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async => const [];
  @override
  Future<Hymn> fetchMusic(int musicId) async => Hymn(id: musicId);
  @override
  Future<List<Hymn>> fetchHymnal() async => const [];
  @override
  Future<List<Hymn>> fetchHymnal1996() async => const [];
  @override
  Future<List<Hymn>> fetchMusicIndex() async => const [];
  @override
  String resolveMediaUrl(String p) => '';
}

void main() {
  late Directory tempDir;
  late CatalogCache cache;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bible_repo_test');
    cache = CatalogCache(tempDir);
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('getBooks', () {
    test('busca livros da API e ordena por bookNumber', () async {
      final repo = BibleRepositoryImpl(
        _MockApi(
          books: const [
            BibleBook(
              id: 40,
              name: 'Mt',
              abbreviation: 'Mt',
              chapters: 28,
              bookNumber: 40,
            ),
            BibleBook(
              id: 1,
              name: 'Gn',
              abbreviation: 'Gn',
              chapters: 50,
              bookNumber: 1,
            ),
          ],
        ),
        cache,
      );
      final result = await repo.getBooks();
      expect(result.length, 2);
      expect(result[0].bookNumber, 1); // ordenado
      expect(result[1].bookNumber, 40);
    });

    test('le do cache quando API falha', () async {
      cache.write('bible_books', [
        {
          'id_bible_book': 1,
          'name': 'Cached',
          'abbreviation': 'C',
          'chapters': 10,
          'book_number': 1,
        },
      ]);
      final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
      final result = await repo.getBooks();
      expect(result.length, 1);
      expect(result[0].name, 'Cached');
    });

    test('rethrow quando cache vazio e API falha', () async {
      final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
      expect(() => repo.getBooks(), throwsA(isA<Exception>()));
    });

    test('le do cache valido sem chamar API', () async {
      cache.write('bible_books', [
        {
          'id_bible_book': 1,
          'name': 'FromCache',
          'abbreviation': 'FC',
          'chapters': 10,
          'book_number': 1,
        },
      ]);
      final repo = BibleRepositoryImpl(_MockApi(), cache);
      final result = await repo.getBooks();
      expect(result[0].name, 'FromCache');
    });
  });

  group('getVersions', () {
    test('busca versoes da API', () async {
      final repo = BibleRepositoryImpl(_MockApi(), cache);
      final result = await repo.getVersions();
      expect(result.length, 1);
      expect(result[0].abbreviation, 'ARA');
    });

    test('le do cache quando API falha', () async {
      cache.write('bible_versions', [
        {'id_bible_version': 2, 'abbreviation': 'NVI', 'name': 'NVI'},
      ]);
      final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
      final result = await repo.getVersions();
      expect(result[0].abbreviation, 'NVI');
    });

    test('rethrow quando cache vazio e API falha', () async {
      final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
      expect(() => repo.getVersions(), throwsA(isA<Exception>()));
    });

    test('le do cache valido sem chamar API', () async {
      cache.write('bible_versions', [
        {'id_bible_version': 1, 'abbreviation': 'ACF', 'name': 'ACF'},
      ]);
      final repo = BibleRepositoryImpl(_MockApi(), cache);
      final result = await repo.getVersions();
      expect(result[0].abbreviation, 'ACF');
    });
  });

  group('getChapter', () {
    test('busca versiculos da API', () async {
      final repo = BibleRepositoryImpl(_MockApi(), cache);
      final result = await repo.getChapter(1, 1, 1);
      expect(result['1'], 'v1');
      expect(result['2'], 'v2');
    });

    test('le do cache quando API falha', () async {
      cache.write('bible_1_1_1', {'1': 'cached_v1'});
      final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
      final result = await repo.getChapter(1, 1, 1);
      expect(result['1'], 'cached_v1');
    });

    test('rethrow quando cache vazio e API falha', () async {
      final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
      expect(() => repo.getChapter(1, 1, 1), throwsA(isA<Exception>()));
    });

    test('le do cache valido sem chamar API', () async {
      cache.write('bible_1_1_1', {'1': 'from_cache'});
      final repo = BibleRepositoryImpl(_MockApi(), cache);
      final result = await repo.getChapter(1, 1, 1);
      expect(result['1'], 'from_cache');
    });
  });
}
