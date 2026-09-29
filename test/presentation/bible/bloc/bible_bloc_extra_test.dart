// ignore_for_file: unused_element
library;

import 'package:louvorja_piano_mobile/core/errors/louvorja_api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/bible_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bloc/bible_bloc.dart';

/// Mock que lanca LouvorjaApiException em todos os metodos de biblia.
class _ApiErrorException implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  @override
  Future<List<BibleBook>> fetchBibleBooks() async =>
      throw const LouvorjaApiException('errors.connection', 'test');
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async =>
      throw const LouvorjaApiException('errors.connection', 'test');
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      throw const LouvorjaApiException('errors.connection', 'test');

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

/// Mock que lanca Exception generica.
class _ApiGenericException implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  @override
  Future<List<BibleBook>> fetchBibleBooks() async => throw Exception('boom');
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async =>
      throw Exception('boom');
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      throw Exception('boom');

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

/// Mock que funciona para bootstrap mas falha em chapter.
class _ApiChapterFail implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [
    BibleBook(
      id: 1,
      name: 'Gen',
      abbreviation: 'Gn',
      chapters: 50,
      bookNumber: 1,
    ),
  ];
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [
    BibleVersion(id: 1, abbreviation: 'ARA', name: 'ARA'),
  ];
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      throw const LouvorjaApiException('errors.connection', 'chapter fail');

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

/// Mock com books vazios (bootstrap falha com loadCatalogFailed).
class _MockApiEmptyBooks implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [];
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [
    BibleVersion(id: 1, abbreviation: 'ARA', name: 'ARA'),
  ];
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      const {};

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

/// Mock com versions vazios (bootstrap falha com loadCatalogFailed).
class _MockApiEmptyVersions implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [
    BibleBook(
      id: 1,
      name: 'Gen',
      abbreviation: 'Gn',
      chapters: 50,
      bookNumber: 1,
    ),
  ];
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [];
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      const {};

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

/// Mock que funciona no bootstrap mas falha com LouvorjaApiException
/// em fetchBibleChapter (para testar selectVersion/Book/Chapter).
class _ApiChapterLouvorjaFail implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [
    BibleBook(
      id: 1,
      name: 'Gen',
      abbreviation: 'Gn',
      chapters: 50,
      bookNumber: 1,
    ),
  ];
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [
    BibleVersion(id: 1, abbreviation: 'ARA', name: 'ARA'),
    BibleVersion(id: 2, abbreviation: 'NVI', name: 'NVI'),
  ];

  int _chapterCallCount = 0;

  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async {
    _chapterCallCount++;
    if (_chapterCallCount > 1) {
      throw const LouvorjaApiException('errors.connection', 'fail after first');
    }
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
  group('BibleBloc ramos de erro em handlers', () {
    test('selectVersion com LouvorjaApiException emite erro', () async {
      // API que funciona para bootstrap mas lanca LouvorjaApiException no chapter
      final bloc = BibleBloc(
        BibleRepositoryImpl(_ApiChapterFail(), CatalogCache.noop()),
      );
      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      // Bootstrap falha no carregamento do primeiro capitulo
      // porque _ApiChapterFail lanca LouvorjaApiException em fetchBibleChapter
      expect(bloc.state, isA<BibleError>());
      await bloc.close();
    });

    test('bootstrap com books vazios emite loadCatalogFailed', () async {
      final api = _MockApiEmptyBooks();
      final bloc = BibleBloc(BibleRepositoryImpl(api, CatalogCache.noop()));
      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));
      expect(bloc.state, isA<BibleError>());
      expect((bloc.state as BibleError).code, 'bible.errors.loadCatalogFailed');
      await bloc.close();
    });

    test('bootstrap com versions vazios emite loadCatalogFailed', () async {
      final api = _MockApiEmptyVersions();
      final bloc = BibleBloc(BibleRepositoryImpl(api, CatalogCache.noop()));
      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));
      expect(bloc.state, isA<BibleError>());
      await bloc.close();
    });
  });

  group('BibleBloc ramos de erro em selectVersion/Book/Chapter', () {
    test('selectVersion com LouvorjaApiException emite BibleError', () async {
      final api = _ApiChapterLouvorjaFail();
      final bloc = BibleBloc(BibleRepositoryImpl(api, CatalogCache.noop()));
      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));
      expect(bloc.state, isA<BibleLoaded>());

      // Agora o 2o fetchChapter vai falhar com LouvorjaApiException
      bloc.add(BibleSelectVersion(2));
      await Future.delayed(const Duration(milliseconds: 300));
      expect(bloc.state, isA<BibleError>());
      expect((bloc.state as BibleError).code, 'errors.connection');
      await bloc.close();
    });

    test('selectBook com LouvorjaApiException emite BibleError', () async {
      final api = _ApiChapterLouvorjaFail();
      final bloc = BibleBloc(BibleRepositoryImpl(api, CatalogCache.noop()));
      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));
      expect(bloc.state, isA<BibleLoaded>());

      // 2o fetchChapter vai falhar
      bloc.add(BibleSelectBook(1));
      await Future.delayed(const Duration(milliseconds: 300));
      expect(bloc.state, isA<BibleError>());
      await bloc.close();
    });

    test('selectChapter com LouvorjaApiException emite BibleError', () async {
      final api = _ApiChapterLouvorjaFail();
      final bloc = BibleBloc(BibleRepositoryImpl(api, CatalogCache.noop()));
      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));
      expect(bloc.state, isA<BibleLoaded>());

      bloc.add(BibleSelectChapter(2));
      await Future.delayed(const Duration(milliseconds: 300));
      expect(bloc.state, isA<BibleError>());
      await bloc.close();
    });
  });

  group('BibleLoaded copyWith', () {
    test('copyWith preserva valores nao alterados', () {
      const state = BibleLoaded(
        books: [],
        versions: [],
        selectedVersionId: 1,
        selectedBookId: 10,
        selectedChapter: 5,
        verses: {'1': 'v1'},
        selectedVerses: [1],
      );
      final copy = state.copyWith();
      expect(copy.selectedVersionId, 1);
      expect(copy.selectedBookId, 10);
      expect(copy.selectedChapter, 5);
      expect(copy.verses['1'], 'v1');
      expect(copy.selectedVerses, [1]);
    });

    test('copyWith altera apenas campo especificado', () {
      const state = BibleLoaded(
        books: [],
        versions: [],
        selectedVersionId: 1,
        selectedBookId: 10,
        selectedChapter: 5,
        verses: {},
        selectedVerses: [],
      );
      final copy = state.copyWith(selectedChapter: 3);
      expect(copy.selectedChapter, 3);
      expect(copy.selectedBookId, 10); // nao mudou
    });
  });

  group('BibleBloc repository getter', () {
    test('repository e acessivel', () {
      final repo = BibleRepositoryImpl(_ApiChapterFail(), CatalogCache.noop());
      final bloc = BibleBloc(repo);
      expect(bloc.repository, same(repo));
      bloc.close();
    });
  });

  group('BibleSelectVerse constructor', () {
    test('armazena verseNumber', () {
      const event = BibleSelectVerse(42);
      expect(event.verseNumber, 42);
    });
  });
}
