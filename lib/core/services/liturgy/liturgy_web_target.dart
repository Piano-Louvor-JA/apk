import 'dart:convert';

class LiturgyWebTarget {
  const LiturgyWebTarget({
    required this.kind,
    required this.url,
    required this.embedUrl,
    this.videoId = '',
  });
  final String kind;
  final String url;
  final String embedUrl;
  final String videoId;
  static LiturgyWebTarget? parse(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(value) &&
        !RegExp(r'^https?://', caseSensitive: false).hasMatch(value))
      return null;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(value))
      value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty)
      return null;
    final host = uri.host
        .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '')
        .toLowerCase();
    String? youtube;
    if (host == 'youtu.be') {
      youtube = uri.pathSegments.firstOrNull;
    } else if ({
      'youtube.com',
      'm.youtube.com',
      'music.youtube.com',
      'youtube-nocookie.com',
    }.contains(host)) {
      youtube = uri.queryParameters['v'];
      if (youtube == null) {
        final parts = uri.pathSegments;
        if (parts.length >= 2 &&
            {'embed', 'shorts', 'live', 'v'}.contains(parts.first))
          youtube = parts[1];
      }
    }
    if (youtube != null && youtube.isNotEmpty)
      return LiturgyWebTarget(
        kind: 'youtube',
        videoId: youtube,
        url: 'https://www.youtube.com/watch?v=${Uri.encodeComponent(youtube)}',
        embedUrl:
            'https://www.youtube-nocookie.com/embed/${Uri.encodeComponent(youtube)}?autoplay=1&enablejsapi=1',
      );
    if ({'vimeo.com', 'player.vimeo.com'}.contains(host)) {
      final id = uri.pathSegments.lastOrNull;
      if (id != null && RegExp(r'^\d+$').hasMatch(id))
        return LiturgyWebTarget(
          kind: 'vimeo',
          videoId: id,
          url: value,
          embedUrl: 'https://player.vimeo.com/video/$id',
        );
    }
    final video = RegExp(
      r'\.(mp4|m4v|webm|mov)$',
      caseSensitive: false,
    ).hasMatch(uri.path);
    return LiturgyWebTarget(
      kind: video ? 'direct-video' : 'site',
      url: value,
      embedUrl: value,
    );
  }

  String get projectionHtml {
    final src = const HtmlEscape(HtmlEscapeMode.attribute).convert(embedUrl);
    return '<iframe src="$src" sandbox="allow-scripts allow-same-origin allow-forms allow-presentation" allow="autoplay; fullscreen" allowfullscreen style="position:fixed;inset:0;width:100vw;height:100vh;border:0;background:#000"></iframe>';
  }
}
