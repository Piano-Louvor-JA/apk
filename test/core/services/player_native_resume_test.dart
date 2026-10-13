import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/player_native.dart'
    as native;

class _Audio extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  int plays = 0;
  int resumes = 0;
  Duration position = Duration.zero;
  @override
  Source? source;
  bool failPlay = false;
  @override
  Stream<PlayerState> get onPlayerStateChanged => states.stream;
  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();
  @override
  Future<void> setAudioContext(AudioContext context) async {}
  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    plays++;
    if (failPlay) throw StateError('fonte indisponível');
    this.source = source;
    this.position = position ?? Duration.zero;
    states.add(PlayerState.playing);
  }

  @override
  Future<void> pause() async => states.add(PlayerState.paused);
  @override
  Future<void> resume() async {
    resumes++;
    states.add(PlayerState.playing);
  }

  @override
  Future<void> stop() async => states.add(PlayerState.stopped);
  @override
  Future<void> seek(Duration position) async => this.position = position;
  @override
  Future<void> dispose() => states.close();
}

void main() {
  for (final url in ['https://example.com/hino.mp3', '/downloads/hino.mp3']) {
    test('toggle retoma a mesma fonte sem recarregar: $url', () async {
      final audio = _Audio();
      final player = native.createPlayerImpl(audioPlayer: audio);
      addTearDown(player.dispose);
      await player.toggleUrl(url);
      await player.seek(const Duration(seconds: 18));
      await player.toggleUrl(url);
      expect(player.isPlaying, isFalse);
      await player.toggleUrl(url);
      expect(audio.plays, 1);
      expect(audio.resumes, 1);
      expect(audio.position, const Duration(seconds: 18));
      expect(player.currentUrl, url);
      expect(
        audio.source,
        url.startsWith('http') ? isA<UrlSource>() : isA<DeviceFileSource>(),
      );
    });
  }
  test('resume sem fonte e após stop não reativa áudio antigo', () async {
    final audio = _Audio();
    final player = native.createPlayerImpl(audioPlayer: audio);
    addTearDown(player.dispose);
    await player.resume();
    await player.playUrl('https://example.com/hino.mp3');
    await player.stop();
    await player.resume();
    expect(audio.resumes, 0);
    expect(player.currentUrl, isNull);
    expect(player.isPlaying, isFalse);
  });
  test('fonte com falha não se torna candidata a resume', () async {
    final audio = _Audio()..failPlay = true;
    final player = native.createPlayerImpl(audioPlayer: audio);
    addTearDown(player.dispose);
    await expectLater(
      player.playUrl('https://example.com/falha.mp3'),
      throwsStateError,
    );
    expect(player.currentUrl, isNull);
    await player.resume();
    expect(audio.resumes, 0);
  });
}
