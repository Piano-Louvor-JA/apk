import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_models.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_sender.dart';

/// Lista de palcos conectados (módulo Palco) e comandos para um palco só.
void main() {
  late PalcoSender sender;
  final sockets = <WebSocket>[];

  setUp(() async {
    sender = PalcoSender(httpPortFixed: 0, wsPortFixed: 0);
    await sender.start();
  });

  tearDown(() async {
    for (final s in sockets) {
      await s.close();
    }
    sockets.clear();
    PalcoSender.mutedTvs.clear();
    await sender.stop();
  });

  /// Receiver de verdade: conecta no WS e guarda o que chega (menos as
  /// mensagens que o sender manda a todo mundo na conexão).
  Future<(WebSocket, List<Map<String, dynamic>>)> receiver({
    String ua = 'Mozilla/5.0 (Web0S; Linux/SmartTV)',
    Map<String, dynamic>? hello,
  }) async {
    final ws = await WebSocket.connect(
      'ws://127.0.0.1:${sender.effectiveWsPort}/palco',
      headers: {'User-Agent': ua},
    );
    sockets.add(ws);
    final got = <Map<String, dynamic>>[];
    ws.listen((d) {
      final m = jsonDecode(d as String) as Map<String, dynamic>;
      if (m['type'] != 'youare' && m['type'] != 'idleStyle') got.add(m);
    });
    if (hello != null) ws.add(jsonEncode({'v': 2, 'type': 'hello', ...hello}));
    await _settle();
    return (ws, got);
  }

  test(
    'plataforma vem do User-Agent e o hello completa nome e versão',
    () async {
      await receiver(ua: 'Mozilla/5.0 (Linux; Android 12) Chrome');
      await receiver(
        hello: {
          'role': 'tv',
          'platform': 'webos',
          'id': 'abc',
          'version': '0.3.1',
          'name': 'TV do púlpito',
        },
      );

      final byPlatform = {for (final c in sender.clients) c.platform: c};
      expect(byPlatform['androidtv']!.name, 'Android TV');
      expect(byPlatform['androidtv']!.version, isNull);
      expect(byPlatform['webos']!.name, 'TV do púlpito');
      expect(byPlatform['webos']!.version, '0.3.1');
      expect(byPlatform['webos']!.id, 'abc');
    },
  );

  test('a mesma TV reconectando substitui a conexão antiga', () async {
    final hello = {'role': 'tv', 'platform': 'webos', 'id': 'x1'};
    await receiver(hello: hello);
    await receiver(hello: hello);
    expect(sender.clients, hasLength(1));
    expect(sender.clientCount, 1);
  });

  test('ids diferentes atrás do mesmo IP são TVs diferentes', () async {
    await receiver(hello: {'role': 'tv', 'platform': 'webos', 'id': 'p1'});
    await receiver(hello: {'role': 'tv', 'platform': 'webos', 'id': 'p2'});
    await _settle();
    expect(sender.clients.map((c) => c.id), unorderedEquals(['p1', 'p2']));
    expect(sender.clientCount, 2);
  });

  test('sem id, mesmo IP e plataforma é a mesma TV', () async {
    await receiver(hello: {'role': 'tv', 'platform': 'tizen'});
    await receiver(hello: {'role': 'tv', 'platform': 'tizen'});
    expect(sender.clients, hasLength(1));
  });

  test('sendToClient chega só no palco escolhido', () async {
    final (_, gotA) = await receiver(
      hello: {'role': 'tv', 'platform': 'webos', 'id': 'a'},
    );
    final (_, gotB) = await receiver(
      ua: 'Mozilla/5.0 (SMART-TV; Tizen 6.0)',
      hello: {'role': 'tv', 'platform': 'tizen', 'id': 'b'},
    );

    final a = sender.clients.firstWhere((c) => c.id == 'a');
    expect(sender.sendToClient(a, _reload), isTrue);
    await _settle();

    expect(gotA.map((m) => m['type']), ['reload']);
    expect(gotB, isEmpty);
  });

  test('renameClient manda o nome para a TV e já atualiza a lista', () async {
    final (_, got) = await receiver(
      hello: {'role': 'tv', 'platform': 'webos', 'id': 'r', 'version': '0.3.1'},
    );
    final c = sender.clients.single;

    expect(sender.renameClient(c, '  TV da entrada  '), isTrue);
    await _settle();

    expect(got.single, containsPair('type', 'rename'));
    expect(got.single, containsPair('name', 'TV da entrada'));
    final now = sender.clients.single;
    expect(now.name, 'TV da entrada');
    expect(now.version, '0.3.1');
    expect(now.id, 'r');
  });

  test('renameClient com nome vazio não manda nada', () async {
    final (_, got) = await receiver(
      hello: {'role': 'tv', 'platform': 'webos', 'id': 'e'},
    );
    expect(sender.renameClient(sender.clients.single, '   '), isFalse);
    await _settle();
    expect(got, isEmpty);
  });

  test('cópia antiga do palco (antes do hello) ainda acha o socket', () async {
    final (ws, got) = await receiver();
    final before = sender.clients.single; // ainda sem id
    ws.add(jsonEncode({'v': 2, 'type': 'hello', 'role': 'tv', 'id': 'z'}));
    await _settle();
    expect(identical(before, sender.clients.single), isFalse);

    expect(sender.sendToClient(before, _reload), isTrue);
    await _settle();
    expect(got.map((m) => m['type']), ['reload']);
  });

  test('palco que saiu: sendToClient devolve false', () async {
    final (ws, _) = await receiver(
      hello: {'role': 'tv', 'platform': 'webos', 'id': 'g'},
    );
    final c = sender.clients.single;
    await ws.close();
    sockets.remove(ws);
    await _settle();

    expect(sender.clients, isEmpty);
    expect(sender.sendToClient(c, _reload), isFalse);
  });

  test('TV desmarcada vai para a espera e não recebe a transmissão', () async {
    final (_, gotA) = await receiver(
      hello: {'role': 'tv', 'platform': 'webos', 'id': 'ma'},
    );
    final (_, gotB) = await receiver(
      hello: {'role': 'tv', 'platform': 'webos', 'id': 'mb'},
    );
    final a = sender.clients.firstWhere((c) => c.id == 'ma');

    PalcoSender.mutedTvs.add(PalcoSender.muteKey(a));
    sender.applyMute(a);
    sender.send(const PalcoMessage(type: 'projection', fields: {'t': 1}));
    sender.sendToRole('tv', const PalcoMessage(type: 'timer'));
    await _settle();

    expect(gotA.map((m) => m['type']), ['idle']);
    expect(gotB.map((m) => m['type']), ['projection', 'timer']);
  });

  test('TV remarcada recebe a última cena na hora', () async {
    final (_, got) = await receiver(
      hello: {'role': 'tv', 'platform': 'webos', 'id': 'mc'},
    );
    final c = sender.clients.single;
    PalcoSender.mutedTvs.add(PalcoSender.muteKey(c));
    sender.send(const PalcoMessage(type: 'projection', fields: {'t': 2}));
    sender.send(const PalcoMessage(type: 'timer'));

    PalcoSender.mutedTvs.remove(PalcoSender.muteKey(c));
    sender.applyMute(c);
    await _settle();

    expect(got, hasLength(1));
    expect(got.single, containsPair('type', 'projection'));
    expect(got.single, containsPair('t', 2));
  });

  test('muteKey usa o id e, sem id, IP + plataforma', () {
    final base = PalcoClientInfo(
      ip: '10.0.0.5',
      platform: 'tizen',
      name: 'x',
      connectedAt: DateTime(2026),
    );
    expect(PalcoSender.muteKey(base), '10.0.0.5|tizen');
    expect(PalcoSender.muteKey(base.withHello({'id': 'z9'})), 'z9');
  });
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 80));

const _reload = PalcoMessage(type: 'reload');
