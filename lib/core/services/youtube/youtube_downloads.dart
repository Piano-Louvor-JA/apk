import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_video_cache.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/yt_dlp_downloader.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_link_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

enum YoutubeDownloadPhase { none, queued, downloading, done, failed }

class YoutubeDownloadStatus {
  const YoutubeDownloadStatus(this.phase, {this.progress, this.bytes = 0});
  final YoutubeDownloadPhase phase;

  /// 0..1 enquanto baixa (nulo se o tamanho não é conhecido).
  final double? progress;

  /// Tamanho do arquivo baixado.
  final int bytes;

  static const none = YoutubeDownloadStatus(YoutubeDownloadPhase.none);
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Downloads do módulo YouTube: um vídeo por vez, em fila, para a mesma
/// pasta dos vídeos online da Liturgia (o player usa a cópia offline).
/// No celular não há escolha de pasta (fica no armazenamento do app);
/// quem libera espaço é o operador, apagando os vídeos.
class YoutubeDownloads extends ChangeNotifier {
  YoutubeDownloads({Future<LiturgyVideoCache> Function()? cache})
    : _cacheFactory =
          cache ??
          (() async => LiturgyVideoCache(
            await LiturgyVideoCache.defaultDirectory(),
            LiturgyLinkRepositoryImpl(),
          ));

  static final instance = YoutubeDownloads();

  /// Download só existe no Android (yt-dlp). No iOS não há como rodar o
  /// yt-dlp e a App Store (5.2.3) barra baixar do YouTube: lá o módulo
  /// só toca online, e os botões de download ficam ocultos.
  static bool get supported =>
      supportedOverride ?? defaultTargetPlatform == TargetPlatform.android;

  @visibleForTesting
  static bool? supportedOverride;

  final Future<LiturgyVideoCache> Function() _cacheFactory;
  LiturgyVideoCache? _cache;
  Future<LiturgyVideoCache> _getCache() async =>
      _cache ??= await _cacheFactory();

  final _status = <String, YoutubeDownloadStatus>{};
  final _queue = <YoutubeVideo>[];
  String? _current;
  bool _cancelCurrent = false;

  /// Encerra a espera do download atual (parado sem dados ou cancelado).
  Completer<String>? _abort;

  /// Sem nenhum dado nesse tempo, o download é dado como travado.
  @visibleForTesting
  /// (O 1º download no Android prepara o Python do yt-dlp: leva um tempo.)
  static Duration stallTimeout = const Duration(minutes: 3);
  bool _working = false;

  int totalBytes = 0;
  int totalVideos = 0;

  static String _url(String videoId) =>
      'https://www.youtube.com/watch?v=$videoId';

  YoutubeDownloadStatus statusOf(String videoId) =>
      _status[videoId] ?? YoutubeDownloadStatus.none;

  bool isBusy(String videoId) {
    final phase = statusOf(videoId).phase;
    return phase == YoutubeDownloadPhase.queued ||
        phase == YoutubeDownloadPhase.downloading;
  }

  bool get hasPending => _working || _queue.isNotEmpty;

  /// Confere no disco quais desses vídeos já estão baixados.
  Future<void> refresh(Iterable<String> videoIds) async {
    final LiturgyVideoCache cache;
    try {
      cache = await _getCache();
    } catch (_) {
      return; // sem pasta do app (ex.: testes): nada baixado
    }
    var changed = false;
    for (final id in videoIds.toSet()) {
      if (isBusy(id)) continue;
      final path = await cache.find(_url(id));
      final next = path == null
          ? YoutubeDownloadStatus.none
          : YoutubeDownloadStatus(
              YoutubeDownloadPhase.done,
              bytes: await File(path).length(),
            );
      final previous = _status[id];
      if (previous?.phase == YoutubeDownloadPhase.failed && path == null) {
        continue;
      }
      if (previous?.phase != next.phase || previous?.bytes != next.bytes) {
        _status[id] = next;
        changed = true;
      }
    }
    await _measure(cache, notify: false);
    if (changed) notifyListeners();
  }

  /// Espaço usado pela pasta inteira (vídeos da Liturgia também).
  Future<void> measure() async {
    try {
      await _measure(await _getCache());
    } catch (_) {
      /* sem pasta do app: mantém 0 */
    }
  }

  Future<void> _measure(LiturgyVideoCache cache, {bool notify = true}) async {
    var bytes = 0;
    var count = 0;
    final dir = cache.directory;
    if (await dir.exists()) {
      await for (final entry in dir.list()) {
        if (entry is File && entry.path.endsWith('.mp4')) {
          bytes += await entry.length();
          count++;
        }
      }
    }
    final changed = bytes != totalBytes || count != totalVideos;
    totalBytes = bytes;
    totalVideos = count;
    if (changed && notify) notifyListeners();
  }

  /// Coloca na fila os que ainda não estão baixados nem na fila.
  void download(Iterable<YoutubeVideo> videos) {
    var added = false;
    for (final video in videos) {
      if (!YoutubeVideo.isValidId(video.videoId)) continue;
      final phase = statusOf(video.videoId).phase;
      if (phase == YoutubeDownloadPhase.done || isBusy(video.videoId)) continue;
      _status[video.videoId] = const YoutubeDownloadStatus(
        YoutubeDownloadPhase.queued,
      );
      _queue.add(video);
      added = true;
    }
    if (!added) return;
    notifyListeners();
    unawaited(_work());
  }

  /// Para um vídeo (na fila ou baixando).
  void cancel(String videoId) {
    final before = _queue.length;
    _queue.removeWhere((v) => v.videoId == videoId);
    if (_queue.length != before) _status.remove(videoId);
    if (_current == videoId) _abortCurrent();
    notifyListeners();
  }

  void _abortCurrent() {
    _cancelCurrent = true;
    // yt-dlp roda num processo próprio: parar de esperar não basta.
    if (YtDlpDownloader.supported) unawaited(YtDlpDownloader.instance.cancel());
    final abort = _abort;
    if (abort != null && !abort.isCompleted) {
      abort.completeError(const _Cancelled());
    }
  }

  /// "Parar": esvazia a fila desses vídeos e interrompe o que está baixando.
  void cancelAll(Iterable<String> videoIds) {
    final ids = videoIds.toSet();
    _queue.removeWhere((v) {
      if (!ids.contains(v.videoId)) return false;
      _status.remove(v.videoId);
      return true;
    });
    if (_current != null && ids.contains(_current)) _abortCurrent();
    notifyListeners();
  }

  /// Apaga a cópia baixada.
  Future<bool> remove(String videoId) async {
    if (isBusy(videoId)) return false;
    final cache = await _getCache();
    final removed = await cache.remove(_url(videoId));
    _status.remove(videoId);
    await _measure(cache, notify: false);
    notifyListeners();
    return removed;
  }

  Future<void> _work() async {
    if (_working) return;
    _working = true;
    try {
      final cache = await _getCache();
      while (_queue.isNotEmpty) {
        final video = _queue.removeAt(0);
        _current = video.videoId;
        _cancelCurrent = false;
        _status[video.videoId] = const YoutubeDownloadStatus(
          YoutubeDownloadPhase.downloading,
        );
        notifyListeners();
        final abort = _abort = Completer<String>();
        Timer? watchdog;
        void arm() {
          watchdog?.cancel();
          watchdog = Timer(stallTimeout, () {
            if (!abort.isCompleted) {
              _cancelCurrent = true;
              if (YtDlpDownloader.supported) {
                unawaited(YtDlpDownloader.instance.cancel());
              }
              abort.completeError(TimeoutException('sem dados do YouTube'));
            }
          });
        }

        arm();
        try {
          final path = await Future.any([
            cache.download(
              _url(video.videoId),
              // Vídeo longo leva tempo; travado cai no vigia acima.
              timeout: const Duration(minutes: 40),
              onProgress: (received, total) {
                if (_cancelCurrent) throw const _Cancelled();
                arm();
                _status[video.videoId] = YoutubeDownloadStatus(
                  YoutubeDownloadPhase.downloading,
                  progress: total > 0 ? received / total : null,
                );
                notifyListeners();
              },
            ),
            abort.future,
          ]);
          _status[video.videoId] = YoutubeDownloadStatus(
            YoutubeDownloadPhase.done,
            bytes: await File(path).length(),
          );
        } on _Cancelled {
          _status.remove(video.videoId);
        } catch (e) {
          debugPrint('[youtube-download] falhou ${video.videoId}: $e');
          _status[video.videoId] = e is _Cancelled
              ? YoutubeDownloadStatus.none
              : const YoutubeDownloadStatus(YoutubeDownloadPhase.failed);
        }
        watchdog?.cancel();
        if (!abort.isCompleted) abort.complete('');
        _abort = null;
        _current = null;
        await _measure(cache, notify: false);
        notifyListeners();
      }
    } catch (_) {
      // Sem pasta do app: os itens da fila ficam como estavam.
    } finally {
      _working = false;
    }
  }
}

/// "1.6 GB", "350 MB"...
String formatYoutubeBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0 || value >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
