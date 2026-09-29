library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/bible_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bloc/bible_bloc.dart';

class _NavMockApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  final Map<String, String> chapterVerses;

  _NavMockApi({this.chapterVerses = const {}});

  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [
    BibleBook(
      id: 1,
      name: 'Gen',
      abbreviation: 'Gn',
      chapters: 2,
      bookNumber: 1,
    ),
  ];

  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [
    BibleVersion(id: 1, abbreviation: 'ARA', name: 'ARA'),
  ];

  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async {
    return chapterVerses;
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
  String resolveMediaUrl(String relativePath) => '';
}

void main() {
  group('BibleNavigateVerse', () {
    test('navega para proximo versiculo no mesmo capitulo', () async {
      final repo = BibleRepositoryImpl(
        _NavMockApi(chapterVerses: {'1': 'v1', '2': 'v2', '3': 'v3'}),
        CatalogCache.noop(),
      );
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      bloc.add(const BibleSelectVerse(1));
      await Future.delayed(const Duration(milliseconds: 100));

      bloc.add(const BibleNavigateVerse(1));
      await Future.delayed(const Duration(milliseconds: 100));

      final state = bloc.state as BibleLoaded;
      expect(state.selectedVerses, [2]);
      await bloc.close();
    });

    test('navega para versiculo anterior no mesmo capitulo', () async {
      final repo = BibleRepositoryImpl(
        _NavMockApi(chapterVerses: {'1': 'v1', '2': 'v2', '3': 'v3'}),
        CatalogCache.noop(),
      );
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      bloc.add(const BibleSelectVerse(3));
      await Future.delayed(const Duration(milliseconds: 100));

      bloc.add(const BibleNavigateVerse(-1));
      await Future.delayed(const Duration(milliseconds: 100));

      final state = bloc.state as BibleLoaded;
      expect(state.selectedVerses, [2]);
      await bloc.close();
    });

    test('navigate verse sem selecao nao faz nada', () async {
      final repo = BibleRepositoryImpl(
        _NavMockApi(chapterVerses: {'1': 'v1'}),
        CatalogCache.noop(),
      );
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      bloc.add(const BibleNavigateVerse(1));
      await Future.delayed(const Duration(milliseconds: 100));

      final state = bloc.state as BibleLoaded;
      expect(state.selectedVerses, isEmpty);
      await bloc.close();
    });

    test('cruza para proximo capitulo ao chegar no ultimo versiculo', () async {
      final repo = BibleRepositoryImpl(
        _NavMockApi(chapterVerses: {'1': 'v1next', '2': 'v2next'}),
        CatalogCache.noop(),
      );
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      // Selecionar ultimo versiculo do cap 1 (2 versiculos)
      bloc.add(const BibleSelectVerse(2));
      await Future.delayed(const Duration(milliseconds: 100));

      // Navegar proximo -> cruza para cap 2
      bloc.add(const BibleNavigateVerse(1));
      await Future.delayed(const Duration(milliseconds: 300));

      final state = bloc.state as BibleLoaded;
      expect(state.selectedChapter, 2);
      expect(state.selectedVerses, [1]);
      await bloc.close();
    });

    test(
      'cruza para capitulo anterior ao chegar no primeiro versiculo',
      () async {
        final repo = BibleRepositoryImpl(
          _NavMockApi(chapterVerses: {'1': 'v1prev', '2': 'v2prev'}),
          CatalogCache.noop(),
        );
        final bloc = BibleBloc(repo);

        bloc.add(BibleBootstrap());
        await Future.delayed(const Duration(milliseconds: 300));

        // Ir para cap 2 primeiro
        bloc.add(BibleSelectChapter(2));
        await Future.delayed(const Duration(milliseconds: 300));

        // Selecionar versiculo 1
        bloc.add(const BibleSelectVerse(1));
        await Future.delayed(const Duration(milliseconds: 100));

        // Navegar anterior -> cruza para cap 1, ultimo versiculo
        bloc.add(const BibleNavigateVerse(-1));
        await Future.delayed(const Duration(milliseconds: 300));

        final state = bloc.state as BibleLoaded;
        expect(state.selectedChapter, 1);
        await bloc.close();
      },
    );
  });
}
