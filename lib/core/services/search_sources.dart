library;

import 'global_search_service.dart';
import '../../domain/entities/hymn.dart';

/// Dados minimos que o agregador de fontes precisa do repositorio de hinos.
abstract interface class HymnRepositoryView {
  Future<List<int>> getAlbumIds();
  Future<List<Hymn>> getHymnsByAlbum(int albumId);
}

/// Dados minimos que o agregador de fontes precisa do repositorio da biblia.
abstract interface class BibleRepositoryView {
  Future<List<BibleBookInfo>> getBooks();
  Future<Map<String, String>> getChapter(
    int versionId,
    int bookId,
    int chapter,
  );
}

/// Info leve de livro biblico para busca (id, nome, capitulos).
class BibleBookInfo {
  final int id;
  final String name;
  final int chapters;

  const BibleBookInfo({
    required this.id,
    required this.name,
    required this.chapters,
  });
}

/// Agrega fontes reais (hinos + biblia) para a busca global.
///
/// Desacoplado dos repos concretos via interfaces minimas — permite
/// testar com fakes e trocar a fonte sem tocar o service de busca.
abstract final class SearchSources {
  /// Carrega todos os hinos de todos os albuns (com tolerancia a falha
  /// por album: um album que falha nao derruba os demais).
  static Future<List<Hymn>> loadHymnSources({
    required HymnRepositoryView repository,
  }) async {
    final all = <Hymn>[];
    final albumIds = await repository.getAlbumIds();
    for (final id in albumIds) {
      try {
        all.addAll(await repository.getHymnsByAlbum(id));
      } catch (_) {
        // Album com erro e pulado; busca parcial e melhor que nenhuma.
      }
    }
    return all;
  }

  /// Carrega o capitulo 1 de ate [maxBooks] livros como versiculos
  /// pesquisaveis. Limitar evita dezenas de requests na primeira busca.
  static Future<List<BibleVerseRef>> loadBibleSources({
    required BibleRepositoryView repository,
    int versionId = 1,
    int maxBooks = 5,
  }) async {
    final verses = <BibleVerseRef>[];
    final books = await repository.getBooks();
    for (final book in books.take(maxBooks)) {
      try {
        final chapter = await repository.getChapter(versionId, book.id, 1);
        chapter.forEach((verseNum, text) {
          final n = int.tryParse(verseNum);
          if (n == null || text.trim().isEmpty) return;
          verses.add(
            BibleVerseRef(
              bookId: book.id,
              bookName: book.name,
              chapter: 1,
              verse: n,
              text: text,
            ),
          );
        });
      } catch (_) {
        // Livro sem capitulo disponivel e pulado.
      }
    }
    return verses;
  }
}
