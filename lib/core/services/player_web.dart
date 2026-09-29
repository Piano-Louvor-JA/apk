// coverage:ignore-file
/// Player Web usando dart:html AudioElement.
library;

// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html';

import 'hymn_audio_player.dart';

HymnAudioPlayer createPlayerImpl() => _WebAudioPlayer();

class _WebAudioPlayer implements HymnAudioPlayer {
  AudioElement? _audio;
  String? _currentUrl;
  bool _isPlaying = false;

  final _controller = StreamController<bool>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();

  @override
  String? get currentUrl => _currentUrl;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Stream<bool> get playingStream => _controller.stream;

  final _completions = StreamController<void>.broadcast();

  @override
  Stream<void> get completionStream => _completions.stream;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Stream<Duration> get durationStream => _durations.stream;

  @override
  Future<void> seek(Duration position) async {
    _ensure();
    if (_audio != null) _audio!.currentTime = position.inMilliseconds / 1000.0;
  }

  @override
  Future<void> setVolume(double v) async {
    _ensure();
    if (_audio != null) _audio!.volume = v;
  }

  void _ensure() {
    _audio ??= AudioElement()
      ..onPlay.listen((_) {
        _isPlaying = true;
        _controller.add(true);
      })
      ..onPause.listen((_) {
        _isPlaying = false;
        _controller.add(false);
      })
      ..onEnded.listen((_) {
        _isPlaying = false;
        _controller.add(false);
        _completions.add(null);
      })
      ..onError.listen((_) {
        _isPlaying = false;
        _controller.add(false);
      });

    // Timeline: emite posicao (1x/s do browser) e duracao quando conhecida.
    // Cache + replay da duracao (broadcast sem replay = slider em 0).
    Duration? cachedDur;
    Timer.periodic(const Duration(seconds: 1), (_) {
      final a = _audio;
      if (a == null) return;
      _positions.add(Duration(milliseconds: a.currentTime * 1000 ~/ 1));
      final d = a.duration;
      if (d.isFinite && d > 0) {
        cachedDur = Duration(milliseconds: (d * 1000).toInt());
        _durations.add(cachedDur!);
      }
    });
    _durations.onListen = () {
      if (cachedDur != null) _durations.add(cachedDur!);
    };
  }

  @override
  Future<void> toggleUrl(String url) async {
    _ensure();
    if (_currentUrl == url && _isPlaying) {
      _audio!.pause();
      return;
    }
    await playUrl(url);
  }

  @override
  Future<void> playUrl(String url) async {
    _ensure();
    _currentUrl = url;
    _audio!.src = url;
    try {
      _audio!.play();
    } catch (_) {
      // Browser pode bloquear autoplay; erro tratado silenciosamente.
    }
  }

  @override
  Future<void> pause() async {
    _ensure();
    _audio!.pause();
  }

  @override
  Future<void> stop() async {
    _ensure();
    _audio!.pause();
    _currentUrl = null;
  }

  @override
  void dispose() {
    _audio?.pause();
    _audio = null;
    _controller.close();
    _completions.close();
  }
}

// volume: no-op em web
