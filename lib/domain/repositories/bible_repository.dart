library;

import '../../domain/entities/bible_book.dart';
import '../../domain/entities/bible_version.dart';

/// Contrato para acesso aos dados bíblicos.
abstract interface class BibleRepository {
  /// 66 livros bíblicos ordenados por bookNumber.
  Future<List<BibleBook>> getBooks();

  /// Versões/traduções disponíveis.
  Future<List<BibleVersion>> getVersions();

  /// Versículos de um capítulo: Map de string para string.
  Future<Map<String, String>> getChapter(
    int versionId,
    int bookId,
    int chapter,
  );
}
