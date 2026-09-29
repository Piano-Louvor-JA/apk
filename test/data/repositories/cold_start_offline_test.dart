library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';

class _OfflineApi implements LouvorjaApiClient {
  List<AlbumCategory> categoriesResult = const [];
  List<Hymn> hymnalResult = const [];
  bool shouldFail = false;

  @override
  String languagePrefix = 'pt';

  @override
  Future<List<AlbumCategory>> fetchCategories() async {
    if (shouldFail) throw Exception('network error');
    return categoriesResult;
  }

  @override
  Future<List<Hymn>> fetchHymnal() async {
    if (shouldFail) throw Exception('network error');
    return hymnalResult;
  }

  @override
  Future<List<Hymn>> fetchHymnal1996() async {
    if (shouldFail) throw Exception('network error');
    return const [];
  }

  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async {
    if (shouldFail) throw Exception('network error');
    return const [];
  }

  @override
  noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// Cold start SEM internet deve servir o catálogo do disco:
/// o usuário baixou hinos, fechou o app, desligou a rede e reabriu —
/// a home não pode mostrar "verifique sua conexão" com conteúdo offline
/// disponível (bug reportado 2026-08-16).
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cold_offline');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test(
    'cold start offline serve categorias e hinário do cache de disco',
    () async {
      // 1) Sessão online popula o cache (categorias + hinário).
      final apiOnline = _OfflineApi();
      apiOnline.categoriesResult = [
        const AlbumCategory(
          id: 1,
          name: 'Coletâneas',
          albums: [Album(id: 100, name: 'Louvor JA 2026')],
        ),
      ];
      apiOnline.hymnalResult = const [Hymn(id: 1, title: 'Nosso Sol é Jesus')];

      final repoOnline = HymnRepositoryImpl(apiOnline, CatalogCache(tmp));
      await repoOnline.getCategories();
      await repoOnline.getHymnsByAlbum(-1);

      // 2) App fecha (nova instância = memória zerada), internet cai.
      final apiOffline = _OfflineApi()..shouldFail = true;
      final repoOffline = HymnRepositoryImpl(apiOffline, CatalogCache(tmp));

      final cats = await repoOffline.getCategories();
      expect(cats, isNotEmpty, reason: 'categorias devem vir do disco');

      final hymns = await repoOffline.getHymnsByAlbum(-1);
      expect(hymns, isNotEmpty, reason: 'hinário deve vir do disco');

      // O hinário aparece como categoria virtual com álbum -1.
      final temHinario = cats.expand((c) => c.albums).any((a) => a.id == -1);
      expect(
        temHinario,
        isTrue,
        reason: 'Hinário Adventista (Atual) deve existir offline',
      );
    },
  );
}
