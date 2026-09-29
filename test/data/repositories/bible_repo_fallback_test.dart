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

  _MockApi({this.fail = false});

  @override
  Future<List<BibleBook>> fetchBibleBooks() async {
    if (fail) throw Exception('network');
    return const [
      BibleBook(
        id: 1,
        name: 'Gen',
        abbreviation: 'Gn',
        chapters: 50,
        bookNumber: 1,
      ),
    ];
  }

  @override
  Future<List<BibleVersion>> fetchBibleVersions() async {
    if (fail) throw Exception('network');
    return const [BibleVersion(id: 1, abbreviation: 'ARA', name: 'ARA')];
  }

  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async {
    if (fail) throw Exception('network');
    return const {'1': 'v1'};
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
    tempDir = Directory.systemTemp.createTempSync('bible_repo_fallback');
    cache = CatalogCache(tempDir);
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // Testes do catch fallback: cache invalido + API falha
  group('fallback: cache invalido + API falha', () {
    test('getBooks: cache nao-List + API falha = rethrow', () async {
      cache.write('bible_books', 'invalid_string');
      final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
      expect(() => repo.getBooks(), throwsA(isA<Exception>()));
    });

    test('getVersions: cache nao-List + API falha = rethrow', () async {
      cache.write('bible_versions', 'invalid_string');
      final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
      expect(() => repo.getVersions(), throwsA(isA<Exception>()));
    });

    test('getChapter: cache nao-Map + API falha = rethrow', () async {
      cache.write('bible_1_1_1', 'invalid_string');
      final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
      expect(() => repo.getChapter(1, 1, 1), throwsA(isA<Exception>()));
    });
  });

  // Testes do catch fallback: cache valido (List vazia) + API falha
  group('fallback: cache valido mas vazio + API falha', () {
    test(
      'getBooks: cache List vazia + API falha = retorna do catch vazio',
      () async {
        cache.write('bible_books', <Map<String, dynamic>>[]);
        final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
        // cache e List mas parsed e vazio -> tenta API -> falha
        // catch: cached is List -> map -> [] (cached era []) -> retorno
        final result = await repo.getBooks();
        expect(result, isEmpty);
      },
    );

    test('getVersions: cache List vazia + API falha', () async {
      cache.write('bible_versions', <Map<String, dynamic>>[]);
      final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
      final result = await repo.getVersions();
      expect(result, isEmpty);
    });

    test('getChapter: cache Map vazio + API falha', () async {
      cache.write('bible_1_1_1', <String, dynamic>{});
      final repo = BibleRepositoryImpl(_MockApi(fail: true), cache);
      final result = await repo.getChapter(1, 1, 1);
      expect(result, isEmpty);
    });
  });
}
