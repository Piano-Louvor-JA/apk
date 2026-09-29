library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_models.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_sender.dart';

void main() {
  late PalcoSender sender;

  setUp(() {
    sender = PalcoSender(httpPortFixed: 0, wsPortFixed: 0);
  });

  tearDown(() async {
    await sender.stop();
  });

  Future<(String, WebSocket)> connectClient() async {
    final base = await sender.start();
    expect(base, isNotNull);
    final ws = await WebSocket.connect(
      'ws://127.0.0.1:${sender.effectiveWsPort}/palco',
    );
    // hello: declara role desktop
    ws.add(
      jsonEncode(
        const PalcoMessage(type: 'hello', fields: {'role': 'desktop'}).toJson(),
      ),
    );
    await pumpEventQueue();
    return (base!, ws);
  }

  test('remote.command serializa command, id e value', () {
    final m = PalcoMessage.remoteCommand('volume', id: 'rc_1', value: 0.5);
    final json = m.toJson();
    expect(json['type'], 'remote.command');
    expect(json['command'], 'volume');
    expect(json['id'], 'rc_1');
    expect(json['value'], 0.5);
  });

  test('accessors de ack e hello', () {
    final ack = const PalcoMessage(
      type: 'remote.ack',
      fields: {
        'id': 'rc_1',
        'ok': true,
        'state': {'playing': false},
      },
    );
    expect(ack.remoteAckId, 'rc_1');
    expect(ack.remoteAckOk, isTrue);
    expect(ack.remoteState['playing'], isFalse);

    final hello = const PalcoMessage(
      type: 'hello',
      fields: {'role': 'desktop'},
    );
    expect(hello.helloRole, 'desktop');
  });

  test('hello registra role e sendToRole entrega só ao role alvo', () async {
    final (_, ws) = await connectClient();
    await pumpEventQueue();

    expect(sender.roleCounts['desktop'], 1);

    final delivered = sender.sendToRole(
      'desktop',
      PalcoMessage.remoteCommand('pause', id: 'rc_2'),
    );
    expect(delivered, isTrue);

    // Coleta mensagens em buffer até chegar o remote.command
    // (você/youare podem vir antes).
    final received = <Map<String, dynamic>>[];
    final sub = ws.listen((d) {
      final j = jsonDecode(d as String) as Map<String, dynamic>;
      if (j['type'] == 'remote.command') received.add(j);
    });
    final cmd = await () async {
      for (var i = 0; i < 40; i++) {
        if (received.isNotEmpty) return received.first;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      return null;
    }();
    await sub.cancel();
    expect(cmd, isNotNull);
    expect(cmd!['command'], 'pause');
    expect(cmd['id'], 'rc_2');

    // sem receiver web conectado
    expect(
      sender.sendToRole('web', PalcoMessage.remoteCommand('pause')),
      isFalse,
    );
    await ws.close();
  });

  test('roleCounts volta a zero quando receiver sai', () async {
    final (_, ws) = await connectClient();
    await pumpEventQueue();
    expect(sender.roleCounts['desktop'], 1);
    await ws.close();
    await pumpEventQueue();
    expect(sender.roleCounts['desktop'], isNull);
  });
}
