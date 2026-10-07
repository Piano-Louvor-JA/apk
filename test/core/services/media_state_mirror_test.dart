// SPEC media-service (apk#132 follow-up): espelho de estado player → sessão.
//
// O sistema (notificação MediaStyle, lock screen, barra PiP) alimenta-se
// da MediaSession. Hoje a sessão só atualiza quando o botão DENTRO da
// NowPlayingPage é tocado — o player real nunca reporta estado, então a
// barra nativa mostra PLAY enquanto o áudio toca e nenhum toque pausa de
// verdade (evidência A15 15:57: dispatchAction com hasPlayCb=true e
// dumpsys state=PAUSED com áudio audível).
//
// O MediaStateMirror liga o singleton HymnAudioPlayer ao canal nativo
// `app.louvorja/media` (setPlaybackState/show/hide) — o MESMO padrão do
// YouTube/Spotify: player → sessão → sistema alimenta notificação + lock
// screen + PiP do MESMO estado.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/media_session.dart';
import 'package:louvorja_piano_mobile/core/services/media_state_mirror.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';

/// Player falso controlado pelo teste (emite nos streams como o nativo).
class _FakePlayer implements HymnAudioPlayer {
  final _playing = StreamController<bool>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();
  final _completions = StreamController<void>.broadcast();

  @override
  bool isPlaying = false;
  @override
  String? currentUrl;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<void> get completionStream => _completions.stream;
  @override
  Stream<Duration> get positionStream => _positions.stream;
  @override
  Stream<Duration> get durationStream => _durations.stream;
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double v) async {}
  @override
  Future<void> toggleUrl(String url) async {}
  @override
  Future<void> playUrl(String url) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}

  void emitPlaying(bool v) {
    isPlaying = v;
    _playing.add(v);
  }

  void emitPosition(Duration d) => _positions.add(d);
  void emitCompletion() => _completions.add(null);
}

/// Captura as chamadas ao canal `app.louvorja/media`.
Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlayer player;
  const channel = MethodChannel('app.louvorja/media');
  final calls = <String, List<Object?>>{};

  setUp(() {
    player = _FakePlayer();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      (calls[call.method] ??= <Object?>[]).add(call.arguments);
      return null;
    });
  });

  tearDown(() {
    MediaStateMirror.stop();
    MediaSession.release();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('player tocando → setPlaybackState(isPlaying: true) no nativo', () async {
    MediaStateMirror.start(player: player);
    await _pump();

    player.emitPlaying(true);
    await _pump();
    await _pump();

    final states = calls['setPlaybackState'];
    expect(states, isNotNull, reason: 'espelho deve chamar setPlaybackState');
    expect((states!.last as Map)['isPlaying'], true);
    // Nota: a notificação em si é publicada pelo postNotification NATIVO
    // dentro de setPlaybackState/setMetadata — não há chamada 'show'
    // separada no desenho atual (era assert incorreto do teste).
  });

  test('player toca → startMediaService; para → stopMediaService (One UI freeze)',
      () async {
    MediaStateMirror.start(player: player);
    await _pump();

    player.emitPlaying(true);
    await _pump();
    await _pump();
    expect(calls.containsKey('startMediaService'), isTrue,
        reason: 'FGS de mídia deve subir quando o player toca '
            '(One UI congela processo sem serviço foreground)');

    calls.clear();
    player.emitPlaying(false);
    await _pump();
    await _pump();
    expect(calls.containsKey('stopMediaService'), isTrue,
        reason: 'FGS deve descer quando o player para (sem notificação órfã)');
  });

  test('player pausa → setPlaybackState(isPlaying: false) — bug 15:57', () async {
    MediaStateMirror.start(player: player);
    await _pump();
    player.emitPlaying(true);
    await _pump();

    player.emitPlaying(false);
    await _pump();
    await _pump();

    final states = calls['setPlaybackState'];
    expect((states!.last as Map)['isPlaying'], false,
        reason: 'pausa real do player deve refletir na sessão nativa');
  });

  test('posição atualiza setPlaybackState com positionMs', () async {
    MediaStateMirror.start(player: player);
    await _pump();

    player.emitPlaying(true);
    await _pump();
    player.emitPosition(const Duration(seconds: 42));
    await _pump();
    await _pump();

    final last = calls['setPlaybackState']!.last as Map;
    expect(last['positionMs'], 42000);
    expect(last['isPlaying'], true);
  });

  test('faixa termina (completion) → sessão pausada', () async {
    MediaStateMirror.start(player: player);
    await _pump();
    player.emitPlaying(true);
    await _pump();

    player.emitCompletion();
    await _pump();
    await _pump();

    final last = calls['setPlaybackState']!.last as Map;
    expect(last['isPlaying'], false);
  });

  test('nowPlaying.start() → setMetadata com título/álbum da faixa', () async {
    MediaStateMirror.start(player: player);
    await _pump();

    nowPlaying.start(
      hymnId: 1,
      title: 'Santo, Santo, Santo!',
      album: 'Hinários',
      durationMs: 137000,
    );
    await _pump();
    await _pump();

    final meta = calls['setMetadata']!.last as Map;
    expect(meta['title'], 'Santo, Santo, Santo!');
    expect(meta['album'], 'Hinários');
    expect(meta['durationMs'], 137000);
    // postNotification nativo roda dentro do setMetadata (sem 'show' separado).
  });

  test('start é idempotente (sem duplicar listeners)', () async {
    MediaStateMirror.start(player: player);
    MediaStateMirror.start(player: player);
    await _pump();

    player.emitPlaying(true);
    await _pump();
    await _pump();

    final states = calls['setPlaybackState']!;
    expect(states.length, 1, reason: 'listener único mesmo com start duplo');
  });
}
