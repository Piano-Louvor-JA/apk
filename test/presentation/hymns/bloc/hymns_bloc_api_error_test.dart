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

/// Mock que lanca LouvorjaApiException em vez de Exception generica.
class _ApiErrorException implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  @override
  Future<List<AlbumCategory>> fetchCategories() async {
    throw const LouvorjaApiException('errors.connection', 'test error');
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
  test('load com LouvorjaApiException emite HymnsError com code', () async {
    final repo = HymnRepositoryImpl(_ApiErrorException(), CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    bloc.add(HymnsLoadRequested());
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<HymnsLoading>(), isA<HymnsError>()]),
    );
    expect((bloc.state as HymnsError).code, 'errors.connection');
    await bloc.close();
  });

  test('refresh com LouvorjaApiException emite HymnsError com code', () async {
    final repo = HymnRepositoryImpl(_ApiErrorException(), CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    bloc.add(HymnsRefreshRequested());
    // Refresh nao emite Loading -- so emite Loaded ou Error
    await expectLater(bloc.stream, emits(isA<HymnsError>()));
    expect((bloc.state as HymnsError).code, 'errors.connection');
    await bloc.close();
  });
}
