library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/desktop_connection.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await desktopCloseAllForTest();
    await server.close(force: true);
  });

  WebSocket? serverSide;
  tearDown(() async {
    await serverSide?.close();
    serverSide = null;
  });

  test('conecta, autentica com token e recebe state', () async {
    final states = <RemotePlayerState>[];
    server.listen((req) async {
      serverSide = await WebSocketTransformer.upgrade(req);
      serverSide!.listen((data) {
        final msg = RemoteProtocol.parse(data as String);
        // servidor exige token no primeiro command
        if (msg is RemoteCommand && msg.token == 'ABC123') {
          serverSide!.add(
            RemotePlayerState(
              hymnId: 15,
              title: 'Rocha Eterna',
              mode: 'audio',
              playing: true,
              position: const Duration(seconds: 34),
              duration: const Duration(minutes: 3),
              slideIndex: 2,
              slideCount: 5,
              volume: 80,
              canPrevious: true,
              canNext: false,
            ).encode(),
          );
        }
      });
    });

    final conn = DesktopConnection();
    final connected = await conn.connect(
      host: '127.0.0.1',
      port: server.port,
      token: 'ABC123',
    );
    expect(connected, isTrue);

    final stateReceived = Completer<void>();
    conn.states.listen((st) {
      states.add(st);
      if (!stateReceived.isCompleted) stateReceived.complete();
    });

    await conn.send(RemoteCommand(id: 'c1', action: RemoteAction.play));
    await stateReceived.future.timeout(const Duration(seconds: 5));
    expect(states.single.hymnId, 15);
    expect(states.single.playing, isTrue);
  });

  test('comando recebe ack do servidor', () async {
    final acks = <RemoteAck>[];
    server.listen((req) async {
      serverSide = await WebSocketTransformer.upgrade(req);
      serverSide!.listen((data) {
        final msg = RemoteProtocol.parse(data as String);
        if (msg is RemoteCommand) {
          serverSide!.add(RemoteAck(id: msg.id, ok: true).encode());
        }
      });
    });

    final conn = DesktopConnection();
    expect(
      await conn.connect(host: '127.0.0.1', port: server.port, token: 'T'),
      isTrue,
    );

    final ackReceived = Completer<void>();
    conn.acks.listen((a) {
      acks.add(a);
      if (!ackReceived.isCompleted) ackReceived.complete();
    });

    await conn.send(RemoteCommand(id: 'a1', action: RemoteAction.pause));
    await ackReceived.future.timeout(const Duration(seconds: 5));
    expect(acks.single.ok, isTrue);
  });

  test('token errado → servidor fecha e estado vira disconnected', () async {
    final statusChanges = <DesktopConnectionStatus>[];
    server.listen((req) async {
      serverSide = await WebSocketTransformer.upgrade(req);
      serverSide!.listen((data) async {
        final msg = RemoteProtocol.parse(data as String);
        if (msg is RemoteCommand && msg.token != 'CERTO') {
          serverSide!.add(
            RemoteError(
              id: msg.id,
              code: 'invalid_token',
              message: 'token',
            ).encode(),
          );
          await serverSide!.close();
        }
      });
    });

    final conn = DesktopConnection();
    expect(
      await conn.connect(host: '127.0.0.1', port: server.port, token: 'ERRADO'),
      isTrue,
    );
    final closed = Completer<void>();
    conn.status.listen((st) {
      statusChanges.add(st);
      if (st == DesktopConnectionStatus.disconnected && !closed.isCompleted) {
        closed.complete();
      }
    });

    await conn.send(RemoteCommand(id: 'x', action: RemoteAction.play));
    await closed.future.timeout(const Duration(seconds: 5));
    expect(statusChanges, contains(DesktopConnectionStatus.disconnected));
  });

  test(
    'reconexão automática após queda (3 tentativas, backoff curto)',
    () async {
      // servidor derruba a primeira conexão; a segunda fica de pé
      var connections = 0;
      late StreamSubscription<HttpRequest> sub;
      sub = server.listen((req) async {
        connections++;
        serverSide = await WebSocketTransformer.upgrade(req);
        if (connections == 1) {
          await serverSide!.close();
          return;
        }
        serverSide!.listen((data) {
          final msg = RemoteProtocol.parse(data as String);
          if (msg is RemoteCommand) {
            serverSide!.add(RemoteAck(id: msg.id, ok: true).encode());
          }
        });
      });

      final conn = DesktopConnection(
        heartbeat: const Duration(milliseconds: 300),
        reconnectDelays: const [
          Duration(milliseconds: 100),
          Duration(milliseconds: 100),
        ],
      );
      expect(
        await conn.connect(host: '127.0.0.1', port: server.port, token: 'T'),
        isTrue,
      );
      final reconnected = Completer<void>();
      conn.status.listen((s) {
        if (s == DesktopConnectionStatus.connected &&
            !reconnected.isCompleted) {
          // ignora a primeira (connect inicial)
        }
      });
      // aguarda queda + reconexão
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(connections, greaterThanOrEqualTo(2));
      await sub.cancel();
    },
  );

  test('ping do servidor recebe pong do cliente', () async {
    final received = <String>[];
    server.listen((req) async {
      serverSide = await WebSocketTransformer.upgrade(req);
      serverSide!.listen((data) => received.add(data as String));
    });

    final conn = DesktopConnection();
    await conn.connect(host: '127.0.0.1', port: server.port, token: 'T');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    serverSide!.add(const RemotePing().encode());
    final gotPong = Completer<void>();
    Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (received.any((m) => m.contains('"pong"')) && !gotPong.isCompleted) {
        gotPong.complete();
        t.cancel();
      }
    });
    await gotPong.future.timeout(const Duration(seconds: 2));
  });

  test('connect em porta morta → false sem exceção', () async {
    final conn = DesktopConnection();
    final deadPort = server.port; // server ainda não escuta (setup bindou em 0)
    await server.close(force: true);
    expect(
      await conn.connect(host: '127.0.0.1', port: deadPort, token: 'T'),
      isFalse,
    );
  });
}
