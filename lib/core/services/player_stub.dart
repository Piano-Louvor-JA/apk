// coverage:ignore-file
/// Stub — resolve a implementação correta em runtime.
library;

import 'hymn_audio_player.dart';

class _StubAudioPlayer implements HymnAudioPlayer {
  @override
  String? get currentUrl => null;
  @override
  bool get isPlaying => false;
  @override
  Stream<bool> get playingStream => Stream.empty();
  @override
  Stream<void> get completionStream => Stream.empty();
  @override
  Stream<Duration> get positionStream => Stream.empty();
  @override
  Stream<Duration> get durationStream => Stream.empty();
  @override
  Future<void> playUrl(String url) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> setVolume(double v) async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> toggleUrl(String url) async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

HymnAudioPlayer createPlayerImpl() => _StubAudioPlayer();
