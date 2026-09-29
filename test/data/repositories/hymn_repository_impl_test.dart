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

  List<AlbumCategory> categoriesResult = const [];
  Map<int, List<Hymn>> albumHymns = {};
  List<Hymn> musicIndex = const [];
  List<Hymn> hymnalResult = const [];
  List<Hymn> hymnal1996Result = const [];
  Hymn? musicDetail;
  bool shouldFail = false;
  bool shouldFailHymnal1996 = false; // API ES nao possui esse arquivo (404).

  @override
  Future<List<AlbumCategory>> fetchCategories() async {
    if (shouldFail) throw Exception('network error');
    return categoriesResult;
  }

  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async {
    if (shouldFail) throw Exception('network error');
    return albumHymns[albumId] ?? const [];
  }

  @override
  Future<Hymn> fetchMusic(int musicId) async {
    if (shouldFail) throw Exception('network error');
    return musicDetail ?? Hymn(id: musicId);
  }

  @override
  Future<List<Hymn>> fetchHymnal() async {
    if (shouldFail) throw Exception('network error');
    return hymnalResult;
  }

  @override
  Future<List<Hymn>> fetchHymnal1996() async {
    if (shouldFail || shouldFailHymnal1996) throw Exception('network error');
    return hymnal1996Result;
  }

  @override
  Future<List<Hymn>> fetchMusicIndex() async {
    if (shouldFail) throw Exception('network error');
    return musicIndex;
  }

  @override
  String resolveMediaUrl(String relativePath) =>
      'https://example.com/$relativePath';
  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [];
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [];
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      {};
}

void main() {
  late _MockApi api;
  late CatalogCache cache;

  setUp(() {
    api = _MockApi();
    final tempDir = Directory.systemTemp.createTempSync('repo_test');
    cache = CatalogCache(tempDir);
  });

  test('getCategories injeta hinario quando hymnal nao e vazio', () async {
    api.categoriesResult = [
      AlbumCategory(
        id: 1,
        name: 'Cat 1',
        albums: [const Album(id: 100, name: 'Album A')],
      ),
    ];
    api.hymnalResult = [
      const Hymn(id: 1, title: 'Hino 1'),
      const Hymn(id: 2, title: 'Hino 2'),
    ];

    final repo = HymnRepositoryImpl(api, cache);
    final result = await repo.getCategories();

    // Primeira categoria = Hinario Adventista (virtual)
    expect(result.first.name, 'Hinário Adventista');
    expect(result.first.albums.first.id, -1);
    expect(result.first.albums.first.subtitle, '2 hinos');
    expect(result.first.albums.first.trackCount, 2);
  });

  test(
    'getCategories preserva catalogo e hinario atual quando 1996 indisponivel (API ES 404)',
    () async {
      api.languagePrefix = 'es';
      api.categoriesResult = [
        AlbumCategory(
          id: 1,
          name: 'Cat ES',
          albums: [const Album(id: 100, name: 'Album ES')],
        ),
      ];
      api.hymnalResult = [const Hymn(id: 1, title: 'Himno actual')];
      api.shouldFailHymnal1996 = true;

      final result = await HymnRepositoryImpl(api, cache).getCategories();

      expect(result.any((c) => c.name == 'Cat ES'), isTrue);
      expect(result.expand((c) => c.albums).any((a) => a.id == -1), isTrue);
      expect(result.expand((c) => c.albums).any((a) => a.id == -2), isFalse);
    },
  );

  test('hinario atual usa cache quando API cai (offline-first)', () async {
    api.hymnalResult = [const Hymn(id: 1, title: 'Nosso Sol é Jesus')];
    final repo = HymnRepositoryImpl(api, cache);

    // Primeira visita online popula album_-1 no CatalogCache.
    final online = await repo.getHymnsByAlbum(-1);
    expect(online.single.title, 'Nosso Sol é Jesus');

    // Nova instancia simula reinicio; rede indisponivel.
    api.shouldFail = true;
    final restarted = HymnRepositoryImpl(api, cache);
    final offline = await restarted.getHymnsByAlbum(-1);

    expect(offline.single.id, 1);
    expect(offline.single.title, 'Nosso Sol é Jesus');
  });

  test('getCategories nao injeta hinario quando vazio', () async {
    api.categoriesResult = [
      AlbumCategory(
        id: 1,
        name: 'Cat 1',
        albums: [const Album(id: 100, name: 'A')],
      ),
    ];
    api.hymnalResult = const [];

    final repo = HymnRepositoryImpl(api, cache);
    final result = await repo.getCategories();

    // Sem categoria virtual de hinario
    expect(result.any((c) => c.name == 'Hinário Adventista'), false);
  });

  test('getCategories injeta hinario 1996 quando disponivel', () async {
    api.categoriesResult = const [];
    api.hymnal1996Result = [
      const Hymn(id: 1, title: 'Hino 1996 #1'),
      const Hymn(id: 2, title: 'Hino 1996 #2'),
      const Hymn(id: 3, title: 'Hino 1996 #3'),
    ];

    final repo = HymnRepositoryImpl(api, cache);
    final result = await repo.getCategories();

    // Deve ter categoria com hinario 1996
    final hymnalCat = result
        .where((c) => c.name == 'Hinário Adventista')
        .toList();
    expect(hymnalCat, isNotEmpty);
    final album1996 = hymnalCat.first.albums.where((a) => a.id == -2).first;
    expect(album1996.name, contains('1996'));
    expect(album1996.subtitle, '3 hinos');
  });

  test('getHymnsByAlbum retorna hinario 1996 do endpoint dedicado', () async {
    api.hymnal1996Result = [const Hymn(id: 10, title: 'O Deus de Amor')];

    final repo = HymnRepositoryImpl(api, cache);
    final hymns = await repo.getHymnsByAlbum(-2);

    expect(hymns.length, 1);
    expect(hymns.first.title, 'O Deus de Amor');
  });

  test('getCategories filtra IDs 712 e 629', () async {
    api.categoriesResult = [
      AlbumCategory(
        id: 1,
        name: 'Cat 1',
        albums: [
          const Album(id: 100, name: 'Album A'),
          const Album(id: 712, name: 'Excluido 712'),
          const Album(id: 629, name: 'Excluido 629'),
          const Album(id: 200, name: 'Album B'),
        ],
      ),
    ];

    final repo = HymnRepositoryImpl(api, cache);
    final result = await repo.getCategories();

    expect(result.length, 1);
    expect(result[0].albums.length, 2);
    expect(result[0].albums[0].id, 100);
    expect(result[0].albums[1].id, 200);
  });

  test('getCategories usa cache em memoria na segunda chamada', () async {
    api.categoriesResult = [
      AlbumCategory(id: 1, name: 'Teste', albums: const [Album(id: 1)]),
    ];

    final repo = HymnRepositoryImpl(api, cache);
    await repo.getCategories();
    api.shouldFail = true;
    final result = await repo.getCategories();

    expect(result.length, greaterThan(0));
  });

  test('getHymnsByAlbum retorna hinos', () async {
    api.albumHymns = {
      100: [
        const Hymn(id: 1, title: 'Hino 1'),
        const Hymn(id: 2, title: 'Hino 2'),
      ],
    };

    final repo = HymnRepositoryImpl(api, cache);
    final result = await repo.getHymnsByAlbum(100);

    expect(result.length, 2);
    expect(result[0].title, 'Hino 1');
  });

  test('getHymnsByAlbum com hinario (-1) usa fetchHymnal', () async {
    api.hymnalResult = [
      const Hymn(id: 1, title: 'Hino 1'),
      const Hymn(id: 2, title: 'Hino 2'),
    ];

    final repo = HymnRepositoryImpl(api, cache);
    final result = await repo.getHymnsByAlbum(-1);

    expect(result.length, 2);
  });

  test('getHymnsByAlbum faz cache em disco', () async {
    api.albumHymns = {
      100: [const Hymn(id: 1, title: 'Cached')],
    };

    final repo = HymnRepositoryImpl(api, cache);
    await repo.getHymnsByAlbum(100);

    // Segunda chamada: mesmo com erro de rede, retorna do cache
    api.shouldFail = true;
    final result = await repo.getHymnsByAlbum(100);

    expect(result.length, 1);
    expect(result[0].title, 'Cached');
  });

  test('getHymnsByAlbum propaga erro quando nao ha cache', () async {
    api.shouldFail = true;
    final repo = HymnRepositoryImpl(api, cache);
    expect(() => repo.getHymnsByAlbum(999), throwsA(isA<Exception>()));
  });

  test('searchHymns filtra por titulo', () async {
    api.musicIndex = [
      const Hymn(id: 1, title: 'Gracas Dou', number: 1),
      const Hymn(id: 2, title: 'Coroai', number: 2),
      const Hymn(id: 3, title: 'Gracas a Deus', number: 3),
    ];

    final repo = HymnRepositoryImpl(api, cache);
    final result = await repo.searchHymns('gracas');

    expect(result.length, 2);
    expect(result[0].title, 'Gracas Dou');
  });

  test('searchHymns filtra por numero', () async {
    api.musicIndex = [
      const Hymn(id: 1, title: 'Hino A', number: 42),
      const Hymn(id: 2, title: 'Hino B', number: 100),
    ];

    final repo = HymnRepositoryImpl(api, cache);
    final result = await repo.searchHymns('42');

    expect(result.length, 1);
    expect(result[0].number, 42);
  });

  test('getHymn por ID', () async {
    api.musicIndex = [
      const Hymn(id: 10, title: 'Encontrado'),
      const Hymn(id: 20, title: 'Outro'),
    ];

    final repo = HymnRepositoryImpl(api, cache);
    final h = await repo.getHymn(10);

    expect(h, isNotNull);
    expect(h!.title, 'Encontrado');
  });

  test('getHymn retorna null se nao existe', () async {
    api.musicIndex = [const Hymn(id: 1)];
    final repo = HymnRepositoryImpl(api, cache);
    expect(await repo.getHymn(999), isNull);
  });

  test('getHymnDetails delega para fetchMusic', () async {
    api.musicDetail = const Hymn(
      id: 42,
      title: 'Detalhado',
      urlMusic: '/musics/foo.mp3',
    );
    final repo = HymnRepositoryImpl(api, cache);
    final h = await repo.getHymnDetails(42);

    expect(h.title, 'Detalhado');
    expect(h.urlMusic, '/musics/foo.mp3');
  });

  test('getAllAlbums flattened de categorias', () async {
    api.categoriesResult = [
      AlbumCategory(id: 1, albums: [const Album(id: 1), const Album(id: 2)]),
      AlbumCategory(id: 2, albums: [const Album(id: 3)]),
    ];

    final repo = HymnRepositoryImpl(api, cache);
    await repo.getCategories();
    final albums = repo.getAllAlbums();

    expect(albums.length, 3);
  });

  test('getCategories com erro remoto e sem cache propaga erro', () async {
    api.shouldFail = true;
    final repo = HymnRepositoryImpl(api, cache);
    expect(() => repo.getCategories(), throwsA(isA<Exception>()));
  });
}
