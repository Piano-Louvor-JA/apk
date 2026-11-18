import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_media_muxer.dart';

/// Arquivos que o yt-dlp baixou (vídeo e áudio separados, ou um só).
typedef YtDlpFiles = ({String? video, String? audio});

/// Download de vídeos do YouTube pelo yt-dlp no Android (o mesmo motor do
/// desktop, com Python e QuickJS do youtubedl-android). O yt-dlp baixa o
/// vídeo H.264 e o áudio m4a; o mux nativo do app junta os dois.
class YtDlpDownloader {
  YtDlpDownloader({
    MethodChannel? channel,
    Future<void> Function({
      required String video,
      required String audio,
      required String output,
    })?
    mux,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _mux = mux ?? LiturgyMediaMuxer.combine {
    _channel.setMethodCallHandler(_onCall);
  }

  static const channelName = 'app.louvorja/ytdlp';

  /// Um por app (o canal tem um só ouvinte).
  static final instance = YtDlpDownloader();

  final MethodChannel _channel;
  final Future<void> Function({
    required String video,
    required String audio,
    required String output,
  })
  _mux;

  final _progress = <String, void Function(int, int)>{};
  int _seq = 0;
  String? _current;

  static bool get supported => Platform.isAndroid;

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'progress') return;
    final args = (call.arguments as Map).cast<String, Object?>();
    final listener = _progress[args['id']];
    if (listener == null) return;
    final percent = (args['percent'] as num?)?.toDouble() ?? 0;
    final stage = (args['stage'] as num?)?.toInt() ?? 1;
    // Vídeo é quase todo o tamanho: 0–90 % no vídeo, 90–100 % no áudio.
    final overall = stage <= 1 ? percent * .9 : 90 + percent * .1;
    try {
      listener((overall * 10).round(), 1000);
    } catch (_) {
      // Quem ouve pode desistir (cancelar) lançando; o processo é parado
      // por [cancel].
    }
  }

  /// Baixa [url] para [destination] (mp4 pronto para tocar).
  /// [onProgress] recebe (feito, total) em milésimos; (0, 0) = trabalhando.
  Future<void> download(
    String url,
    String destination, {
    void Function(int, int)? onProgress,
    int maxHeight = 720,
  }) async {
    final id = 'yt-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';
    final work = Directory('$destination.ytdlp');
    if (onProgress != null) _progress[id] = onProgress;
    _current = id;
    try {
      onProgress?.call(0, 0);
      final result = await _channel.invokeMapMethod<String, Object?>(
        'download',
        {'url': url, 'dir': work.path, 'id': id, 'maxHeight': maxHeight},
      );
      final files = (
        video: result?['video'] as String?,
        audio: result?['audio'] as String?,
      );
      await _finish(files, destination);
    } finally {
      _progress.remove(id);
      if (_current == id) _current = null;
      if (await work.exists()) await work.delete(recursive: true);
    }
  }

  Future<void> _finish(YtDlpFiles files, String destination) async {
    final video = files.video, audio = files.audio;
    if (video != null && audio != null) {
      await _mux(video: video, audio: audio, output: destination);
    } else if (video != null) {
      // Arquivo único (vídeo com áudio) quando não há trilhas separadas.
      await File(video).copy(destination);
    } else {
      throw StateError('ytdlp-sem-video');
    }
  }

  /// Para o download em andamento (mata o processo do yt-dlp).
  Future<void> cancel() async {
    final id = _current;
    if (id == null) return;
    try {
      await _channel.invokeMethod<bool>('cancel', {'id': id});
    } catch (_) {
      /* já terminou */
    }
  }
}
