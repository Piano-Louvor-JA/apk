library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_player_adapter.dart';

/// Fake do player de plataforma: registra chamadas sem tocar áudio real.
class _FakePlatformPlayer extends HymnAudioPlayer {
  final _playing = StreamController<bool>.broadcast();
  bool _isPlaying = false;
  String? _currentUrl;
  Duration? seekedTo;
  int playUrlCalls = 0;
  int resumeCalls = 0;
  int pauseCalls = 0;

  @override
  String? get currentUrl => _currentUrl;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<void> get completionStream => const Stream.empty();

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration> get durationStream => const Stream.empty();

  @override
  Future<void> seek(Duration position) async => seekedTo = position;

  @override
  Future<void> setVolume(double v) async {}

  @override
  Future<void> toggleUrl(String url) async {}

  @override
  Future<void> playUrl(String url) async {
    playUrlCalls++;
    _currentUrl = url;
    _isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    _isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _currentUrl = null;
    _playing.add(false);
  }

  @override
  void dispose() {}
}

void main() {
  test('resume() NÃO chama playUrl (que reinicia a faixa do zero)', () async {
    final platform = _FakePlatformPlayer();
    final adapter = HymnPlayerAdapter(platform);

    await platform.playUrl('https://api.example.com/musica.mp3');
    await adapter.pause();
    await adapter.resume();

    // playUrl foi chamado 1x (o play inicial). O resume NÃO pode chamá-lo
    // de novo — isso reinicia a faixa desde o início (apk#96).
    expect(platform.playUrlCalls, 1);
    expect(platform.resumeCalls, 1);
  });

  test('playingListenable reflete pause/resume do player de plataforma', () async {
    final platform = _FakePlatformPlayer();
    final adapter = HymnPlayerAdapter(platform);

    expect(adapter.playingListenable.value, isFalse);
    await platform.playUrl('https://api.example.com/musica.mp3');
    expect(adapter.playingListenable.value, isTrue);
    await adapter.pause();
    expect(adapter.playingListenable.value, isFalse);
    await adapter.resume();
    expect(adapter.playingListenable.value, isTrue);
  });
}
