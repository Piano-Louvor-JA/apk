import 'package:louvorja_piano_mobile/core/constants/app_version.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_media_muxer.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:louvorja_piano_mobile/core/platform_header.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_link_info.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_target.dart';
import 'package:louvorja_piano_mobile/domain/repositories/liturgy_link_repository.dart';

class LiturgyLinkRepositoryImpl implements LiturgyLinkRepository {
  LiturgyLinkRepositoryImpl({Dio? dio})
    : _http =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 10),
              headers: clientPlatformHeaders(),
            ),
          ) {
    _http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers.addAll(
            clientPlatformHeaders(version: await AppVersion.version),
          );
          handler.next(options);
        },
      ),
    );
  }
  final Dio _http;
  @override
  Future<LiturgyLinkInfo> info(String raw) async {
    final target = LiturgyWebTarget.parse(raw);
    if (target == null) throw const FormatException('url');
    final prefs = await SharedPreferences.getInstance();
    final key = 'liturgy.links.${target.url}';
    final cached = prefs.getString(key);
    if (cached != null)
      return LiturgyLinkInfo.fromJson(
        (jsonDecode(cached) as Map).cast<String, dynamic>(),
      );
    LiturgyLinkInfo result;
    if (target.kind == 'youtube') {
      final yt = YoutubeExplode(
        httpClient: _IdentifiedYoutubeHttpClient(await AppVersion.version),
      );
      try {
        final video = await yt.videos
            .get(target.videoId)
            .timeout(const Duration(seconds: 20));
        result = LiturgyLinkInfo(
          title: video.title,
          source: video.author,
          description: video.description,
          durationMs: video.duration?.inMilliseconds ?? 0,
        );
      } catch (_) {
        final response = await _http.get(
          'https://www.youtube.com/oembed',
          queryParameters: {'url': target.url, 'format': 'json'},
        );
        final data = response.data as Map;
        result = LiturgyLinkInfo(
          title: data['title'] as String? ?? '',
          source: data['author_name'] as String? ?? '',
        );
      } finally {
        yt.close();
      }
    } else if (target.kind == 'vimeo') {
      final response = await _http.get(
        'https://vimeo.com/api/oembed.json',
        queryParameters: {'url': target.url},
      );
      final data = response.data as Map;
      result = LiturgyLinkInfo(
        title: data['title'] as String? ?? '',
        source: data['author_name'] as String? ?? '',
        description: data['description'] as String? ?? '',
        durationMs: ((data['duration'] as num?)?.toDouble() ?? 0) * 1000 ~/ 1,
      );
    } else {
      final response = await _http.get<String>(
        target.url,
        options: Options(responseType: ResponseType.plain),
      );
      result = LiturgyLinkInfo.fromHtml(response.data ?? '');
    }
    if (result.title.isNotEmpty)
      await prefs.setString(key, jsonEncode(result.toJson()));
    return result;
  }

  @override
  Future<void> download(
    String raw,
    String destination, {
    void Function(int, int)? onProgress,
  }) async {
    final target = LiturgyWebTarget.parse(raw);
    if (target == null) throw const FormatException('url');
    if (target.kind == 'youtube') {
      final yt = YoutubeExplode(
        httpClient: _IdentifiedYoutubeHttpClient(await AppVersion.version),
      );
      try {
        final manifest = await yt.videos.streams
            .getManifest(target.videoId)
            .timeout(const Duration(seconds: 45));
        Future<void> write(StreamInfo stream, String path) async {
          final sink = File(path).openWrite();
          var received = 0;
          try {
            await for (final bytes
                in yt.videos.streams
                    .get(stream)
                    .timeout(const Duration(seconds: 45))) {
              sink.add(bytes);
              received += bytes.length;
              onProgress?.call(received, stream.size.totalBytes);
            }
            await sink.flush();
          } finally {
            await sink.close();
          }
        }

        final videos =
            manifest.videoOnly
                .where(
                  (stream) =>
                      stream.container.name == 'mp4' &&
                      stream.videoCodec.startsWith('avc1'),
                )
                .toList()
              ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
        final audios =
            manifest.audioOnly
                .where((stream) => stream.container.name == 'mp4')
                .toList()
              ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
        if (Platform.isAndroid && videos.isNotEmpty && audios.isNotEmpty) {
          final video = File('$destination.video');
          final audio = File('$destination.audio');
          try {
            await write(videos.first, video.path);
            await write(audios.first, audio.path);
            await LiturgyMediaMuxer.combine(
              video: video.path,
              audio: audio.path,
              output: destination,
            );
          } finally {
            if (await video.exists()) await video.delete();
            if (await audio.exists()) await audio.delete();
          }
        } else {
          final streams = manifest.muxed.toList()
            ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
          if (streams.isEmpty) throw StateError('no-muxed-stream');
          await write(streams.first, destination);
        }
      } finally {
        yt.close();
      }
    } else if (target.kind == 'vimeo') {
      final response = await _http.get(
        'https://player.vimeo.com/video/${target.videoId}/config',
        options: Options(headers: {'Referer': target.url}),
      );
      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      final config = decoded is Map ? decoded : const {};
      final files =
          (config['video'] is Map ? (config['video'] as Map)['files'] : null) ??
          (config['request'] is Map
              ? (config['request'] as Map)['files']
              : null);
      final progressive = files is Map ? files['progressive'] : null;
      final sources = progressive is List
          ? progressive.whereType<Map>().where((source) {
              final uri = Uri.tryParse(source['url']?.toString() ?? '');
              return uri != null &&
                  {'http', 'https'}.contains(uri.scheme) &&
                  uri.host.isNotEmpty;
            }).toList()
          : <Map>[];
      sources.sort(
        (a, b) =>
            ((b['height'] as num?) ?? 0).compareTo((a['height'] as num?) ?? 0),
      );
      if (sources.isEmpty) throw UnsupportedError('video-download');
      await _http.download(
        sources.first['url'].toString(),
        destination,
        onReceiveProgress: onProgress,
        options: Options(headers: {'Referer': target.url}),
      );
    } else if (target.kind == 'direct-video') {
      await _http.download(
        target.url,
        destination,
        onReceiveProgress: onProgress,
      );
    } else {
      throw UnsupportedError('video-download');
    }
  }
}

class _IdentifiedYoutubeHttpClient extends YoutubeHttpClient {
  _IdentifiedYoutubeHttpClient(this.version);
  final String version;
  @override
  Map<String, String> get headers => {
    ...super.headers,
    ...clientPlatformHeaders(version: version),
  };
}
