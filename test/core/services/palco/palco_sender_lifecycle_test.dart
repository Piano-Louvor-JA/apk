import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_models.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_sender.dart';

/// Ramos restantes do sender: ciclo start/stop, serveMedia HTTP, clearMedia,
/// send sem clientes, roles notify e portas efetivas.
void main() {
  late PalcoSender sender;

  setUp(() {
    sender = PalcoSender(httpPortFixed: 0, wsPortFixed: 0);
  });

  tearDown(() async {
    await sender.stop();
  });

  test('start sobe HTTP+WS e portas efetivas mudam', () async {
    final base = await sender.start();
    expect(base, isNotNull);
    expect(sender.isRunning, isTrue);
    expect(sender.effectiveHttpPort, greaterThan(0));
    expect(sender.effectiveWsPort, greaterThan(0));
  });

  test('stop encerra e isRunning false; duplo stop idempotente', () async {
    await sender.start();
    await sender.stop();
    expect(sender.isRunning, isFalse);

    await sender.stop(); // segunda chamada não lança
  });

  test('serveMedia + GET baixa os bytes; clearMedia volta 404', () async {
    await sender.start();

    sender.serveMedia('slide.png', [1, 2, 3, 4, 5]);
    final client = HttpClient();
    final req = await client.getUrl(
      Uri.parse('http://127.0.0.1:${sender.effectiveHttpPort}/media/slide.png'),
    );
    final res = await req.close();
    expect(res.statusCode, 200);
    final body = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    expect(body, [1, 2, 3, 4, 5]);

    sender.clearMedia();
    final req2 = await client.getUrl(
      Uri.parse('http://127.0.0.1:${sender.effectiveHttpPort}/media/slide.png'),
    );
    final res2 = await req2.close();
    expect(res2.statusCode, 404);
    client.close();
  });

  test('send sem clientes conectados é no-op silencioso', () async {
    await sender.start();
    sender.send(
      const PalcoMessage(type: 'projection', fields: {'slide': 1}),
    );
  });

  test('notifyRoleChange dispara rolesChanged', () async {
    var fired = 0;
    final sub = sender.rolesChanged.listen((_) => fired++);
    sender.notifyRoleChange();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fired, greaterThanOrEqualTo(1));
    await sub.cancel();
  });

  test('receiver WS conecta, hello define role e eventos fluem', () async {
    await sender.start();

    final events = <PalcoMessage>[];
    final sub = sender.events.listen(events.add);

    final ws = await WebSocket.connect(
      'ws://127.0.0.1:${sender.effectiveWsPort}/palco',
    );
    ws.add(jsonEncode({'v': 2, 'type': 'hello', 'role': 'tv'}));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(sender.clientCount, 1);
    expect(sender.roleCounts['tv'], 1);

    // evento receiver→sender
    ws.add(jsonEncode({'v': 2, 'type': 'remote-key', 'key': 'left'}));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(events.map((e) => e.type), contains('remote-key'));

    // send sender→receiver chega
    final received = <String>[];
    ws.listen((d) => received.add(d as String));
    sender.send(
      const PalcoMessage(type: 'projection', fields: {'slide': 2}),
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    // youare (handshake) + projection — a projection é a última.
    expect(received, isNotEmpty);
    expect(received.last, contains('projection'));

    await ws.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(sender.clientCount, 0);
    await sub.cancel();
  });

  test('receiver sem hello: conecta mas nao registra role', () async {
    await sender.start();
    final ws = await WebSocket.connect(
      'ws://127.0.0.1:${sender.effectiveWsPort}/palco',
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(sender.clientCount, 1);
    expect(sender.roleCounts, isEmpty); // sem hello = sem role
    await ws.close();
  });
}
