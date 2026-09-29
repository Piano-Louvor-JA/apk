// coverage:ignore-file
/// Interface do player de audio.
library;

import 'player_stub.dart'
    if (dart.library.html) 'player_web.dart'
    if (dart.library.io) 'player_native.dart';

abstract class HymnAudioPlayer {
  static final HymnAudioPlayer instance = createPlayer();

  String? get currentUrl;
  bool get isPlaying;

  Stream<bool> get playingStream;

  /// Emitido quando a faixa atual TERMINA (completou, não pausa/stop).
  /// Usado pela fila de "Tocar tudo" do álbum para avançar automaticamente.
  Stream<void> get completionStream;

  /// Posição atual (ms) e duração (ms) da faixa em reprodução.
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;

  /// Move a reprodução para [position].
  Future<void> seek(Duration position);

  /// Volume do player local (modo tv do Palco usa 0 = mudo/controle).
  Future<void> setVolume(double v);

  Future<void> toggleUrl(String url);
  Future<void> playUrl(String url);
  Future<void> pause();
  Future<void> stop();
  void dispose();
}

HymnAudioPlayer createPlayer() => createPlayerImpl();
