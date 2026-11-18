import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

/// Vídeo guardado (histórico, favorito ou item de coletânea).
/// `at`: quando tocou por último, quando favoritou ou quando entrou na
/// coletânea. `playCount` só conta no histórico.
class YoutubeSavedVideo {
  const YoutubeSavedVideo({
    required this.videoId,
    required this.title,
    this.channel = '',
    this.thumbnail = '',
    this.durationText = '',
    this.at = 0,
    this.playCount = 1,
  });

  final String videoId, title, channel, thumbnail, durationText;
  final int at, playCount;

  factory YoutubeSavedVideo.from(YoutubeVideo video, {int at = 0}) =>
      YoutubeSavedVideo(
        videoId: video.videoId,
        title: video.title.trim().isEmpty ? video.videoId : video.title.trim(),
        channel: video.channel.trim(),
        thumbnail: video.thumbnail,
        durationText: video.durationText,
        at: at,
      );

  YoutubeVideo toVideo() => YoutubeVideo(
    videoId: videoId,
    title: title,
    channel: channel,
    thumbnail: thumbnail,
    durationText: durationText,
  );

  static YoutubeSavedVideo? fromJson(Object? raw, {String atKey = 'playedAt'}) {
    if (raw is! Map) return null;
    String str(String key) => raw[key] is String ? raw[key] as String : '';
    final id = str('videoId');
    if (!YoutubeVideo.isValidId(id)) return null;
    final at = raw[atKey];
    final count = raw['playCount'];
    return YoutubeSavedVideo(
      videoId: id,
      title: str('title').isEmpty ? id : str('title'),
      channel: str('channel'),
      thumbnail: str('thumbnail'),
      durationText: str('durationText'),
      at: at is num && at > 0 ? at.toInt() : 0,
      playCount: count is num && count > 0 ? count.floor() : 1,
    );
  }

  Map<String, dynamic> toJson({String atKey = 'playedAt', bool count = true}) => {
    'videoId': videoId,
    'title': title,
    'channel': channel,
    'thumbnail': thumbnail,
    'durationText': durationText,
    atKey: at,
    if (count) 'playCount': playCount,
  };
}

/// Coletânea online: vídeos do YouTube na ordem escolhida pelo operador.
class YoutubeCollection {
  const YoutubeCollection({
    required this.id,
    required this.name,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.videos = const [],
  });
  final String id, name;
  final int createdAt, updatedAt;
  final List<YoutubeSavedVideo> videos;

  bool has(String videoId) => videos.any((v) => v.videoId == videoId);

  YoutubeCollection copyWith({
    String? name,
    int? updatedAt,
    List<YoutubeSavedVideo>? videos,
  }) => YoutubeCollection(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    videos: videos ?? this.videos,
  );

  static YoutubeCollection? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'] is String ? raw['id'] as String : '';
    final name = raw['name'] is String ? (raw['name'] as String).trim() : '';
    if (id.isEmpty || name.isEmpty) return null;
    int num0(Object? v) => v is num && v > 0 ? v.toInt() : 0;
    final seen = <String>{};
    final videos = <YoutubeSavedVideo>[];
    for (final item in raw['videos'] is List ? raw['videos'] as List : const []) {
      final video = YoutubeSavedVideo.fromJson(item, atKey: 'addedAt');
      if (video != null && seen.add(video.videoId)) videos.add(video);
    }
    return YoutubeCollection(
      id: id,
      name: name,
      createdAt: num0(raw['createdAt']),
      updatedAt: num0(raw['updatedAt']),
      videos: videos,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'videos': [
      for (final v in videos) v.toJson(atKey: 'addedAt', count: false),
    ],
  };
}

/// Histórico, favoritos, buscas recentes e coletâneas do módulo YouTube,
/// salvos no aparelho. Mesmas regras (e nomes de chave) do desktop.
class YoutubeLibraryStorage {
  YoutubeLibraryStorage({
    Future<SharedPreferences> Function()? prefs,
    int Function()? clock,
  }) : _prefs = prefs ?? SharedPreferences.getInstance,
       _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final Future<SharedPreferences> Function() _prefs;
  final int Function() _clock;

  static const historyKey = 'louvorja-youtube-history-v1';
  static const favoritesKey = 'louvorja-youtube-favorites-v1';
  static const queriesKey = 'louvorja-youtube-queries-v1';
  static const collectionsKey = 'louvorja-youtube-collections-v1';

  static const historyMax = 300;
  static const favoritesMax = 500;
  static const recentQueriesMax = 10;
  static const collectionNameMax = 80;
  static const collectionVideosMax = 500;

  Future<List<Object?>> _readList(String key) async {
    final raw = (await _prefs()).getString(key);
    if (raw == null) return const [];
    try {
      final parsed = jsonDecode(raw);
      return parsed is List ? parsed : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _write(String key, Object value) async =>
      (await _prefs()).setString(key, jsonEncode(value));

  /* ---------- Histórico ---------- */

  /// Do mais recente para o mais antigo; inválidos e repetidos saem.
  Future<List<YoutubeSavedVideo>> history() async {
    final seen = <String>{};
    final list = <YoutubeSavedVideo>[];
    for (final item in await _readList(historyKey)) {
      final entry = YoutubeSavedVideo.fromJson(item);
      if (entry != null && seen.add(entry.videoId)) list.add(entry);
    }
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  Future<List<YoutubeSavedVideo>> _saveHistory(
    List<YoutubeSavedVideo> list,
  ) async {
    final trimmed = list.take(historyMax).toList();
    await _write(historyKey, [for (final e in trimmed) e.toJson()]);
    return trimmed;
  }

  /// Tocou: sobe para o topo e soma uma reprodução.
  Future<List<YoutubeSavedVideo>> recordPlay(YoutubeVideo video) async {
    final list = await history();
    if (!YoutubeVideo.isValidId(video.videoId)) return list;
    final previous = list.where((e) => e.videoId == video.videoId).firstOrNull;
    String pick(String value, String? old) =>
        value.trim().isNotEmpty ? value.trim() : (old ?? '');
    final entry = YoutubeSavedVideo(
      videoId: video.videoId,
      title: pick(video.title, previous?.title).isEmpty
          ? video.videoId
          : pick(video.title, previous?.title),
      channel: pick(video.channel, previous?.channel),
      thumbnail: pick(video.thumbnail, previous?.thumbnail),
      durationText: pick(video.durationText, previous?.durationText),
      at: _clock(),
      playCount: (previous?.playCount ?? 0) + 1,
    );
    return _saveHistory([
      entry,
      ...list.where((e) => e.videoId != video.videoId),
    ]);
  }

  Future<List<YoutubeSavedVideo>> removeFromHistory(String videoId) async =>
      _saveHistory((await history()).where((e) => e.videoId != videoId).toList());

  Future<List<YoutubeSavedVideo>> clearHistory() => _saveHistory(const []);

  /* ---------- Buscas recentes ---------- */

  Future<List<String>> recentQueries() async => (await _readList(queriesKey))
      .whereType<String>()
      .where((q) => q.trim().isNotEmpty)
      .take(recentQueriesMax)
      .toList();

  Future<List<String>> rememberQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) return recentQueries();
    final next = [
      q,
      ...(await recentQueries()).where(
        (item) => item.toLowerCase() != q.toLowerCase(),
      ),
    ].take(recentQueriesMax).toList();
    await _write(queriesKey, next);
    return next;
  }

  Future<List<String>> forgetQuery(String query) async {
    final next = (await recentQueries()).where((q) => q != query).toList();
    await _write(queriesKey, next);
    return next;
  }

  /* ---------- Favoritos ---------- */

  Future<List<YoutubeSavedVideo>> favorites() async {
    final seen = <String>{};
    final list = <YoutubeSavedVideo>[];
    for (final item in await _readList(favoritesKey)) {
      final entry = YoutubeSavedVideo.fromJson(item);
      if (entry != null && seen.add(entry.videoId)) list.add(entry);
    }
    return list;
  }

  Future<List<YoutubeSavedVideo>> _saveFavorites(
    List<YoutubeSavedVideo> list,
  ) async {
    final trimmed = list.take(favoritesMax).toList();
    await _write(favoritesKey, [
      for (final e in trimmed) e.toJson(count: false),
    ]);
    return trimmed;
  }

  /// Liga/desliga; ao favoritar, entra no topo.
  Future<List<YoutubeSavedVideo>> toggleFavorite(YoutubeVideo video) async {
    final list = await favorites();
    if (!YoutubeVideo.isValidId(video.videoId)) return list;
    if (list.any((e) => e.videoId == video.videoId)) {
      return _saveFavorites(
        list.where((e) => e.videoId != video.videoId).toList(),
      );
    }
    return _saveFavorites([YoutubeSavedVideo.from(video, at: _clock()), ...list]);
  }

  /* ---------- Coletâneas ---------- */

  Future<List<YoutubeCollection>> collections() async {
    final seen = <String>{};
    final list = <YoutubeCollection>[];
    for (final item in await _readList(collectionsKey)) {
      final c = YoutubeCollection.fromJson(item);
      if (c != null && seen.add(c.id)) list.add(c);
    }
    return list;
  }

  Future<List<YoutubeCollection>> _saveCollections(
    List<YoutubeCollection> list,
  ) async {
    await _write(collectionsKey, [for (final c in list) c.toJson()]);
    return list;
  }

  static String cleanName(String name) {
    final clean = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length > collectionNameMax
        ? clean.substring(0, collectionNameMax)
        : clean;
  }

  String _newId(int now) {
    final random = Random();
    final suffix = List.generate(
      10,
      (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)],
    ).join();
    return 'yc-${now.toRadixString(36)}-$suffix';
  }

  /// Cria a coletânea; `created` nulo quando o nome fica vazio.
  Future<({List<YoutubeCollection> list, YoutubeCollection? created})>
  createCollection(String name) async {
    final clean = cleanName(name);
    final list = await collections();
    if (clean.isEmpty) return (list: list, created: null);
    final now = _clock();
    final created = YoutubeCollection(
      id: _newId(now),
      name: clean,
      createdAt: now,
      updatedAt: now,
    );
    return (list: await _saveCollections([...list, created]), created: created);
  }

  Future<List<YoutubeCollection>> _update(
    String id,
    YoutubeCollection? Function(YoutubeCollection c) change,
  ) async {
    final list = await collections();
    final index = list.indexWhere((c) => c.id == id);
    if (index < 0) return list;
    final next = change(list[index]);
    if (next == null) return list;
    final copy = [...list];
    copy[index] = next.copyWith(updatedAt: _clock());
    return _saveCollections(copy);
  }

  Future<List<YoutubeCollection>> renameCollection(String id, String name) {
    final clean = cleanName(name);
    return _update(
      id,
      (c) => clean.isNotEmpty && clean != c.name ? c.copyWith(name: clean) : null,
    );
  }

  Future<List<YoutubeCollection>> deleteCollection(String id) async =>
      _saveCollections((await collections()).where((c) => c.id != id).toList());

  /// Vários de uma vez (importar playlist ou o botão +): na ordem, sem
  /// repetir, até o limite.
  Future<List<YoutubeCollection>> addVideos(
    String id,
    List<YoutubeVideo> videos,
  ) {
    final now = _clock();
    return _update(id, (c) {
      final seen = c.videos.map((v) => v.videoId).toSet();
      final next = [...c.videos];
      for (final video in videos) {
        if (next.length >= collectionVideosMax) break;
        if (!YoutubeVideo.isValidId(video.videoId) || !seen.add(video.videoId)) {
          continue;
        }
        next.add(YoutubeSavedVideo.from(video, at: now));
      }
      return next.length == c.videos.length ? null : c.copyWith(videos: next);
    });
  }

  Future<List<YoutubeCollection>> addVideo(String id, YoutubeVideo video) =>
      addVideos(id, [video]);

  Future<List<YoutubeCollection>> removeVideo(String id, String videoId) =>
      _update(
        id,
        (c) => c.has(videoId)
            ? c.copyWith(
                videos: c.videos.where((v) => v.videoId != videoId).toList(),
              )
            : null,
      );

  /// Move uma posição para cima (-1) ou para baixo (+1).
  Future<List<YoutubeCollection>> moveVideo(String id, String videoId, int delta) =>
      _update(id, (c) {
        final from = c.videos.indexWhere((v) => v.videoId == videoId);
        final to = from + delta;
        if (from < 0 || to < 0 || to >= c.videos.length) return null;
        final videos = [...c.videos];
        final moved = videos.removeAt(from);
        videos.insert(to, moved);
        return c.copyWith(videos: videos);
      });
}

/// Filtro por título ou canal, sem acento e com todos os termos (AND).
List<T> filterYoutubeVideos<T>(
  List<T> list,
  String query,
  String Function(T item) text,
) {
  final terms = foldYoutubeText(
    query,
  ).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (terms.isEmpty) return list;
  return list.where((item) {
    final haystack = foldYoutubeText(text(item));
    return terms.every(haystack.contains);
  }).toList();
}

String foldYoutubeText(String text) {
  const from = 'àáâãäåèéêëìíîïòóôõöùúûüçñýÿ';
  const to = 'aaaaaaeeeeiiiiooooouuuucnyy';
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    out.write(i >= 0 ? to[i] : ch);
  }
  return out.toString();
}
