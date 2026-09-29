library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await RemoteSession.instance.dispose();
    await server.close(force: true);
  });

  test('idle → connectDesktop → connected com state do desktop', () async {
    WebSocket? desktop;
    server.listen((req) async {
      desktop = await WebSocketTransformer.upgrade(req);
      desktop!.listen((_) {});
      // state push na conexão (resync)
      desktop!.add(
        RemotePlayerState(
          hymnId: 7,
          title: 'To God Be the Glory',
          mode: 'audio',
          playing: false,
          position: Duration.zero,
          duration: const Duration(minutes: 4),
          slideIndex: 0,
          slideCount: 6,
          volume: 50,
          canPrevious: false,
          canNext: true,
        ).encode(),
      );
    });

    final session = RemoteSession.instance;
    expect(session.mode, RemoteMode.idle);

    final ok = await session.connectDesktop(
      host: '127.0.0.1',
      port: server.port,
      token: 'T',
    );
    expect(ok, isTrue);
    expect(session.mode, RemoteMode.desktop);

    // Regressão: state chega no upgrade WS, antes da UI assinar `states`.
    // Session precisa cachear/repassar o frame sem depender de listener tardio.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(session.lastState?.title, 'To God Be the Glory');
    await desktop?.close();
  });

  test('desktop_closed derruba sessão remota imediatamente', () async {
    WebSocket? desktop;
    server.listen((req) async {
      desktop = await WebSocketTransformer.upgrade(req);
      desktop!.listen((_) {});
    });

    final session = RemoteSession.instance;
    expect(
      await session.connectDesktop(
        host: '127.0.0.1',
        port: server.port,
        token: 'T',
      ),
      isTrue,
    );
    desktop!.add(
      const RemoteError(id: 'server', code: 'desktop_closed').encode(),
    );

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(session.mode, RemoteMode.idle);
    expect(session.lastState, isNull);
  });

  test('sendCommand desktop → servidor recebe comando com token', () async {
    final received = <RemoteCommand>[];
    WebSocket? desktop;
    server.listen((req) async {
      desktop = await WebSocketTransformer.upgrade(req);
      desktop!.listen((data) {
        final m = RemoteProtocol.parse(data as String);
        if (m is RemoteCommand) received.add(m);
      });
    });

    final session = RemoteSession.instance;
    await session.connectDesktop(
      host: '127.0.0.1',
      port: server.port,
      token: 'TKN123',
    );
    await session.send(
      RemoteCommand(id: 'q1', action: RemoteAction.liturgySelect, index: 2),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(received.single.action, RemoteAction.liturgySelect);
    expect(received.single.index, 2);
    expect(received.single.token, 'TKN123');
    await desktop?.close();
  });

  test(
    'isControlling: web link só controla quando o browser conecta',
    () async {
      final session = RemoteSession.instance;
      // Desktop conectado = controlando direto.
      server.listen((req) async {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.listen((_) {});
      });
      await session.connectDesktop(
        host: '127.0.0.1',
        port: server.port,
        token: 'T',
      );
      expect(session.mode, RemoteMode.desktop);
      expect(
        session.isControlling,
        isTrue,
        reason: 'desktop conectado deve controlar',
      );
      await session.disconnect();
      expect(session.isControlling, isFalse);

      // Web link: servidor de pé ≠ controlando; só quando o browser conecta.
      final url = await session.startWebLink(token: 'WEB2');
      expect(url, isNotNull);
      expect(session.mode, RemoteMode.web);
      expect(
        session.isControlling,
        isFalse,
        reason: 'web link escutando sem cliente não é controlling',
      );

      // Assina ANTES de conectar: broadcast perde frames de listeners tardios.
      final connected = Completer<void>();
      final sub = session.status.listen((s) {
        if (s == RemoteSessionStatus.connected && !connected.isCompleted) {
          connected.complete();
        }
      });
      final browser = await WebSocket.connect(url!);
      await connected.future.timeout(const Duration(seconds: 5));
      expect(
        session.isControlling,
        isTrue,
        reason: 'browser conectado via web link deve controlar',
      );

      await browser.close();
      final dropped = Completer<void>();
      await sub.cancel();
      final sub2 = session.status.listen((s) {
        if (s == RemoteSessionStatus.listening && !dropped.isCompleted) {
          dropped.complete();
        }
      });
      await dropped.future.timeout(const Duration(seconds: 5));
      expect(
        session.isControlling,
        isFalse,
        reason: 'browser desconectado deve sair de controlling',
      );
      await sub2.cancel();
    },
  );

  test('startWebLink → APK envia comando; web devolve state', () async {
    final session = RemoteSession.instance;
    final url = await session.startWebLink(token: 'WEB9');
    expect(url, isNotNull);
    expect(session.mode, RemoteMode.web);
    expect(url, contains('WEB9'));

    final web = await WebSocket.connect(url!);
    final frames = <String>[];
    web.listen((d) => frames.add(d as String));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // comando do operador: APK → web
    await session.send(RemoteCommand(id: 'w1', action: RemoteAction.play));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(frames.where((f) => f.contains('player.play')), isNotEmpty);

    // estado do player: web → APK
    final gotState = Completer<void>();
    session.states.listen((_) {
      if (!gotState.isCompleted) gotState.complete();
    });
    web.add(
      const RemotePlayerState(
        hymnId: 1,
        title: 'Teste',
        mode: 'audio',
        playing: true,
        position: Duration.zero,
        duration: Duration(minutes: 1),
        slideIndex: 0,
        slideCount: 1,
        volume: 70,
        canPrevious: false,
        canNext: false,
      ).encode(),
    );
    await gotState.future.timeout(const Duration(seconds: 5));
    expect(session.lastState?.title, 'Teste');
    await web.close();
  });

  test('disconnect volta a idle e limpa', () async {
    server.listen((req) async {
      final ws = await WebSocketTransformer.upgrade(req);
      ws.listen((_) {});
    });
    final session = RemoteSession.instance;
    await session.connectDesktop(
      host: '127.0.0.1',
      port: server.port,
      token: 'T',
    );
    expect(session.mode, RemoteMode.desktop);
    await session.disconnect();
    expect(session.mode, RemoteMode.idle);
  });
}
