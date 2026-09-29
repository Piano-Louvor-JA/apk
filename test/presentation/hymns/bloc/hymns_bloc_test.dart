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
import 'package:louvorja_piano_mobile/presentation/hymns/bloc/hymns_bloc.dart';

class _MockApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  bool fail = false;
  @override
  Future<List<AlbumCategory>> fetchCategories() async {
    if (fail) throw Exception('network');
    return [
      AlbumCategory(
        id: 1,
        name: 'Cat',
        albums: const [Album(id: 1, name: 'A')],
      ),
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
  late HymnsBloc bloc;

  setUp(() {
    final api = _MockApi();
    final tempDir = Directory.systemTemp.createTempSync('bloc_test');
    final cache = CatalogCache(tempDir);
    bloc = HymnsBloc(HymnRepositoryImpl(api, cache));
  });

  tearDown(() => bloc.close());

  test('load → loading → loaded', () async {
    final states = <HymnsState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(HymnsLoadRequested());
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<HymnsLoading>(), isA<HymnsLoaded>()]),
    );
    sub.cancel();
  });

  test('error state quando API falha', () async {
    final api = _MockApi()..fail = true;
    final tempDir = Directory.systemTemp.createTempSync('bloc_err');
    final cache = CatalogCache(tempDir);
    final errorBloc = HymnsBloc(HymnRepositoryImpl(api, cache));

    errorBloc.add(HymnsLoadRequested());
    await expectLater(
      errorBloc.stream,
      emitsInOrder([isA<HymnsLoading>(), isA<HymnsError>()]),
    );
    await errorBloc.close();
  });

  test('refresh emite loaded', () async {
    bloc.add(HymnsLoadRequested());
    await bloc.stream.firstWhere((s) => s is HymnsLoaded);

    bloc.add(HymnsRefreshRequested());
    await expectLater(bloc.stream, emits(isA<HymnsLoaded>()));
  });
}
