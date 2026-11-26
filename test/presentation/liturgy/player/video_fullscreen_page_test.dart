import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/player/video_fullscreen_page.dart';

RemotePlayerState _state({
  bool playing = true,
  int seconds = 30,
  int volume = 80,
}) => RemotePlayerState(
  title: 'Deus o Pode',
  playing: playing,
  position: Duration(seconds: seconds),
  duration: const Duration(minutes: 4, seconds: 47),
  slideIndex: 0,
  slideCount: 0,
  volume: volume,
  canPrevious: false,
  canNext: false,
);

void main() {
  late List<RemoteCommand> sent;
  late StreamController<RemotePlayerState> states;
  late List<MethodCall> system;

  setUp(() {
    sent = [];
    states = StreamController<RemotePlayerState>.broadcast();
    system = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          system.add(call);
          return null;
        });
  });
  tearDown(() => states.close());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              VideoFullscreenPage.route(
                initial: _state(),
                states: states.stream,
                send: (command) async => sent.add(command),
                video: const ColoredBox(
                  key: Key('the-video'),
                  color: Colors.blue,
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'mostra o vídeo, o título e o tempo; entra em tela cheia de verdade',
    (tester) async {
      await open(tester);
      expect(find.byKey(const Key('the-video')), findsOneWidget);
      expect(find.text('Deus o Pode'), findsOneWidget);
      expect(find.text('00:30'), findsOneWidget);
      expect(find.text('04:47'), findsOneWidget);
      // Libera o giro (paisagem) e esconde as barras do sistema.
      expect(
        system.map((c) => c.method),
        containsAll([
          'SystemChrome.setPreferredOrientations',
          'SystemChrome.setEnabledSystemUIMode',
        ]),
      );
    },
  );

  testWidgets('play/pausa e arrastar a barra mandam o comando ao player', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('video-fullscreen-play')));
    expect(sent.last.action, RemoteAction.pause);

    states.add(_state(playing: false, seconds: 60));
    await tester.pump();
    expect(find.text('01:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('video-fullscreen-play')));
    expect(sent.last.action, RemoteAction.play);

    await tester.tap(find.byKey(const Key('video-fullscreen-seek')));
    await tester.pump();
    expect(sent.last.action, RemoteAction.seek);
  });

  testWidgets(
    'controle de áudio: ícone acima do play abre o volume para cima',
    (tester) async {
      await open(tester);
      final audio = find.byKey(const Key('video-fullscreen-audio'));
      final play = find.byKey(const Key('video-fullscreen-play'));
      expect(tester.getCenter(audio).dy, lessThan(tester.getCenter(play).dy));
      expect(find.byKey(const Key('video-fullscreen-volume')), findsNothing);

      await tester.tap(audio);
      await tester.pump();
      final volume = find.byKey(const Key('video-fullscreen-volume'));
      expect(volume, findsOneWidget);
      // Vertical, acima do ícone.
      final box = tester.getRect(
        find.byKey(const Key('video-fullscreen-volume-panel')),
      );
      expect(box.height, greaterThan(box.width));
      expect(box.center.dy, lessThan(tester.getCenter(audio).dy));

      await tester.tap(volume);
      await tester.pump();
      expect(sent.last.action, RemoteAction.setVolume);
      expect(sent.last.volume, inInclusiveRange(30, 70));

      await tester.tap(find.byKey(const Key('video-fullscreen-mute')));
      expect(sent.last.volume, 0);
      states.add(_state(volume: 0));
      await tester.pump();
      await tester.tap(find.byKey(const Key('video-fullscreen-mute')));
      expect(sent.last.volume, 80);

      // Tocar de novo no ícone fecha.
      await tester.tap(audio);
      await tester.pump();
      expect(find.byKey(const Key('video-fullscreen-volume')), findsNothing);
    },
  );

  testWidgets('enquanto aberta, avisa para o player minimizado não aparecer', (
    tester,
  ) async {
    expect(VideoFullscreenPage.open.value, isFalse);
    await open(tester);
    expect(VideoFullscreenPage.open.value, isTrue);
    await tester.tap(find.byKey(const Key('video-fullscreen-exit')));
    await tester.pumpAndSettle();
    expect(VideoFullscreenPage.open.value, isFalse);
  });

  testWidgets('sair volta à barra e devolve o celular em pé', (tester) async {
    await open(tester);
    system.clear();
    await tester.tap(find.byKey(const Key('video-fullscreen-exit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('the-video')), findsNothing);
    final orientation = system.lastWhere(
      (c) => c.method == 'SystemChrome.setPreferredOrientations',
    );
    expect(orientation.arguments, ['DeviceOrientation.portraitUp']);
  });

  testWidgets('mídia fechada fecha a tela cheia', (tester) async {
    await open(tester);
    states.add(
      const RemotePlayerState(
        playing: false,
        position: Duration.zero,
        duration: Duration.zero,
        slideIndex: 0,
        slideCount: 0,
        volume: 80,
        canPrevious: false,
        canNext: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('the-video')), findsNothing);
  });
}
