import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_player_adapter.dart';
import 'package:mocktail/mocktail.dart';

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


class _MockPlayer extends Mock implements HymnAudioPlayer {}

void main() {
  late _MockPlayer player;
  late StreamController<bool> playingCtrl;

  setUp(() {
    player = _MockPlayer();
    playingCtrl = StreamController<bool>.broadcast();
    registerFallbackValue(const Duration(seconds: 1));
    when(() => player.isPlaying).thenReturn(false);
    when(() => player.playingStream).thenAnswer((_) => playingCtrl.stream);
    when(() => player.positionStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => player.durationStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => player.currentUrl).thenReturn(null);
    when(() => player.resume()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await playingCtrl.close();
  });

  test('adapter espelha playingStream no listenable', () async {
    final adapter = HymnPlayerAdapter(player);
    expect(adapter.playingListenable.value, isFalse);
    final seen = <bool>[];
    void listener() => seen.add(adapter.playingListenable.value);
    adapter.playingListenable.addListener(listener);
    await playingCtrl.addStream(Stream.fromIterable([true, false]));
    await Future<void>.delayed(Duration.zero);
    adapter.playingListenable.removeListener(listener);
    expect(seen, contains(true));
    expect(seen, contains(false));
  });

  test('isPlaying/position/duration/seek/setVolume/stop delegam pro player',
      () async {
    when(() => player.isPlaying).thenReturn(true);
    when(() => player.seek(any())).thenAnswer((_) async {});
    when(() => player.setVolume(any())).thenAnswer((_) async {});
    when(() => player.stop()).thenAnswer((_) async {});

    final adapter = HymnPlayerAdapter(player);
    expect(adapter.isPlaying, isTrue);
    expect(adapter.positionStream, isA<Stream<Duration>>());
    expect(adapter.durationStream, isA<Stream<Duration>>());
    await adapter.seek(const Duration(seconds: 5));
    await adapter.setVolume(0.5);
    await adapter.stop();
    verify(() => player.seek(const Duration(seconds: 5))).called(1);
    verify(() => player.setVolume(0.5)).called(1);
    verify(() => player.stop()).called(1);
  });

  test('pause e resume delegam sem recarregar a URL', () async {
    when(() => player.pause()).thenAnswer((_) async {});
    when(() => player.currentUrl).thenReturn('http://x/15.mp3');
    when(() => player.playUrl(any())).thenAnswer((_) async {});

    final adapter = HymnPlayerAdapter(player);
    await adapter.pause();
    verify(() => player.pause()).called(1);

    await adapter.resume();
    verify(() => player.resume()).called(1);
    verifyNever(() => player.playUrl(any()));
  });

  test('resume sem url atual não chama playUrl', () async {
    when(() => player.playUrl(any())).thenAnswer((_) async {});
    final adapter = HymnPlayerAdapter(player);
    await adapter.resume();
    verifyNever(() => player.playUrl(any()));
  });

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

  test(
    'playingListenable reflete pause/resume do player de plataforma',
    () async {
      final platform = _FakePlatformPlayer();
      final adapter = HymnPlayerAdapter(platform);

      expect(adapter.playingListenable.value, isFalse);
      await platform.playUrl('https://api.example.com/musica.mp3');
      expect(adapter.playingListenable.value, isTrue);
      await adapter.pause();
      expect(adapter.playingListenable.value, isFalse);
      await adapter.resume();
      expect(adapter.playingListenable.value, isTrue);
    },
  );

}
