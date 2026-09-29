library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/errors/louvorja_api_exception.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_catalog_provider.dart';
import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/hymn_repository.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/bloc/hymns_bloc.dart';

/// Um loader que demora MUITO (simula 67 álbuns em rede lenta).
/// Se o bloc esperar o sync do catálogo, HymnsLoaded nunca chega a tempo
/// e a UI fica em loading infinito (bug reportado 2026-08-16).
class _SlowRepo implements HymnRepository {
  int loaderCalls = 0;

  @override
  Future<List<AlbumCategory>> getCategories() async => [
    AlbumCategory(
      id: 1,
      name: 'Cat',
      albums: [
        const Album(id: 10, name: 'Album 1'),
        const Album(id: 11, name: 'Album 2'),
      ],
    ),
  ];

  @override
  Future<List<Hymn>> getHymnsByAlbum(int albumId) async {
    loaderCalls++;
    await Future<void>.delayed(const Duration(seconds: 30));
    return const [];
  }

  @override
  noSuchMethod(Invocation i) =>
      throw LouvorjaApiException('errors.unknown', 'não usado');
}

void main() {
  test(
    'HymnsLoaded NAO espera o sync do catalogo (loading infinito)',
    () async {
      final repo = _SlowRepo();
      final provider = HymnCatalogProvider();
      final bloc = HymnsBloc(repo, catalogProvider: provider);

      final states = <Type>[];
      final sub = bloc.stream.listen((s) => states.add(s.runtimeType));

      bloc.add(HymnsLoadRequested());
      // Se o bloc esperasse o sync (30s por álbum), loaded nunca chegaria.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        states,
        contains(HymnsLoaded),
        reason: 'HymnsLoaded deve emitir ANTES do sync do catálogo completar',
      );
      await sub.cancel();
      await bloc.close();
    },
  );
}
