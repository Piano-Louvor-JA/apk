library;

import 'package:flutter/foundation.dart';

import '../../domain/entities/hymn.dart';

/// Interface minima do player para o miniplayer (facilita testes).
///
/// Timeline (paridade Player.vue): posição, duração e seek têm default
/// inofensivo — implementações que suportam sobrescrevem.
abstract class HymnPlayerLike {
  bool get isPlaying;
  ValueListenable<bool> get playingListenable;

  Stream<Duration> get positionStream => const Stream.empty();
  Stream<Duration> get durationStream => const Stream.empty();
  Future<void> seek(Duration position) async {}

  /// F3.3e: modo tv do Palco silencia o player local (0) sem pausar —
  /// ele continua sendo o relógio dos slides projetados.
  Future<void> setVolume(double v) async {}

  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
}

/// Faixa em execucao exibida pelo miniplayer.
@immutable
class NowPlayingTrack {
  final int hymnId;
  final String title;
  final String album;
  final int? albumId;
  final int? durationMs;

  /// Detail completo (lyric/urls) — permite REABRIR o NowPlayingPage
  /// pelo mini player sem buscar na API de novo (multi-palco 2026-08-21).
  final Hymn? detail;

  /// Contexto da reprodução original (mesma visão do play na lista).
  final bool instrumental;
  final String? albumCoverUrl;
  final String? audioSource;
  final bool audioIsLocal;

  const NowPlayingTrack({
    required this.hymnId,
    required this.title,
    required this.album,
    this.albumId,
    this.durationMs,
    this.detail,
    this.instrumental = false,
    this.albumCoverUrl,
    this.audioSource,
    this.audioIsLocal = false,
  });
}

/// Estado global do que esta tocando agora.
///
/// AlbumDetailPage chama [start] ao dar play; MiniPlayerBar escuta.
/// [stop] limpa (barra some). [setPlaying] espelha o estado do player.
class NowPlayingNotifier extends ChangeNotifier {
  NowPlayingTrack? _track;
  bool _playing = false;

  NowPlayingTrack? get track => _track;
  bool get hasTrack => _track != null;
  bool get isPlaying => _playing;

  void start({
    required int hymnId,
    required String title,
    required String album,
    int? albumId,
    int? durationMs,
    Hymn? detail,
    bool instrumental = false,
    String? albumCoverUrl,
    String? audioSource,
    bool audioIsLocal = false,
  }) {
    _track = NowPlayingTrack(
      hymnId: hymnId,
      title: title,
      album: album,
      albumId: albumId,
      durationMs: durationMs,
      detail: detail,
      instrumental: instrumental,
      albumCoverUrl: albumCoverUrl,
      audioSource: audioSource,
      audioIsLocal: audioIsLocal,
    );
    _playing = true;
    notifyListeners();
  }

  void setPlaying(bool playing) {
    if (_playing == playing) return;
    _playing = playing;
    notifyListeners();
  }

  void pause() => setPlaying(false);

  void stop() {
    _track = null;
    _playing = false;
    notifyListeners();
  }
}

/// Singleton global — o miniplayer na shell consome.
final nowPlaying = NowPlayingNotifier();
