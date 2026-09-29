library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/mini_player_bar.dart';

class _FakePlayer extends HymnPlayerLike {
  final _playing = ValueNotifier<bool>(false);
  bool stopped = false;

  @override
  bool get isPlaying => _playing.value;

  @override
  ValueListenable<bool> get playingListenable => _playing;

  @override
  Future<void> pause() async => _playing.value = false;

  @override
  Future<void> resume() async => _playing.value = true;

  @override
  Future<void> stop() async {
    stopped = true;
    _playing.value = false;
  }
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('oculto quando nada tocando', (tester) async {
    final notifier = NowPlayingNotifier();
    final player = _FakePlayer();

    await tester.pumpWidget(
      _wrap(MiniPlayerBar(notifier: notifier, player: player)),
    );

    expect(find.byType(MiniPlayerBar), findsOneWidget);
    expect(find.text('Hino'), findsNothing);
  });

  testWidgets('mostra titulo e album quando ha faixa ativa', (tester) async {
    final notifier = NowPlayingNotifier();
    final player = _FakePlayer();
    notifier.start(title: 'Chegado à Cruz', album: 'Hinário', hymnId: 10);
    player._playing.value = true;

    await tester.pumpWidget(
      _wrap(MiniPlayerBar(notifier: notifier, player: player)),
    );

    expect(find.text('Chegado à Cruz'), findsOneWidget);
    expect(find.text('Hinário'), findsOneWidget);
  });

  testWidgets('pause alterna para play e volta', (tester) async {
    final notifier = NowPlayingNotifier();
    final player = _FakePlayer();
    notifier.start(title: 'Hino A', album: 'Album', hymnId: 1);
    player._playing.value = true;

    await tester.pumpWidget(
      _wrap(MiniPlayerBar(notifier: notifier, player: player)),
    );
    await tester.tap(find.byKey(const Key('miniplayer-toggle')));
    await tester.pump();
    expect(player.isPlaying, isFalse);

    await tester.tap(find.byKey(const Key('miniplayer-toggle')));
    await tester.pump();
    expect(player.isPlaying, isTrue);
  });

  testWidgets('stop limpa o now playing', (tester) async {
    final notifier = NowPlayingNotifier();
    final player = _FakePlayer();
    notifier.start(title: 'Hino A', album: 'Album', hymnId: 1);
    player._playing.value = true;

    await tester.pumpWidget(
      _wrap(MiniPlayerBar(notifier: notifier, player: player)),
    );
    await tester.tap(find.byKey(const Key('miniplayer-stop')));
    await tester.pump();

    expect(player.stopped, isTrue);
    expect(notifier.hasTrack, isFalse);
  });

  testWidgets('tap na barra chama onOpenPlayer', (tester) async {
    final notifier = NowPlayingNotifier();
    final player = _FakePlayer();
    var opened = false;
    notifier.start(title: 'Hino A', album: 'Album', hymnId: 1);
    player._playing.value = true;

    await tester.pumpWidget(
      _wrap(
        MiniPlayerBar(
          notifier: notifier,
          player: player,
          onOpenPlayer: () => opened = true,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('miniplayer-tap-area')));
    await tester.pump();

    expect(opened, isTrue);
  });
}
