library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/bloc/hymns_bloc.dart';

class _MockApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';
  bool fail = false;
  bool refreshFails = false;
  int callCount = 0;

  @override
  Future<List<AlbumCategory>> fetchCategories() async {
    callCount++;
    if (fail || (refreshFails && callCount > 1)) throw Exception('fail');
    return [
      AlbumCategory(id: 1, albums: const [Album(id: 1)]),
    ];
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
  test('refresh apos load emite novo loaded', () async {
    final api = _MockApi();
    final repo = HymnRepositoryImpl(api, CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    bloc.add(HymnsLoadRequested());
    await Future.delayed(const Duration(milliseconds: 200));
    expect(bloc.state, isA<HymnsLoaded>());

    bloc.add(HymnsRefreshRequested());
    await Future.delayed(const Duration(milliseconds: 200));
    expect(bloc.state, isA<HymnsLoaded>());
  });

  test('refresh emite error quando cache falha', () async {
    final api = _MockApi()..fail = true;
    final repo = HymnRepositoryImpl(api, CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    bloc.add(HymnsRefreshRequested());
    await Future.delayed(const Duration(milliseconds: 200));
    expect(bloc.state, isA<HymnsError>());
  });

  test('refresh emite error unknown quando excecao generica', () async {
    final api = _MockApi()..fail = true;
    final repo = HymnRepositoryImpl(api, CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    bloc.add(HymnsRefreshRequested());
    await Future.delayed(const Duration(milliseconds: 100));
    expect(bloc.state, isA<HymnsError>());
    expect((bloc.state as HymnsError).code, 'errors.unknown');
  });
}
