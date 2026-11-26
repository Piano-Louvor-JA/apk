/// Canais do YouTube no módulo YouTube (mesmo formato do desktop,
/// `src/modules/youtube/services/youtube-channels.ts` e
/// `electron/youtube-search.mjs`).
library;

/// Dados do canal lidos do YouTube. `url` é o link curto (@handle) quando existe.
class YoutubeChannelInfo {
  const YoutubeChannelInfo({
    required this.id,
    required this.name,
    required this.url,
    this.avatar = '',
  });
  final String id, name, url, avatar;
}

/// Playlist da aba "Playlists" de um canal.
class YoutubeChannelPlaylistInfo {
  const YoutubeChannelPlaylistInfo({
    required this.id,
    required this.title,
    this.thumbnail = '',
    this.videoCount = 0,
  });
  final String id, title, thumbnail;
  final int videoCount;
}

/// Canal e playlists. `error`: `invalid`, `empty`, `parse`, `network` ou `http-<status>`.
class YoutubeChannelResult {
  const YoutubeChannelResult({
    this.channel,
    this.playlists = const [],
    this.error,
  });
  final YoutubeChannelInfo? channel;
  final List<YoutubeChannelPlaylistInfo> playlists;
  final String? error;
}

/// Canal achado na pesquisa. `handle`: "@nome" (pode vir vazio);
/// `subscribers`: texto do YouTube ("12 mil inscritos").
class YoutubeChannelSearchItem {
  const YoutubeChannelSearchItem({
    required this.id,
    required this.name,
    required this.url,
    this.handle = '',
    this.subscribers = '',
    this.avatar = '',
    this.description = '',
  });
  final String id, name, url, handle, subscribers, avatar, description;
}

/// `error`: `empty`, `parse`, `network` ou `http-<status>`.
class YoutubeChannelSearchResult {
  const YoutubeChannelSearchResult({this.items = const [], this.error});
  final List<YoutubeChannelSearchItem> items;
  final String? error;
}

/// Playlist de um canal do módulo. Capa: [thumbnail] (canais cadastrados) ou a
/// miniatura de [coverVideoId] (canais padrão, o primeiro vídeo da playlist).
class YoutubeChannelPlaylist {
  const YoutubeChannelPlaylist({
    required this.id,
    required this.name,
    this.coverVideoId = '',
    this.thumbnail = '',
    this.videoCount = 0,
  });
  final String id, name, coverVideoId, thumbnail;
  final int videoCount;

  String get cover => thumbnail.isNotEmpty
      ? thumbnail
      : coverVideoId.isNotEmpty
      ? 'https://i.ytimg.com/vi/$coverVideoId/hqdefault.jpg'
      : '';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'thumbnail': thumbnail,
    'videoCount': videoCount,
  };
}

/// Canal do módulo: os padrão vêm no código (somente leitura) e os
/// cadastrados pelo operador ficam salvos no aparelho. `merged`: abrir o
/// canal lista os vídeos de todas as playlists numa lista só.
class YoutubeChannel {
  const YoutubeChannel({
    required this.id,
    required this.name,
    required this.url,
    required this.playlists,
    this.subtitle = '',
    this.merged = false,
    this.youtubeId = '',
    this.avatar = '',
    this.userAdded = false,
    this.addedAt = 0,
  });
  final String id, name, url, subtitle, youtubeId, avatar;
  final bool merged, userAdded;
  final int addedAt;
  final List<YoutubeChannelPlaylist> playlists;

  YoutubeChannelPlaylist? playlist(String? id) =>
      playlists.where((p) => p.id == id).firstOrNull;

  /// Capas do card: as das 4 primeiras playlists; sem capas, o avatar.
  List<String> get covers {
    final list = playlists
        .map((p) => p.cover)
        .where((c) => c.isNotEmpty)
        .take(4)
        .toList();
    if (list.isNotEmpty) return list;
    return avatar.isNotEmpty ? [avatar] : const [];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'avatar': avatar,
    'addedAt': addedAt,
    'playlists': [for (final p in playlists) p.toJson()],
  };
}
