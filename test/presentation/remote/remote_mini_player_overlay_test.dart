import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_player_presence.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_mini_player_overlay.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_player_bar.dart';

class _Session extends RemoteSession {
  bool connected = true;
  final sent = <RemoteCommand>[];
  @override
  bool get isControlling => connected;
  @override
  Future<void> send(RemoteCommand command) async => sent.add(command);
}

void main() {
  late _Session session;
  late RemotePlayerPresence presence;
  late GlobalKey<NavigatorState> navigatorKey;
  setUp(() {
    session = _Session();
    presence = RemotePlayerPresence();
    navigatorKey = GlobalKey<NavigatorState>();
    session.debugInjectStateForTest(title: 'Digno', playing: true);
  });
  tearDown(() async => session.dispose());

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (_, child) => RemoteMiniPlayerOverlay(
          navigatorKey: navigatorKey,
          session: session,
          presence: presence,
          child: child!,
        ),
        home: const Scaffold(body: Text('Bíblia')),
      ),
    );
    await tester.pump();
  }

  testWidgets('acompanha rotas, pausa e expande sem reiniciar a mídia', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byKey(const Key('remote-mini-player')), findsOneWidget);
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Outra página')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('remote-mini-player')), findsOneWidget);
    await tester.tap(find.byKey(const Key('remote-mini-toggle')));
    expect(session.sent.single.action, RemoteAction.pause);
    await tester.tap(find.byKey(const Key('remote-mini-expand')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('remote-player-bar')), findsOneWidget);
    expect(find.byKey(const Key('remote-mini-player')), findsNothing);
    expect(
      session.sent,
      hasLength(1),
      reason: 'Expandir não pode abrir/tocar novamente',
    );
    await tester.tap(find.byKey(const Key('remote-player-minimize')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byKey(const Key('remote-player-bar')), findsNothing);
    expect(find.byKey(const Key('remote-mini-player')), findsOneWidget);
    expect(find.text('Outra página'), findsOneWidget);
    expect(session.sent, hasLength(1), reason: 'Minimizar preserva música e projeção');
  });

  testWidgets(
    'oculta no player completo, reaparece pausado e some ao desconectar',
    (tester) async {
      final owner = Object();
      presence.update(owner, true);
      await mount(tester);
      expect(find.byKey(const Key('remote-mini-player')), findsNothing);
      presence.update(owner, false);
      session.debugInjectStateForTest(title: 'Digno', playing: false);
      await tester.pump();
      expect(find.byKey(const Key('remote-mini-player')), findsOneWidget);
      session.connected = false;
      await session.disconnect();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('remote-mini-player')), findsNothing);
    },
  );
  testWidgets(
    'visibilidade real do player acompanha aba e rota, sem duplicar o mini',
    (tester) async {
      presence = remotePlayerPresence;
      late StateSetter change;
      var full = true;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          builder: (_, child) => RemoteMiniPlayerOverlay(
            navigatorKey: navigatorKey,
            session: session,
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (_, update) {
              change = update;
              return Scaffold(
                body: Offstage(
                  offstage: !full,
                  child: TickerMode(
                    enabled: full,
                    child: RemotePlayerBar(
                      state: session.lastState!,
                      showTransport: true,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('remote-mini-player')), findsNothing);
      change(() => full = false);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('remote-mini-player')), findsOneWidget);
      change(() => full = true);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('remote-mini-player')), findsNothing);
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Bíblia')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remote-mini-player')), findsOneWidget);
      expect(session.sent, isEmpty);
    },
  );

  testWidgets(
    'mini mostra a letra atual, confirma fechar e some quando a mídia encerra',
    (tester) async {
      session.debugEmitStateForTest(
        const RemotePlayerState(
          hymnId: 1,
          title: 'Digno',
          playing: true,
          position: Duration.zero,
          duration: Duration(minutes: 3),
          slideIndex: 0,
          slideCount: 1,
          slideLyrics: ['Letra do hino'],
          volume: 60,
          canPrevious: false,
          canNext: false,
        ),
      );
      await mount(tester);
      expect(find.text('Letra do hino'), findsOneWidget);
      await tester.tap(find.byKey(const Key('remote-mini-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remote-close-confirm')), findsOneWidget);
      expect(session.sent, isEmpty);
      await tester.tap(find.byKey(const Key('remote-close-ok')));
      await tester.pumpAndSettle();
      expect(session.sent.single.action, RemoteAction.stop);
      session.debugInjectStateForTest(playing: false, duration: Duration.zero);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('remote-mini-player')), findsNothing);
    },
  );
  testWidgets('seta do mini player alterna projeção e não encerra a mídia', (tester) async {
    session.debugEmitStateForTest(const RemotePlayerState(
      hymnId: 1, title: 'Hino', playing: true,
      position: Duration.zero, duration: Duration(minutes: 3),
      slideIndex: 0, slideCount: 1, volume: 60,
      canPrevious: false, canNext: false,
      videoControls: RemoteVideoControls(
        audioOutput: 'player', canProject: true, projecting: false,
        canControlCaptions: false, captionsHidden: false,
        monitors: [], tvs: [],
      ),
    ));
    await mount(tester);
    expect(find.byKey(const Key('remote-video-project')), findsOneWidget);
    await tester.tap(find.byKey(const Key('remote-video-project')));
    expect(session.sent.single.action, RemoteAction.videoToggleProjection);
  });

}
