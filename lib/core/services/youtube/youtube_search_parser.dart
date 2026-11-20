import 'dart:convert';

import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

/// Leitura das páginas do YouTube sem chave de API (mesma regra do desktop,
/// `electron/youtube-search.mjs`): o `ytInitialData` da página e os JSONs de
/// continuação. Os dois formatos de item: `videoRenderer` (antigo) e
/// `lockupViewModel` (2025+).
class YoutubeSearchParser {
  const YoutubeSearchParser._();

  static const searchKeys = ['videoRenderer', 'lockupViewModel'];
  static const playlistKeys = [
    'lockupViewModel',
    'playlistVideoRenderer',
    'playlistPanelVideoRenderer',
    'videoRenderer',
  ];

  /// Objeto JSON logo depois de [marker], respeitando strings e escapes.
  static Map<String, dynamic>? extractJsonAfter(String html, String marker) {
    final at = html.indexOf(marker);
    if (at < 0) return null;
    final start = html.indexOf('{', at + marker.length);
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < html.length; i++) {
      final c = html[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
      } else if (c == '"') {
        inString = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}' && --depth == 0) {
        try {
          final decoded = jsonDecode(html.substring(start, i + 1));
          return decoded is Map<String, dynamic> ? decoded : null;
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  /// `ytInitialData` da página (os dois jeitos que o YouTube escreve).
  static Map<String, dynamic>? initialData(String html) =>
      extractJsonAfter(html, 'ytInitialData = ') ??
      extractJsonAfter(html, 'ytInitialData"] = ');

  static String? readConfig(String html, String name) =>
      RegExp('"$name"\\s*:\\s*"([^"]+)"').firstMatch(html)?.group(1);

  static Map? _map(Object? value) => value is Map ? value : null;
  static List _list(Object? value) => value is List ? value : const [];

  static String textOf(Object? node) {
    final map = _map(node);
    if (map == null) return '';
    final simple = map['simpleText'];
    if (simple is String) return simple.trim();
    final runs = map['runs'];
    if (runs is List) {
      return runs
          .map((run) => _map(run)?['text']?.toString() ?? '')
          .join()
          .trim();
    }
    return '';
  }

  static String _stripQuery(String url) => url.split('?').first;

  /// `videoRenderer` → vídeo; `null` sem id válido ou sem título.
  static YoutubeVideo? videoFromRenderer(Object? raw) {
    final renderer = _map(raw);
    if (renderer == null) return null;
    final videoId = renderer['videoId'] is String
        ? renderer['videoId'] as String
        : '';
    final title = textOf(renderer['title']);
    if (!YoutubeVideo.isValidId(videoId) || title.isEmpty) return null;
    final thumbs = _list(_map(renderer['thumbnail'])?['thumbnails']);
    final thumb = thumbs.isNotEmpty
        ? (_map(thumbs.last)?['url']?.toString() ?? '')
        : '';
    final live = _list(renderer['badges']).any(
      (badge) => RegExp('LIVE', caseSensitive: false).hasMatch(
        _map(_map(badge)?['metadataBadgeRenderer'])?['style']?.toString() ?? '',
      ),
    );
    final channel = [
      textOf(renderer['ownerText']),
      textOf(renderer['longBylineText']),
      textOf(renderer['shortBylineText']),
    ].firstWhere((text) => text.isNotEmpty, orElse: () => '');
    final views = textOf(renderer['shortViewCountText']);
    final stripped = _stripQuery(thumb);
    return YoutubeVideo(
      videoId: videoId,
      title: title,
      channel: channel,
      durationText: textOf(renderer['lengthText']),
      viewsText: views.isNotEmpty ? views : textOf(renderer['viewCountText']),
      publishedText: textOf(renderer['publishedTimeText']),
      thumbnail: stripped.isNotEmpty
          ? stripped
          : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      live: live,
    );
  }

  /// Formato novo (`lockupViewModel` com `contentType` de vídeo).
  static YoutubeVideo? videoFromLockup(Object? raw) {
    final lockup = _map(raw);
    if (lockup == null ||
        lockup['contentType'] != 'LOCKUP_CONTENT_TYPE_VIDEO') {
      return null;
    }
    final videoId = lockup['contentId'] is String
        ? lockup['contentId'] as String
        : '';
    final meta = _map(_map(lockup['metadata'])?['lockupMetadataViewModel']);
    final rawTitle = _map(meta?['title'])?['content'];
    final title = rawTitle is String ? rawTitle.trim() : '';
    if (!YoutubeVideo.isValidId(videoId) || title.isEmpty) return null;
    final rows = _list(
      _map(
        _map(meta?['metadata'])?['contentMetadataViewModel'],
      )?['metadataRows'],
    );
    final parts = [
      for (final row in rows)
        [
          for (final part in _list(_map(row)?['metadataParts']))
            (_map(_map(part)?['text'])?['content']?.toString() ?? '').trim(),
        ].where((text) => text.isNotEmpty).toList(),
    ];
    String part(int row, int index) =>
        row < parts.length && index < parts[row].length
        ? parts[row][index]
        : '';
    final thumb = _map(_map(lockup['contentImage'])?['thumbnailViewModel']);
    final sources = _list(_map(thumb?['image'])?['sources']);
    var durationText = '';
    for (final overlay in _list(thumb?['overlays'])) {
      final badges = _list(
        _map(
          _map(overlay)?['thumbnailOverlayBadgeViewModel'],
        )?['thumbnailBadges'],
      );
      for (final badge in badges) {
        final text = _map(_map(badge)?['thumbnailBadgeViewModel'])?['text'];
        if (text is String && RegExp(r'\d:\d').hasMatch(text)) {
          durationText = text.trim();
        }
      }
    }
    final last = sources.isNotEmpty
        ? _stripQuery(_map(sources.last)?['url']?.toString() ?? '')
        : '';
    return YoutubeVideo(
      videoId: videoId,
      title: title,
      channel: part(0, 0),
      durationText: durationText,
      viewsText: part(1, 0),
      publishedText: part(1, 1),
      thumbnail: last.isNotEmpty
          ? last
          : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
    );
  }

  /// Vídeos em ordem (sem repetir) e o primeiro token de continuação.
  static ({List<YoutubeVideo> items, String? token}) collect(
    Object? root, [
    List<String> rendererKeys = searchKeys,
  ]) {
    final items = <YoutubeVideo>[];
    final seen = <String>{};
    String? token;
    final stack = <Object?>[root];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (node is List) {
        for (var i = node.length - 1; i >= 0; i--) {
          stack.add(node[i]);
        }
        continue;
      }
      if (node is! Map) continue;
      final key = rendererKeys.cast<String?>().firstWhere(
        (k) => node[k] != null,
        orElse: () => null,
      );
      if (key != null) {
        final video = key == 'lockupViewModel'
            ? videoFromLockup(node[key])
            : videoFromRenderer(node[key]);
        if (video != null && seen.add(video.videoId)) items.add(video);
        continue;
      }
      final continuation = _map(
        _map(
          _map(node['continuationItemRenderer'])?['continuationEndpoint'],
        )?['continuationCommand'],
      )?['token'];
      if (token == null && continuation is String && continuation.isNotEmpty) {
        token = continuation;
      }
      final values = node.values.toList();
      for (var i = values.length - 1; i >= 0; i--) {
        stack.add(values[i]);
      }
    }
    return (items: items, token: token);
  }

  /// Id da playlist num link (`list=`) ou o próprio id colado.
  static String? playlistIdFromText(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    if (RegExp(r'^(PL|UU|LL|FL|OL|RD)[\w-]{10,}$').hasMatch(value)) {
      return value;
    }
    return RegExp(r'[?&#]list=([\w-]{10,})').firstMatch(value)?.group(1);
  }

  static String playlistTitle(Map<String, dynamic> data) {
    final candidates = [
      _map(
            _map(data['metadata'])?['playlistMetadataRenderer'],
          )?['title']?.toString().trim() ??
          '',
      textOf(_map(_map(data['header'])?['playlistHeaderRenderer'])?['title']),
      _map(
            _map(data['microformat'])?['microformatDataRenderer'],
          )?['title']?.toString().trim() ??
          '',
    ];
    return candidates.firstWhere((t) => t.isNotEmpty, orElse: () => '');
  }
}
