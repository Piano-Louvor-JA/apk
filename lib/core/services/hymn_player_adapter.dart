library;

import 'package:flutter/foundation.dart';

import '../../core/services/hymn_audio_player.dart';
import '../../core/services/now_playing.dart';

/// Adapta o [HymnAudioPlayer] real (singleton de plataforma) para a
/// interface `HymnPlayerLike` consumida pelo MiniPlayerBar.
///
/// `playingStream` (Stream de bool) vira ValueNotifier espelhado.
class HymnPlayerAdapter implements HymnPlayerLike {
  final HymnAudioPlayer _player;
  final ValueNotifier<bool> _playing;

  HymnPlayerAdapter(this._player)
    : _playing = ValueNotifier<bool>(_player.isPlaying) {
    _player.playingStream.listen((playing) {
      _playing.value = playing;
    });
  }

  @override
  bool get isPlaying => _player.isPlaying;

  @override
  ValueListenable<bool> get playingListenable => _playing;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration> get durationStream => _player.durationStream;

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double v) => _player.setVolume(v);

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() async {
    // HymnAudioPlayer nao tem resume: toggleUrl na URL atual retoma.
    final url = _player.currentUrl;
    if (url != null) await _player.playUrl(url);
  }

  @override
  Future<void> stop() => _player.stop();
}
