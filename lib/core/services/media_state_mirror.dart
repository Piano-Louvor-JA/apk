// SPEC media-service (apk#132 follow-up): espelho de estado player → sessão.
//
// O sistema (notificação MediaStyle, lock screen, barra PiP) alimenta-se
// da MediaSession. Antes deste espelho, a sessão só atualizava quando o
// botão DENTRO da NowPlayingPage era tocado — o player real nunca
// reportava estado, então a barra nativa mostrava PLAY com áudio tocando
// e nenhum controle nativo tinha efeito (evidência A15 15:57:
// dispatchAction hasPlayCb=true + dumpsys state=PAUSED com áudio audível).
//
// Padrão YouTube/Spotify: player → MediaSession → sistema alimenta
// notificação + lock screen + PiP do MESMO estado.
//
// Evento do player (fonte da verdade) → canal `app.louvorja/media`.
// Metadata vem do NowPlayingNotifier (já centraliza faixa atual).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hymn_audio_player.dart';
import 'dlna/stage_session.dart';
import 'media_session.dart';
import 'now_playing.dart';

abstract final class MediaStateMirror {
  static const _ch = MethodChannel('app.louvorja/media');
  static StreamSubscription<bool>? _playingSub;
  static StreamSubscription<Duration>? _posSub;
  static StreamSubscription<void>? _completeSub;
  static bool _started = false;
  static bool _lastPlaying = false;
  static DateTime? _lastPosSent;
  static Duration? _lastSeenPosition;

  static bool get isRunning => _started;

  /// Idempotente — chamar uma vez no bootstrap do app.
  static void start({HymnAudioPlayer? player}) {
    if (_started) return;
    _started = true;
    final p = player ?? HymnAudioPlayer.instance;
    _lastPlaying = p.isPlaying;

    // Autossuficiente: garante o canal nativo vivo (a página também chama,
    // mas o init é idempotente — receiver/sessão nasce uma única vez).
    MediaSession.init();

    // CONTROLES GLOBAIS (23:22 — pipeline provado até o Dart, mas o
    // onPlayPause da página era null após dispose dela em PiP: o toque
    // chegava e NINGUÉM pausava). O espelho responde direto no singleton
    // — independe de página viva. A página pode sobrepor os callbacks pra
    // efeitos de UI (setState), mas o pause/resume do singleton é daqui.
    MediaSession.onPlayPause = (play) {
      debugPrint('LouvorPip(mirror): onPlayPause play=$play');
      if (play) {
        // HymnAudioPlayer não tem resume: toggleUrl na URL atual retoma.
        final url = p.currentUrl;
        if (url != null) p.playUrl(url);
      } else {
        p.pause();
        StageSession.instance.pauseHymnAudio();
      }
    };
    MediaSession.onPrev = () async {
      debugPrint('LouvorPip(mirror): onPrev');
      await _seekBy(p, -15);
    };
    MediaSession.onNext = () async {
      debugPrint('LouvorPip(mirror): onNext');
      await _seekBy(p, 15);
    };

    // Estado PLAY/PAUSE: fonte da verdade é o evento do player.
    _playingSub = p.playingStream.listen((playing) {
      _lastPlaying = playing;
      // setPlaybackState já publica a notificação (postNotification no
      // nativo): tocando → notificação aparece; pausado → atualiza ícone.
      MediaSession.setPlaybackState(isPlaying: playing, positionMs: 0);
      // FGS de mídia (solução definitiva): One UI congela o processo em
      // background sem serviço foreground — Dart para e nenhum controle
      // executa (FreecessController "BG freezed", A15 22:26).
      if (playing) {
        _ch.invokeMethod<void>('startMediaService').catchError((_) {});
      } else {
        _ch.invokeMethod<void>('stopMediaService').catchError((_) {});
      }
    });

    // Posição: progresso da notificação/lock screen. THROTTLE 1s (23:22:
    // sem throttle eram ~9 notify/s — o sistema derrubava com "rate limit
    // exceeded" e a notificação ficava dessincronizada). O CACHE da última
    // posição atualiza a TODO tick (±15s usa; não pode ser engolido pelo
    // throttle — bug prev/next 07:25).
    _posSub = p.positionStream.listen((pos) {
      _lastSeenPosition = pos;
      final now = DateTime.now();
      if (_lastPosSent != null &&
          now.difference(_lastPosSent!) < const Duration(seconds: 1)) {
        return;
      }
      _lastPosSent = now;
      MediaSession.setPlaybackState(
        isPlaying: _lastPlaying,
        positionMs: pos.inMilliseconds,
      );
    });

    // Faixa terminou → sessão pausada (senão notificação fica "tocando").
    _completeSub = p.completionStream.listen((_) {
      _lastPlaying = false;
      MediaSession.setPlaybackState(isPlaying: false, positionMs: 0);
    });

    // Metadados: faixa atual (título/álbum/capa/duração) → notificação.
    nowPlaying.addListener(_onNowPlayingChanged);
    _onNowPlayingChanged();
  }

  static void _onNowPlayingChanged() {
    final t = nowPlaying.track;
    if (t == null) return;
    MediaSession.setMetadata(
      title: t.title,
      album: t.album,
      artUrl: t.albumCoverUrl,
      durationMs: t.durationMs ?? 0,
    );
  }

  /// ±[seconds] no player global (±15s da notificação/lock/PiP).
  ///
  /// 07:25: `await for (positionStream.take(1))` PENDENVA eternamente quando
  /// pausado/buffering (o stream só emite tocando) — prev/next chegavam ao
  /// Dart e o seek nunca rodava. Usa a ÚLTIMA posição já vista pelo
  /// espelho (o listener de posição roda o tempo todo) — sem esperar stream.
  static Future<void> _seekBy(HymnAudioPlayer p, int seconds) async {
    try {
      final pos = _lastSeenPosition ?? Duration.zero;
      var target = pos + Duration(seconds: seconds);
      if (target < Duration.zero) target = Duration.zero;
      await p.seek(target);
      _lastSeenPosition = target;
    } catch (e) {
      debugPrint('LouvorPip(mirror): seek falhou: $e');
    }
  }

  static void stop() {
    _playingSub?.cancel();
    _posSub?.cancel();
    _completeSub?.cancel();
    nowPlaying.removeListener(_onNowPlayingChanged);
    MediaSession.onPlayPause = null;
    MediaSession.onPrev = null;
    MediaSession.onNext = null;
    _playingSub = null;
    _posSub = null;
    _completeSub = null;
    _started = false;
  }
}
