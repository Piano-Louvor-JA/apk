library;

import 'package:louvorja_piano_mobile/core/errors/louvorja_api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/bloc/hymns_bloc.dart';

/// Mock configuravel: lanca LouvorjaApiException com code escolhido.
class _ApiErrorException implements LouvorjaApiClient {
  _ApiErrorException(this.code);
  final String code;

  @override
  String languagePrefix = 'pt';

  @override
  Future<List<AlbumCategory>> fetchCategories() async {
    throw LouvorjaApiException(code, 'test error');
  }

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
  test(
      'RED: load com 404 (idioma sem catalogo) emite HymnsCatalogInvite '
      'com preview pt-BR carregado (backdrop do convite)', () async {
    final repo = HymnRepositoryImpl(
        _ApiErrorException('errors.notFound'), CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    bloc.add(HymnsLoadRequested());
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<HymnsLoading>(), isA<HymnsCatalogInvite>()]),
    );
    // preview pt-BR em background: categorie reais (aqui repo lança, preview fica vazio)
    expect(bloc.state, isA<HymnsCatalogInvite>());
    await bloc.close();
  });

  test('RED: refresh com 404 tambem emite HymnsCatalogInvite', () async {
    final repo =
        HymnRepositoryImpl(_ApiErrorException('errors.notFound'), CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    bloc.add(HymnsRefreshRequested());
    // refresh NÃO emite HymnsLoading (comportamento real do _onRefresh)
    await expectLater(bloc.stream, emits(isA<HymnsCatalogInvite>()));
    await bloc.close();
  });

  test('erro real (connection) continua HymnsError — nao convite', () async {
    final repo =
        HymnRepositoryImpl(_ApiErrorException('errors.connection'), CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    bloc.add(HymnsLoadRequested());
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<HymnsLoading>(), isA<HymnsError>()]),
    );
    expect((bloc.state as HymnsError).code, 'errors.connection');
    await bloc.close();
  });
}
