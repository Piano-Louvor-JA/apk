library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/bible_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/bible_repository.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bloc/bible_bloc.dart';

class _MockApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  final List<BibleBook> books;
  final List<BibleVersion> versions;
  final Map<String, String> chapterVerses;
  final bool fail;

  _MockApi({
    this.books = const [],
    this.versions = const [],
    this.chapterVerses = const {},
    this.fail = false,
  });

  @override
  Future<List<BibleBook>> fetchBibleBooks() async {
    if (fail) throw Exception('network');
    return books;
  }

  @override
  Future<List<BibleVersion>> fetchBibleVersions() async {
    if (fail) throw Exception('network');
    return versions;
  }

  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async {
    if (fail) throw Exception('network');
    return chapterVerses;
  }

  // Metodos herdados (nao usados)
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

BibleRepository _repo({_MockApi? api}) {
  return BibleRepositoryImpl(
    api ?? _MockApi(books: _defaultBooks, versions: _defaultVersions),
    CatalogCache.noop(),
  );
}

const _defaultBooks = [
  BibleBook(
    id: 1,
    name: 'Gênesis',
    abbreviation: 'Gn',
    chapters: 50,
    bookNumber: 1,
  ),
  BibleBook(
    id: 40,
    name: 'Mateus',
    abbreviation: 'Mt',
    chapters: 28,
    bookNumber: 40,
  ),
];

const _defaultVersions = [
  BibleVersion(id: 1, abbreviation: 'ARA', name: 'ARA'),
];

void main() {
  group('BibleBloc', () {
    test('bootstrap carrega livros, versoes e primeiro capitulo', () async {
      final repo = _repo(
        api: _MockApi(
          books: _defaultBooks,
          versions: _defaultVersions,
          chapterVerses: {'1': 'No princípio', '2': 'E a terra'},
        ),
      );
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      expect(bloc.state, isA<BibleLoaded>());
      final state = bloc.state as BibleLoaded;
      expect(state.books.length, 2);
      expect(state.versions.length, 1);
      expect(state.selectedVersionId, 1); // ARA
      expect(state.verses['1'], 'No princípio');
      await bloc.close();
    });

    test('bootstrap com erro emite BibleError', () async {
      final repo = _repo(api: _MockApi(fail: true));
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      expect(bloc.state, isA<BibleError>());
      await bloc.close();
    });

    test('selectBook carrega capitulos do novo livro', () async {
      final repo = _repo(
        api: _MockApi(
          books: _defaultBooks,
          versions: _defaultVersions,
          chapterVerses: {'1': 'v1'},
        ),
      );
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      bloc.add(BibleSelectBook(40));
      await Future.delayed(const Duration(milliseconds: 300));

      final state = bloc.state as BibleLoaded;
      expect(state.selectedBookId, 40);
      expect(state.selectedChapter, 1);
      await bloc.close();
    });

    test('selectChapter carrega versiculos', () async {
      final repo = _repo(
        api: _MockApi(
          books: _defaultBooks,
          versions: _defaultVersions,
          chapterVerses: {'1': 'cap3v1'},
        ),
      );
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      bloc.add(BibleSelectChapter(3));
      await Future.delayed(const Duration(milliseconds: 300));

      final state = bloc.state as BibleLoaded;
      expect(state.selectedChapter, 3);
      expect(state.verses['1'], 'cap3v1');
      await bloc.close();
    });

    test('selectVerse adiciona versiculo a selecao', () async {
      final repo = _repo(
        api: _MockApi(
          books: _defaultBooks,
          versions: _defaultVersions,
          chapterVerses: {'1': 'v1', '2': 'v2', '3': 'v3'},
        ),
      );
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      bloc.add(const BibleSelectVerse(2));
      await Future.delayed(const Duration(milliseconds: 100));

      final state = bloc.state as BibleLoaded;
      expect(state.selectedVerses, [2]);
      await bloc.close();
    });

    test(
      'selectVerse substitui selecao anterior (mobile = tap simples)',
      () async {
        final repo = _repo(
          api: _MockApi(
            books: _defaultBooks,
            versions: _defaultVersions,
            chapterVerses: {'1': 'v1', '2': 'v2'},
          ),
        );
        final bloc = BibleBloc(repo);

        bloc.add(BibleBootstrap());
        await Future.delayed(const Duration(milliseconds: 300));

        bloc.add(const BibleSelectVerse(1));
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(const BibleSelectVerse(2));
        await Future.delayed(const Duration(milliseconds: 100));

        final state = bloc.state as BibleLoaded;
        expect(state.selectedVerses, [2]); // substituiu, nao acumulou
        await bloc.close();
      },
    );

    test('clearSelection remove versiculos selecionados', () async {
      final repo = _repo(
        api: _MockApi(
          books: _defaultBooks,
          versions: _defaultVersions,
          chapterVerses: {'1': 'v1'},
        ),
      );
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      bloc.add(const BibleSelectVerse(1));
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(BibleClearSelection());
      await Future.delayed(const Duration(milliseconds: 100));

      final state = bloc.state as BibleLoaded;
      expect(state.selectedVerses, isEmpty);
      await bloc.close();
    });

    test('selectVersion muda versao e recarrega capitulo', () async {
      final repo = _repo(
        api: _MockApi(
          books: _defaultBooks,
          versions: [
            const BibleVersion(id: 1, abbreviation: 'ARA', name: 'ARA'),
            const BibleVersion(id: 2, abbreviation: 'NVI', name: 'NVI'),
          ],
          chapterVerses: {'1': 'NVI text'},
        ),
      );
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      bloc.add(BibleSelectVersion(2));
      await Future.delayed(const Duration(milliseconds: 300));

      final state = bloc.state as BibleLoaded;
      expect(state.selectedVersionId, 2);
      expect(state.verses['1'], 'NVI text');
      await bloc.close();
    });

    test('locationLabel formatado corretamente', () async {
      final repo = _repo(
        api: _MockApi(
          books: _defaultBooks,
          versions: _defaultVersions,
          chapterVerses: {'1': 'v1', '2': 'v2'},
        ),
      );
      final bloc = BibleBloc(repo);

      bloc.add(BibleBootstrap());
      await Future.delayed(const Duration(milliseconds: 300));

      bloc.add(const BibleSelectVerse(1));
      await Future.delayed(const Duration(milliseconds: 100));

      final state = bloc.state as BibleLoaded;
      expect(state.locationLabel, contains('Gênesis'));
      expect(state.locationLabel, contains('ARA'));
      await bloc.close();
    });
  });
}
