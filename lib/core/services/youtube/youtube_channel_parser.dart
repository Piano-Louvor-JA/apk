import 'package:louvorja_piano_mobile/core/services/youtube/youtube_search_parser.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_channel.dart';

/// Leitura de canais do YouTube (mesma regra do desktop,
/// `electron/youtube-search.mjs`): o link do canal, as playlists da aba
/// "Playlists" e os canais da pesquisa.
class YoutubeChannelParser {
  const YoutubeChannelParser._();

  static final channelId = RegExp(r'^UC[\w-]{22}$');

  /// Handles aceitam letras com acento (ex.: @HinárioAntigoAdventista).
  static final handle = RegExp(r'^@[\p{L}\p{N}_.\-·]{2,}$', unicode: true);
  static final _name = RegExp(r'^[\w.-]+$');
  static const maxQuery = 200;

  static Map? _map(Object? value) => value is Map ? value : null;
  static List _list(Object? value) => value is List ? value : const [];
  static String _str(Object? value) => value is String ? value : '';

  /// Caminho do canal: `@handle`, link do canal (qualquer aba),
  /// `/channel/UC…`, o id `UC…` sozinho, `/c/nome` ou `/user/nome`.
  static String? channelPath(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    if (channelId.hasMatch(value)) return 'channel/$value';
    if (handle.hasMatch(value)) return value;
    final uri = Uri.tryParse(
      RegExp(r'^https?://', caseSensitive: false).hasMatch(value)
          ? value
          : 'https://$value',
    );
    if (uri == null ||
        !RegExp(
          r'(^|\.)youtube\.com$',
          caseSensitive: false,
        ).hasMatch(uri.host)) {
      return null;
    }
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final first = parts.isNotEmpty ? parts[0] : '';
    final second = parts.length > 1 ? parts[1] : '';
    if (handle.hasMatch(first)) return first;
    if (first == 'channel' && channelId.hasMatch(second)) {
      return 'channel/$second';
    }
    if ((first == 'c' || first == 'user') && _name.hasMatch(second)) {
      return '$first/$second';
    }
    return null;
  }

  /// Colou um link de canal (ou @handle completo, ou id `UC…`).
  static bool isChannelLink(String text) => channelPath(text) != null;

  /// Colou um link com `list=` ou o id da playlist.
  static bool isPlaylistLink(String text) =>
      YoutubeSearchParser.playlistIdFromText(text) != null;

  /// "1.234 vídeos" → 1234; sem número → 0.
  static int _count(String text) {
    final match = RegExp(r'\d[\d.,]*').firstMatch(text);
    return match == null
        ? 0
        : int.tryParse(match.group(0)!.replaceAll(RegExp('[.,]'), '')) ?? 0;
  }

  static bool _isPlaylistId(String id) =>
      YoutubeSearchParser.playlistIdFromText(id) == id;

  /// Playlist no formato novo (`lockupViewModel`); `null` se não for playlist.
  static YoutubeChannelPlaylistInfo? playlistFromLockup(Object? raw) {
    final lockup = _map(raw);
    if (lockup == null ||
        lockup['contentType'] != 'LOCKUP_CONTENT_TYPE_PLAYLIST') {
      return null;
    }
    final id = _str(lockup['contentId']);
    final title = _str(
      _map(
        _map(_map(lockup['metadata'])?['lockupMetadataViewModel'])?['title'],
      )?['content'],
    ).trim();
    if (!_isPlaylistId(id) || title.isEmpty) return null;
    final thumb = _map(
      _map(
        _map(
          _map(lockup['contentImage'])?['collectionThumbnailViewModel'],
        )?['primaryThumbnail'],
      )?['thumbnailViewModel'],
    );
    final sources = _list(_map(thumb?['image'])?['sources']);
    var count = 0;
    for (final overlay in _list(thumb?['overlays'])) {
      final badges = _list(
        _map(
          _map(overlay)?['thumbnailOverlayBadgeViewModel'],
        )?['thumbnailBadges'],
      );
      for (final badge in badges) {
        final n = _count(
          _str(_map(_map(badge)?['thumbnailBadgeViewModel'])?['text']),
        );
        if (n > 0) count = n;
      }
    }
    final last = sources.isNotEmpty ? _str(_map(sources.last)?['url']) : '';
    return YoutubeChannelPlaylistInfo(
      id: id,
      title: title,
      thumbnail: last.split('?').first,
      videoCount: count,
    );
  }

  /// Formato antigo (`gridPlaylistRenderer`).
  static YoutubeChannelPlaylistInfo? _playlistFromGrid(Object? raw) {
    final renderer = _map(raw);
    final id = _str(renderer?['playlistId']);
    final title = YoutubeSearchParser.textOf(renderer?['title']);
    if (!_isPlaylistId(id) || title.isEmpty) return null;
    final thumbs = _list(_map(renderer?['thumbnail'])?['thumbnails']);
    final thumb = thumbs.isNotEmpty ? _str(_map(thumbs.last)?['url']) : '';
    return YoutubeChannelPlaylistInfo(
      id: id,
      title: title,
      thumbnail: thumb.split('?').first,
      videoCount: _count(YoutubeSearchParser.textOf(renderer?['videoCountText'])),
    );
  }

  /// Playlists em ordem (sem repetir) e o primeiro token de continuação.
  static ({List<YoutubeChannelPlaylistInfo> items, String? token})
  collectPlaylists(Object? root) {
    final items = <YoutubeChannelPlaylistInfo>[];
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
      if (node['lockupViewModel'] != null ||
          node['gridPlaylistRenderer'] != null) {
        final playlist = node['lockupViewModel'] != null
            ? playlistFromLockup(node['lockupViewModel'])
            : _playlistFromGrid(node['gridPlaylistRenderer']);
        if (playlist != null && seen.add(playlist.id)) items.add(playlist);
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

  /// Nome, id, link e avatar do canal (`channelMetadataRenderer`).
  static YoutubeChannelInfo? channelInfo(Map<String, dynamic> data) {
    final meta = _map(_map(data['metadata'])?['channelMetadataRenderer']);
    final id = _str(meta?['externalId']);
    final name = _str(meta?['title']).trim();
    if (!channelId.hasMatch(id) || name.isEmpty) return null;
    final vanity = _str(
      meta?['vanityChannelUrl'],
    ).replaceFirst(RegExp('^http:', caseSensitive: false), 'https:');
    final avatars = _list(_map(meta?['avatar'])?['thumbnails']);
    return YoutubeChannelInfo(
      id: id,
      name: name,
      url: vanity.isNotEmpty ? vanity : 'https://www.youtube.com/channel/$id',
      avatar: avatars.isNotEmpty ? _str(_map(avatars.last)?['url']) : '',
    );
  }

  /* ---------- Pesquisa de canais ---------- */

  static String _fold(String text) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    final out = StringBuffer();
    for (final ch in text.split('')) {
      final i = from.indexOf(ch);
      out.write(i < 0 ? ch : to[i]);
    }
    return out.toString();
  }

  /// O tema digitado + "adventista" (se a pessoa já não escreveu).
  static String adventistQuery(String text) {
    var q = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.length > maxQuery) q = q.substring(0, maxQuery);
    if (q.isEmpty) return '';
    if (RegExp('adventist', caseSensitive: false).hasMatch(_fold(q))) return q;
    final full = '$q adventista';
    return full.length > maxQuery ? full.substring(0, maxQuery) : full;
  }

  /// Canal do resultado da busca (`channelRenderer`). O YouTube costuma mandar
  /// o @handle em `subscriberCountText` e os inscritos em `videoCountText`:
  /// o que começa com "@" é o handle, o outro são os inscritos.
  static YoutubeChannelSearchItem? channelFromRenderer(Object? raw) {
    final renderer = _map(raw);
    final id = _str(renderer?['channelId']);
    final name = YoutubeSearchParser.textOf(renderer?['title']);
    if (!channelId.hasMatch(id) || name.isEmpty) return null;
    final texts = [
      YoutubeSearchParser.textOf(renderer?['subscriberCountText']),
      YoutubeSearchParser.textOf(renderer?['videoCountText']),
    ].where((t) => t.isNotEmpty).toList();
    final thumbs = _list(_map(renderer?['thumbnail'])?['thumbnails']);
    final avatar = thumbs.isNotEmpty ? _str(_map(thumbs.last)?['url']) : '';
    return YoutubeChannelSearchItem(
      id: id,
      name: name,
      url: 'https://www.youtube.com/channel/$id',
      handle: texts.firstWhere((t) => t.startsWith('@'), orElse: () => ''),
      subscribers: texts.firstWhere(
        (t) => !t.startsWith('@'),
        orElse: () => '',
      ),
      avatar: avatar.startsWith('//') ? 'https:$avatar' : avatar,
      description: YoutubeSearchParser.textOf(renderer?['descriptionSnippet']),
    );
  }

  /// Canais da página de resultados, em ordem e sem repetir.
  static List<YoutubeChannelSearchItem> collectChannels(Object? root) {
    final items = <YoutubeChannelSearchItem>[];
    final seen = <String>{};
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
      if (node['channelRenderer'] != null) {
        final channel = channelFromRenderer(node['channelRenderer']);
        if (channel != null && seen.add(channel.id)) items.add(channel);
        continue;
      }
      final values = node.values.toList();
      for (var i = values.length - 1; i >= 0; i--) {
        stack.add(values[i]);
      }
    }
    return items;
  }
}
