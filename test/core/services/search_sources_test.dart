library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/search_sources.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

void main() {
  group('SearchSources', () {
    test('loadHymnSources agrega hinos de todos os albuns', () async {
      final hymns = await SearchSources.loadHymnSources(
        repository: _FakeHymnRepo({
          1: [Hymn(id: 1, title: 'Hino A', number: 1, hasInstrumental: false)],
          2: [
            Hymn(id: 2, title: 'Hino B', number: 2, hasInstrumental: false),
            Hymn(id: 3, title: 'Hino C', number: 3, hasInstrumental: false),
          ],
        }),
      );

      expect(hymns, hasLength(3));
      expect(hymns.map((h) => h.id), containsAll([1, 2, 3]));
    });

    test('loadHymnSources com erro em um album continua os outros', () async {
      final hymns = await SearchSources.loadHymnSources(
        repository: _FakeHymnRepo({
          1: [Hymn(id: 1, title: 'Hino A', number: 1, hasInstrumental: false)],
          2: null, // simula erro
        }),
      );

      expect(hymns, hasLength(1));
    });

    test('loadBibleSources extrai versiculos com nome do livro', () async {
      final verses = await SearchSources.loadBibleSources(
        repository: _FakeBibleRepo(),
      );

      expect(verses, hasLength(2));
      expect(verses.first.bookName, 'Livro 1');
      expect(verses.first.verse, 1);
    });

    test('limita livros carregados para performance', () async {
      final repo = _FakeBibleRepo(bookCount: 90);
      await SearchSources.loadBibleSources(repository: repo, maxBooks: 10);

      expect(repo.requestedBooks.length, lessThanOrEqualTo(10));
    });
  });
}

class _FakeHymnRepo implements HymnRepositoryView {
  final Map<int, List<Hymn>?> albums;
  _FakeHymnRepo(this.albums);

  @override
  Future<List<int>> getAlbumIds() async => albums.keys.toList();

  @override
  Future<List<Hymn>> getHymnsByAlbum(int albumId) async {
    final result = albums[albumId];
    if (result == null) throw Exception('erro');
    return result;
  }
}

class _FakeBibleRepo implements BibleRepositoryView {
  final int bookCount;
  final requestedBooks = <int>[];
  _FakeBibleRepo({this.bookCount = 1});

  @override
  Future<List<BibleBookInfo>> getBooks() async => List.generate(
    bookCount,
    (i) => BibleBookInfo(id: i + 1, name: 'Livro ${i + 1}', chapters: 1),
  );

  @override
  Future<Map<String, String>> getChapter(
    int versionId,
    int bookId,
    int chapter,
  ) async {
    requestedBooks.add(bookId);
    return {'1': 'Porque Deus amou o mundo', '16': 'texto do versiculo'};
  }
}
