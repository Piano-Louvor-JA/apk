library;

import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/repositories/bible_repository.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';

/// Implementação de [BibleRepository] com cache local opcional.
class BibleRepositoryImpl implements BibleRepository {
  final LouvorjaApiClient _api;
  final CatalogCache _cache;

  BibleRepositoryImpl(this._api, this._cache);

  @override
  Future<List<BibleBook>> getBooks() async {
    // Tenta cache primeiro
    final cached = _cache.read('bible_books');
    if (cached != null && cached is List) {
      final parsed = cached
          .map((e) => BibleBook.fromJson(e as Map<String, dynamic>))
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }

    try {
      final books = await _api.fetchBibleBooks();
      final sorted = [...books]
        ..sort((a, b) => a.bookNumber.compareTo(b.bookNumber));
      _cache.write('bible_books', sorted.map((b) => b.toJson()).toList());
      return sorted;
    } catch (_) {
      if (cached != null && cached is List) {
        return cached
            .map((e) => BibleBook.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  @override
  Future<List<BibleVersion>> getVersions() async {
    final cached = _cache.read('bible_versions');
    if (cached != null && cached is List) {
      final parsed = cached
          .map((e) => BibleVersion.fromJson(e as Map<String, dynamic>))
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }

    try {
      final versions = await _api.fetchBibleVersions();
      _cache.write('bible_versions', versions.map((v) => v.toJson()).toList());
      return versions;
    } catch (_) {
      if (cached != null && cached is List) {
        return cached
            .map((e) => BibleVersion.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> getChapter(
    int versionId,
    int bookId,
    int chapter,
  ) async {
    final cacheKey = 'bible_${versionId}_${bookId}_$chapter';

    final cached = _cache.read(cacheKey);
    if (cached != null && cached is Map) {
      final parsed = cached.map((k, v) => MapEntry(k.toString(), v.toString()));
      if (parsed.isNotEmpty) return parsed;
    }

    try {
      final verses = await _api.fetchBibleChapter(versionId, bookId, chapter);
      _cache.write(cacheKey, verses);
      return verses;
    } catch (_) {
      if (cached != null && cached is Map) {
        return cached.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      rethrow;
    }
  }
}
