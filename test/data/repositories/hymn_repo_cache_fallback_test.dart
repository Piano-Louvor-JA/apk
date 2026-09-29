library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';

/// API que sempre falha fetchAlbumHymns.
class _FailingApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  @override
  Future<List<AlbumCategory>> fetchCategories() async => const [];
  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async =>
      throw Exception('network down');

  @override
  Future<Hymn> fetchMusic(int musicId) async => Hymn(id: musicId);
  @override
  Future<List<Hymn>> fetchHymnal() async => const [];
  @override
  Future<List<Hymn>> fetchHymnal1996() async => const [];
  @override
  Future<List<Hymn>> fetchMusicIndex() async => const [];
  @override
  String resolveMediaUrl(String p) => p;
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
    tempDir = Directory.systemTemp.createTempSync('repo_cache_fallback');
    cache = CatalogCache(tempDir);
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test(
    'getHymnsByAlbum: cache corrompido + API falha = erro honesto (nao lista vazia)',
    () async {
      // Escreve cache com dados nao-List (parsed sera vazio)
      cache.write('album_42', 'not_a_list');

      final repo = HymnRepositoryImpl(_FailingApi(), cache);

      // Fluxo: le cache -> parsed e [] (not_a_list) -> tenta API -> falha
      // -> catch: fresh e stale ambos inuteis (parse vazio) -> rethrow.
      // Sem lista vazia silenciosa (bug do empty-state enganoso).
      expect(() => repo.getHymnsByAlbum(42), throwsA(isA<Exception>()));
    },
  );

  test('getHymnsByAlbum: sem cache + API falha = rethrow', () async {
    final repo = HymnRepositoryImpl(_FailingApi(), cache);

    // Fluxo: le cache -> null -> tenta API -> falha
    // -> catch: cached == null -> rethrow
    expect(() => repo.getHymnsByAlbum(99), throwsA(isA<Exception>()));
  });

  _staleGroup();
}

/// API que conta chamadas e falha apos N sucessos.
class _CountingFailingApi implements LouvorjaApiClient {
  final int succeedFirst;
  int calls = 0;

  _CountingFailingApi({this.succeedFirst = 0});

  List<Hymn> get _hymns => [
    const Hymn(id: 1, title: 'Remoto A'),
    const Hymn(id: 2, title: 'Remoto B'),
  ];

  @override
  String languagePrefix = 'pt';

  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async {
    calls++;
    if (calls <= succeedFirst) return _hymns;
    throw Exception('network down');
  }

  @override
  Future<List<AlbumCategory>> fetchCategories() async => const [];
  @override
  Future<Hymn> fetchMusic(int musicId) async => Hymn(id: musicId);
  @override
  Future<List<Hymn>> fetchHymnal() async => const [];
  @override
  Future<List<Hymn>> fetchHymnal1996() async => const [];
  @override
  Future<List<Hymn>> fetchMusicIndex() async => const [];
  @override
  String resolveMediaUrl(String p) => p;
  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [];
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [];
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      {};
}

void _staleGroup() {
  group('stale-while-offline: cache expirado e API fora', () {
    test('cache expirado serve como fallback quando API falha', () async {
      final dir = Directory.systemTemp.createTempSync('stale_fallback');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cache = CatalogCache(dir);
      // escreve cache com dados validos e mtime antigo (expirado)
      cache.write('album_7', [
        {'id_music': 1, 'name': 'Hino Cache', 'track': 1},
      ]);
      // envelhece o arquivo além do TTL de 24h
      final f = File('${dir.path}/catalog_album_7.json');
      final old = DateTime.now().subtract(const Duration(hours: 25));
      f.setLastModifiedSync(old);

      final api = _CountingFailingApi(succeedFirst: 0);
      final repo = HymnRepositoryImpl(api, cache);

      final result = await repo.getHymnsByAlbum(7);
      expect(
        result,
        isNotEmpty,
        reason: 'cache expirado deve servir quando a API esta fora',
      );
      expect(result.first.title, 'Hino Cache');
    });
  });
}
