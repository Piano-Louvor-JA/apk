// coverage:ignore-file
/// Player nativo (Android/iOS) usando audioplayers.
library;

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

import 'hymn_audio_player.dart';

HymnAudioPlayer createPlayerImpl({AudioPlayer? audioPlayer}) =>
    _NativeAudioPlayer(audioPlayer: audioPlayer);

class _NativeAudioPlayer implements HymnAudioPlayer {
  final AudioPlayer _player;
  String? _currentUrl;
  bool _isPlaying = false;

  final _controller = StreamController<bool>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();

  _NativeAudioPlayer({AudioPlayer? audioPlayer})
    : _player = audioPlayer ?? AudioPlayer() {
    // AudioContext explicito (F3.3b): sem usage=media o One UI classifica a
    // reproducao como nao-midia em background ("AudioHardening ... would be
    // muted") e muta/pausa o player — que e o relógio dos slides do Palco.
    // stayAwake mantem o wake lock do audio (letra sincronizada em bg).
    unawaited(
      _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.media,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.gain,
            stayAwake: true,
          ),
        ),
      ),
    );
    _player.onPositionChanged.listen((pos) => _positions.add(pos));
    // Cache + replay: duração pode chegar antes do NowPlayingPage assinar
    // (broadcast stream sem replay = evento perdido = slider em 0).
    Duration? cached;
    _player.onDurationChanged.listen((dur) {
      cached = dur;
      _durations.add(dur);
    });
    _durations.onListen = () {
      if (cached != null) _durations.add(cached!);
    };
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      _controller.add(_isPlaying);
      if (state == PlayerState.completed) _completions.add(null);
    });
  }

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
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double v) => _player.setVolume(v);

  @override
  Future<void> toggleUrl(String url) async {
    if (_currentUrl == url) {
      if (_isPlaying) {
        await pause();
      } else {
        await resume();
      }
      return;
    }
    await playUrl(url);
  }

  @override
  Future<void> playUrl(String url) async {
    _currentUrl = null;
    // Offline-first: caminho local (arquivo baixado) usa DeviceFileSource;
    // URL http(s) mantem streaming.
    if (url.startsWith('http://') || url.startsWith('https://')) {
      await _player.play(UrlSource(url));
    } else {
      await _player.play(DeviceFileSource(url));
    }
    _currentUrl = url;
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    final url = _currentUrl;
    if (url == null) return;
    // Após conclusão, ReleaseMode.release libera a fonte do audioplayers.
    // Uma faixa pausada ainda tem fonte e preserva sua posição no resume.
    if (_player.source == null) {
      await playUrl(url);
      return;
    }
    await _player.resume();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _currentUrl = null;
  }

  @override
  void dispose() {
    _player.dispose();
    _controller.close();
    _completions.close();
  }
}
