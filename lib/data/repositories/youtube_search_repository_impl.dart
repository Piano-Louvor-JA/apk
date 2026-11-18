import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:louvorja_piano_mobile/core/services/youtube/youtube_search_parser.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/domain/repositories/youtube_search_repository.dart';

/// Resposta HTTP mínima usada pela busca (facilita os testes).
typedef YoutubeHttpResponse = ({int status, String body});

/// Transporte HTTP da busca. O padrão usa Dio.
abstract class YoutubeHttp {
  Future<YoutubeHttpResponse> get(String url, Map<String, String> headers);
  Future<YoutubeHttpResponse> post(
    String url,
    Map<String, String> headers,
    String body,
  );
}

class DioYoutubeHttp implements YoutubeHttp {
  DioYoutubeHttp([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              responseType: ResponseType.plain,
              validateStatus: (_) => true,
            ),
          );
  final Dio _dio;

  @override
  Future<YoutubeHttpResponse> get(
    String url,
    Map<String, String> headers,
  ) async {
    final res = await _dio.get<String>(url, options: Options(headers: headers));
    return (status: res.statusCode ?? 0, body: res.data ?? '');
  }

  @override
  Future<YoutubeHttpResponse> post(
    String url,
    Map<String, String> headers,
    String body,
  ) async {
    final res = await _dio.post<String>(
      url,
      data: body,
      options: Options(headers: headers),
    );
    return (status: res.statusCode ?? 0, body: res.data ?? '');
  }
}

/// Mesma regra do desktop (`electron/youtube-search.mjs`): página de
/// resultados só de vídeos + `youtubei/v1/search` para carregar mais;
/// playlist pela página `/playlist` + `youtubei/v1/browse`.
class YoutubeSearchRepositoryImpl implements YoutubeSearchRepository {
  YoutubeSearchRepositoryImpl({YoutubeHttp? http})
    : _http = http ?? DioYoutubeHttp();
  final YoutubeHttp _http;

  static const maxQuery = 200;
  static const playlistMaxVideos = 500;
  static const playlistMaxPages = 25;

  /// Filtro "Tipo: vídeo".
  static const onlyVideos = 'EgIQAQ%253D%253D';
  static const defaultClientVersion = '2.20251101.00.00';
  static const headers = {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36',
    'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
  };

  static String _body(String token, String clientVersion) => jsonEncode({
    'context': {
      'client': {
        'clientName': 'WEB',
        'clientVersion': clientVersion,
        'hl': 'pt',
        'gl': 'BR',
      },
    },
    'continuation': token,
  });

  static String _keyParam(String? apiKey) =>
      apiKey != null && apiKey.isNotEmpty
      ? '&key=${Uri.encodeQueryComponent(apiKey)}'
      : '';

  static Object? _json(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<YoutubeSearchResult> search(String query) async {
    var q = query.trim();
    if (q.length > maxQuery) q = q.substring(0, maxQuery);
    if (q.isEmpty) return const YoutubeSearchResult();
    try {
      final url =
          'https://www.youtube.com/results?search_query=${Uri.encodeComponent(q)}&sp=$onlyVideos&hl=pt-BR';
      final res = await _http.get(url, headers);
      if (res.status < 200 || res.status >= 300) {
        return YoutubeSearchResult(error: 'http-${res.status}');
      }
      final data = YoutubeSearchParser.initialData(res.body);
      if (data == null) return const YoutubeSearchResult(error: 'parse');
      final found = YoutubeSearchParser.collect(data);
      return YoutubeSearchResult(
        items: found.items,
        continuation: found.token == null
            ? null
            : YoutubeContinuation(
                token: found.token!,
                apiKey: YoutubeSearchParser.readConfig(
                  res.body,
                  'INNERTUBE_API_KEY',
                ),
                clientVersion:
                    YoutubeSearchParser.readConfig(
                      res.body,
                      'INNERTUBE_CLIENT_VERSION',
                    ) ??
                    defaultClientVersion,
              ),
      );
    } catch (_) {
      return const YoutubeSearchResult(error: 'network');
    }
  }

  @override
  Future<YoutubeSearchResult> more(YoutubeContinuation continuation) async {
    if (continuation.token.isEmpty) return const YoutubeSearchResult();
    final clientVersion = continuation.clientVersion.isNotEmpty
        ? continuation.clientVersion
        : defaultClientVersion;
    try {
      final res = await _http.post(
        'https://www.youtube.com/youtubei/v1/search?prettyPrint=false${_keyParam(continuation.apiKey)}',
        {...headers, 'Content-Type': 'application/json'},
        _body(continuation.token, clientVersion),
      );
      if (res.status < 200 || res.status >= 300) {
        return YoutubeSearchResult(error: 'http-${res.status}');
      }
      final found = YoutubeSearchParser.collect(_json(res.body));
      return YoutubeSearchResult(
        items: found.items,
        continuation: found.token == null
            ? null
            : YoutubeContinuation(
                token: found.token!,
                apiKey: continuation.apiKey,
                clientVersion: clientVersion,
              ),
      );
    } catch (_) {
      return const YoutubeSearchResult(error: 'network');
    }
  }

  @override
  Future<YoutubePlaylistResult> playlist(String text) async {
    final listId = YoutubeSearchParser.playlistIdFromText(text);
    if (listId == null) return const YoutubePlaylistResult(error: 'invalid');
    try {
      final res = await _http.get(
        'https://www.youtube.com/playlist?list=${Uri.encodeComponent(listId)}&hl=pt-BR',
        headers,
      );
      if (res.status < 200 || res.status >= 300) {
        return YoutubePlaylistResult(error: 'http-${res.status}');
      }
      final data = YoutubeSearchParser.initialData(res.body);
      if (data == null) return const YoutubePlaylistResult(error: 'parse');
      const keys = YoutubeSearchParser.playlistKeys;
      final first = YoutubeSearchParser.collect(data, keys);
      final items = [...first.items];
      final seen = items.map((item) => item.videoId).toSet();
      final apiKey = YoutubeSearchParser.readConfig(
        res.body,
        'INNERTUBE_API_KEY',
      );
      final clientVersion =
          YoutubeSearchParser.readConfig(res.body, 'INNERTUBE_CLIENT_VERSION') ??
          defaultClientVersion;
      var token = first.token;
      for (
        var page = 0;
        token != null &&
            page < playlistMaxPages &&
            items.length < playlistMaxVideos;
        page++
      ) {
        final more = await _http.post(
          'https://www.youtube.com/youtubei/v1/browse?prettyPrint=false${_keyParam(apiKey)}',
          {...headers, 'Content-Type': 'application/json'},
          _body(token, clientVersion),
        );
        if (more.status < 200 || more.status >= 300) break;
        final next = YoutubeSearchParser.collect(_json(more.body), keys);
        var added = 0;
        for (final item in next.items) {
          if (!seen.add(item.videoId)) continue;
          items.add(item);
          added++;
        }
        token = added > 0 ? next.token : null;
      }
      final title = YoutubeSearchParser.playlistTitle(data);
      if (items.isEmpty) {
        return YoutubePlaylistResult(title: title, error: 'empty');
      }
      return YoutubePlaylistResult(
        title: title,
        items: items.length > playlistMaxVideos
            ? items.sublist(0, playlistMaxVideos)
            : items,
      );
    } catch (_) {
      return const YoutubePlaylistResult(error: 'network');
    }
  }
}
