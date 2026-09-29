library;

import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';

/// Índice de busca global da Bíblia construído a partir do cache local.
///
/// Cada capítulo visitado (ou baixado) vira um registro pesquisável.
/// Versão com download completo indexa todos os capítulos de uma vez.
/// Busca é 100% local: nenhuma chamada de API por tecla.
class BibleSearchIndex {
  final CatalogCache _cache;

  BibleSearchIndex(this._cache);

  static final _chapterKey = RegExp(r'^bible_(\d+)_(\d+)_(\d+)$');

  bool _booksLoaded = false;
  final Map<int, BibleBook> _booksById = {};

  Future<void> _ensureBooks(List<BibleBook> books) async {
    if (_booksLoaded) return;
    _booksById
      ..clear()
      ..addEntries(books.map((b) => MapEntry(b.id, b)));
    _booksLoaded = true;
  }

  /// Capítulos atualmente em cache para [versionId].
  /// Formato: (bookId, chapter).
  List<(int, int)> cachedChapters(int versionId) {
    final prefix = 'bible_${versionId}_';
    final chapters = <(int, int)>[];
    for (final key in _cache.listKeys()) {
      if (!key.startsWith(prefix)) continue;
      final m = _chapterKey.firstMatch(key);
      if (m == null) continue;
      final bookId = int.tryParse(m.group(2)!);
      final chapter = int.tryParse(m.group(3)!);
      if (bookId != null && chapter != null) {
        chapters.add((bookId, chapter));
      }
    }
    chapters.sort((a, b) {
      final byBook = a.$1.compareTo(b.$1);
      if (byBook != 0) return byBook;
      return a.$2.compareTo(b.$2);
    });
    return chapters;
  }

  /// Busca texto em todos os capítulos cacheados da versão.
  ///
  /// Retorna no máximo [limit] resultados ordenados por relevância:
  /// palavra exata > prefixo > substring; livro/capítulo menor primeiro.
  Future<List<BibleGlobalSearchResult>> search(
    String query,
    int versionId,
    List<BibleBook> books, {
    int limit = 30,
  }) async {
    await _ensureBooks(books);
    final q = _normalize(query);
    if (q.length < 3) return const [];

    final results = <BibleGlobalSearchResult>[];
    for (final (bookId, chapter) in cachedChapters(versionId)) {
      final raw = _cache.read('bible_${versionId}_${bookId}_$chapter');
      if (raw is! Map) continue;
      for (final entry in raw.entries) {
        final verseNum = int.tryParse(entry.key.toString());
        if (verseNum == null) continue;
        final text = _normalize(entry.value.toString());
        final score = _score(text, q);
        if (score > 0) {
          results.add(
            BibleGlobalSearchResult(
              bookId: bookId,
              bookName: _booksById[bookId]?.name ?? 'Livro $bookId',
              chapter: chapter,
              verse: verseNum,
              text: entry.value.toString(),
              score: score,
            ),
          );
        }
      }
    }

    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byBook = (a.bookId * 1000 + a.chapter).compareTo(
        b.bookId * 1000 + b.chapter,
      );
      if (byBook != 0) return byBook;
      return a.verse.compareTo(b.verse);
    });
    return results.take(limit).toList();
  }

  /// Pontuação simples de relevância. 0 = não corresponde.
  static int _score(String text, String q) {
    if (text.contains(q)) {
      // Palavra que começa com a query pesa mais que substring.
      final wordStart = RegExp('(?:^|\\s)$q');
      return wordStart.hasMatch(text) ? 3 : 2;
    }
    return 0;
  }

  static String _normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp('[áàâãä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôõö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .trim();
}

class BibleGlobalSearchResult {
  final int bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;
  final int score;

  const BibleGlobalSearchResult({
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.score,
  });

  /// Referência curta: `João 3:16`.
  String get reference => '$bookName $chapter:$verse';

  /// Trecho para exibição: texto limitado com reticências.
  String get snippet => text.length <= 90 ? text : '${text.substring(0, 90)}…';
}
