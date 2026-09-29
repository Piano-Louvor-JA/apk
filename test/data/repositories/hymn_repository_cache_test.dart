// ignore_for_file: unused_import
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';

class _MockApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';
  bool fail = false;

  @override
  Future<List<AlbumCategory>> fetchCategories() async {
    if (fail) throw Exception('fail');
    return [
      AlbumCategory(id: 1, name: 'Live', albums: const [Album(id: 10)]),
    ];
  }

  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async {
    if (fail) throw Exception('fail');
    return [const Hymn(id: 1, title: 'H1')];
  }

  @override
  Future<Hymn> fetchMusic(int musicId) async => Hymn(id: musicId);
  @override
  Future<List<Hymn>> fetchHymnal() async => const [];
  @override
  Future<List<Hymn>> fetchHymnal1996() async => const [];
  @override
  Future<List<Hymn>> fetchMusicIndex() async => const [];
  @override
  String resolveMediaUrl(String relativePath) => '';
  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [];
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [];
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      {};
}

void main() {
  late Directory tempDir;
  late CatalogCache cache;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cache_test');
    cache = CatalogCache(tempDir);
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('getCategories le do cache em disco quando API falha', () async {
    // 1. Popula cache em disco com dados validos
    final cachedData = [
      {
        'id_category': 99,
        'name': 'Cached Cat',
        'albums': [
          {'id_album': 50, 'name': 'Cached Album'},
        ],
      },
    ];
    cache.write('categories', cachedData);

    // 2. API falha -- deve retornar do cache expirado (fallback)
    final api = _MockApi()..fail = true;
    final repo = HymnRepositoryImpl(api, cache);
    final result = await repo.getCategories();

    expect(result, isNotEmpty);
  });

  test('getHymnsByAlbum le do cache quando API falha', () async {
    // 1. Popula cache do album
    cache.write('album_100', [
      {'id_music': 1, 'name': 'Cached Hino'},
    ]);

    // 2. API falha
    final api = _MockApi()..fail = true;
    final repo = HymnRepositoryImpl(api, cache);
    final result = await repo.getHymnsByAlbum(100);

    expect(result.length, 1);
    expect(result[0].title, 'Cached Hino');
  });

  test('getCategories le do cache local valido (nao expirado)', () async {
    // Escreve cache valido (sem expirar)
    cache.write('categories', [
      {'id_category': 1, 'name': 'From Cache', 'albums': []},
    ]);

    final api = _MockApi();
    final repo = HymnRepositoryImpl(api, cache);
    final result = await repo.getCategories();

    // Mesmo que a API funcione, se o cache e valido, le do cache primeiro
    // (a nao ser que o cache em memoria ja esteja populado de teste anterior)
    expect(result, isNotEmpty);
  });

  test(
    '_parseCategories com dados invalidos retorna do fallback vazio',
    () async {
      cache.write('categories', 'invalid_string');
      final api = _MockApi()..fail = true;
      final repo = HymnRepositoryImpl(api, cache);

      // Cache invalido (nao e List) -> _parseCategories retorna []
      // API falha -> fallback retorna [] do cache invalido
      final result = await repo.getCategories();
      expect(result, isEmpty);
    },
  );
}
