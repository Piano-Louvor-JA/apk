/// Vídeo do YouTube no módulo YouTube (busca, histórico, favoritos e
/// coletâneas). Mesmo formato do desktop (`YoutubeSearchItem`).
class YoutubeVideo {
  const YoutubeVideo({
    required this.videoId,
    required this.title,
    this.channel = '',
    this.durationText = '',
    this.viewsText = '',
    this.publishedText = '',
    this.thumbnail = '',
    this.live = false,
  });

  final String videoId;
  final String title;
  final String channel;
  final String durationText;
  final String viewsText;
  final String publishedText;
  final String thumbnail;
  final bool live;

  static final idPattern = RegExp(r'^[\w-]{11}$');

  static bool isValidId(String id) => idPattern.hasMatch(id);

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';

  /// Capa: a salva ou a padrão do YouTube.
  String get thumbnailOrDefault => thumbnail.isNotEmpty
      ? thumbnail
      : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'title': title,
    'channel': channel,
    'durationText': durationText,
    'viewsText': viewsText,
    'publishedText': publishedText,
    'thumbnail': thumbnail,
    'live': live,
  };

  @override
  bool operator ==(Object other) =>
      other is YoutubeVideo &&
      other.videoId == videoId &&
      other.title == title &&
      other.channel == channel &&
      other.durationText == durationText &&
      other.viewsText == viewsText &&
      other.publishedText == publishedText &&
      other.thumbnail == thumbnail &&
      other.live == live;

  @override
  int get hashCode => Object.hash(
    videoId,
    title,
    channel,
    durationText,
    viewsText,
    publishedText,
    thumbnail,
    live,
  );

  @override
  String toString() => 'YoutubeVideo($videoId, $title)';
}

/// Token para "carregar mais" da busca.
class YoutubeContinuation {
  const YoutubeContinuation({
    required this.token,
    this.apiKey,
    required this.clientVersion,
  });
  final String token;
  final String? apiKey;
  final String clientVersion;

  @override
  bool operator ==(Object other) =>
      other is YoutubeContinuation &&
      other.token == token &&
      other.apiKey == apiKey &&
      other.clientVersion == clientVersion;

  @override
  int get hashCode => Object.hash(token, apiKey, clientVersion);
}

/// Resultado de uma página da busca. `error` nunca vira exceção:
/// `network`, `parse` ou `http-<status>`.
class YoutubeSearchResult {
  const YoutubeSearchResult({
    this.items = const [],
    this.continuation,
    this.error,
  });
  final List<YoutubeVideo> items;
  final YoutubeContinuation? continuation;
  final String? error;
}

/// Vídeos de uma playlist colada. `error`: `invalid`, `empty`, `network`,
/// `parse` ou `http-<status>`.
class YoutubePlaylistResult {
  const YoutubePlaylistResult({
    this.title = '',
    this.items = const [],
    this.error,
  });
  final String title;
  final List<YoutubeVideo> items;
  final String? error;
}
