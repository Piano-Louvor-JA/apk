import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/domain/repositories/bible_repository.dart';

/// Catálogos e detalhes da Liturgia: cache persistente por idioma antes da rede.
class LiturgyCatalogRepository implements BibleRepository {
  LiturgyCatalogRepository(this.prefs, this.api, {String locale = 'pt'})
    : locale = LiturgyRepository.languageOf(locale);
  final SharedPreferences prefs;
  final LouvorjaApiClient api;
  final String locale;
  static Future<LiturgyCatalogRepository> open(String locale) async =>
      LiturgyCatalogRepository(
        await SharedPreferences.getInstance(),
        LouvorjaApiImpl(
          baseUrls: ApiConfig.databaseUrls(),
          filesUrls: ApiConfig.filesUrls(),
          apiToken: ApiConfig.apiToken,
          languagePrefix: LiturgyRepository.languageOf(locale),
        ),
        locale: locale,
      );
  String _key(String key) => 'liturgy.catalog.$locale.$key';
  Object? _read(String key) {
    try {
      return jsonDecode(prefs.getString(_key(key)) ?? 'null');
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, Object value) =>
      prefs.setString(_key(key), jsonEncode(value));
  static Map<String, dynamic> _hymn(Hymn h) => {
    ...h.toJson(),
    'duration': h.durationMs == null ? null : h.durationMs! / 1000,
    'lyric': h.lyricRaw ?? h.lyric,
    'url_image': h.imageUrl,
    'albums_names': h.albumNames,
    'album_ids': h.albumIds,
    'hymnal_tracks': h.hymnalTracks,
  };
  static Hymn _decodeHymn(Map<String, dynamic> raw) {
    final h = Hymn.fromJson(raw);
    return Hymn(
      id: h.id,
      title: h.title,
      number: h.number,
      durationMs: h.durationMs,
      hasInstrumental: h.hasInstrumental,
      urlMusic: h.urlMusic,
      urlInstrumental: h.urlInstrumental,
      lyric: h.lyric,
      lyricRaw: h.lyricRaw,
      imageUrl: h.imageUrl,
      albumNames: h.albumNames,
      albumIds: raw['album_ids'] is List
          ? (raw['album_ids'] as List).whereType<int>().toList()
          : h.albumIds,
      hymnalTracks: raw['hymnal_tracks'] is List
          ? (raw['hymnal_tracks'] as List).whereType<int>().toList()
          : h.hymnalTracks,
    );
  }

  /// Índice já atualizado nesta sessão, por idioma.
  static final Map<String, List<Hymn>> _sessionIndex = {};

  @visibleForTesting
  static void resetSessionIndex() => _sessionIndex.clear();

  /// Como a aba Hinos: a 1ª busca da sessão vem da rede (o disco gravado
  /// antes podia ser de outro catálogo e nunca se atualizava); o disco é
  /// só o fallback offline. Depois, a memória da sessão.
  Future<List<Hymn>> musicIndex({bool refresh = false}) async {
    final session = _sessionIndex[locale];
    if (!refresh && session != null) return session;
    final cached = _read('music_index');
    try {
      var hymns = await api.fetchMusicIndex();
      if (hymns.isEmpty) hymns = await api.fetchHymnal();
      await _write('music_index', hymns.map(_hymn).toList());
      return _sessionIndex[locale] = hymns;
    } catch (_) {
      if (cached is List)
        return cached
            .whereType<Map>()
            .map((e) => _decodeHymn(e.cast<String, dynamic>()))
            .toList();
      rethrow;
    }
  }

  Hymn? cachedMusic(int id) {
    final cached = _read('music_$id');
    if (cached is Map) return _decodeHymn(cached.cast<String, dynamic>());
    return null;
  }

  Future<Hymn> music(int id) async {
    final cached = cachedMusic(id);
    if (cached != null) return cached;
    final detail = await api.fetchMusic(id);
    await _write('music_$id', _hymn(detail));
    return detail;
  }

  @override
  Future<List<BibleBook>> getBooks() async {
    final cached = _read('bible_books');
    if (cached is List)
      return cached
          .whereType<Map>()
          .map((e) => BibleBook.fromJson(e.cast<String, dynamic>()))
          .toList();
    final books = await api.fetchBibleBooks();
    await _write('bible_books', books.map((e) => e.toJson()).toList());
    return books;
  }

  @override
  Future<List<BibleVersion>> getVersions() async {
    final cached = _read('bible_versions');
    if (cached is List)
      return cached
          .whereType<Map>()
          .map((e) => BibleVersion.fromJson(e.cast<String, dynamic>()))
          .toList();
    final versions = await api.fetchBibleVersions();
    await _write('bible_versions', versions.map((e) => e.toJson()).toList());
    return versions;
  }

  @override
  Future<Map<String, String>> getChapter(
    int versionId,
    int bookId,
    int chapter,
  ) async {
    final key = 'bible_${versionId}_${bookId}_$chapter';
    final cached = _read(key);
    if (cached is Map)
      return cached.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    final verses = await api.fetchBibleChapter(versionId, bookId, chapter);
    await _write(key, verses);
    return verses;
  }
}
