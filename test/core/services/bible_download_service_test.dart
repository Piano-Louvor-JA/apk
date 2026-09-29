library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/bible_download_service.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/repositories/bible_repository.dart';

class _FakeRepo implements BibleRepository {
  final Set<String> fetched = {};
  final Set<String> failOn = {};

  @override
  Future<Map<String, String>> getChapter(
    int versionId,
    int bookId,
    int chapter,
  ) async {
    final key = '$versionId-$bookId-$chapter';
    if (failOn.contains(key)) throw Exception('network');
    fetched.add(key);
    return {chapter.toString(): 'versículo'};
  }

  @override
  Future<List<BibleBook>> getBooks() async => throw UnimplementedError();

  @override
  noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  test('baixa todos os capítulos de todos os livros da versão', () async {
    final repo = _FakeRepo();
    final svc = BibleDownloadService(repo);
    final books = const [
      BibleBook(
        id: 1,
        name: 'Gênesis',
        abbreviation: 'gn',
        bookNumber: 1,
        chapters: 2,
      ),
      BibleBook(
        id: 66,
        name: 'Apocalipse',
        abbreviation: 'ap',
        bookNumber: 66,
        chapters: 1,
      ),
    ];

    final progress = <int>[];
    final (done, failed) = await svc.downloadVersion(
      versionId: 12,
      books: books,
      onProgress: (d, t) => progress.add(d),
    );

    expect(done, 3);
    expect(failed, 0);
    expect(repo.fetched, containsAll(['12-1-1', '12-1-2', '12-66-1']));
    expect(progress.last, 3);
  });

  test(
    'capítulo que falha é pulado e contabilizado, sem derrubar o resto',
    () async {
      final repo = _FakeRepo()..failOn.add('12-1-2');
      final svc = BibleDownloadService(repo);
      final books = const [
        BibleBook(
          id: 1,
          name: 'Gn',
          abbreviation: 'gn',
          bookNumber: 1,
          chapters: 3,
        ),
      ];

      final (done, failed) = await svc.downloadVersion(
        versionId: 12,
        books: books,
      );

      expect(done, 2);
      expect(failed, 1);
      expect(repo.fetched, containsAll(['12-1-1', '12-1-3']));
    },
  );
}
