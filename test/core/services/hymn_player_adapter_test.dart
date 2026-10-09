import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_player_adapter.dart';
import 'package:mocktail/mocktail.dart';

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

  test('pause delega; resume com url atual chama playUrl(url)', () async {
    when(() => player.pause()).thenAnswer((_) async {});
    when(() => player.currentUrl).thenReturn('http://x/15.mp3');
    when(() => player.playUrl(any())).thenAnswer((_) async {});

    final adapter = HymnPlayerAdapter(player);
    await adapter.pause();
    verify(() => player.pause()).called(1);

    await adapter.resume();
    verify(() => player.playUrl('http://x/15.mp3')).called(1);
  });

  test('resume sem url atual não chama playUrl', () async {
    when(() => player.playUrl(any())).thenAnswer((_) async {});
    final adapter = HymnPlayerAdapter(player);
    await adapter.resume();
    verifyNever(() => player.playUrl(any()));
  });
}
