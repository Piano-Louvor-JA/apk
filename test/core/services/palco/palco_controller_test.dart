import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_sender.dart';

/// Receiver fake: WS client que se conecta ao sender como a TV faria.
class FakeReceiver {
  WebSocket? _ws;
  final List<Map<String, dynamic>> received = [];
  final _connected = Completer<void>();

  Future<void> get connected => _connected.future;

  Future<void> connect(String host, int wsPort) async {
    _ws = await WebSocket.connect('ws://$host:$wsPort/palco');
    _ws!.listen((d) => received.add(jsonDecode(d as String)));
    _connected.complete();
  }

  void sendEvent(Map<String, dynamic> msg) => _ws?.add(jsonEncode(msg));

  Future<void> close() async => _ws?.close();
}

void main() {
  // Bind em 0.0.0.0 exige rede; em CI usa loopback — PalcoSender usa
  // anyIPv4, que cobre 127.0.0.1. Testes rodam com localhost.
  final bindings = <String>{};

  tearDown(() async {
    bindings.clear();
  });

  test('PalcoController start + receiver conecta + projection chega', () async {
    final ctrl = PalcoController(
      sender: PalcoSender(httpPortFixed: 0, wsPortFixed: 0),
    );
    final ok = await ctrl.connect(
      const PalcoTarget(name: 'TV fake', ip: '127.0.0.1'),
    );
    expect(ok, isTrue, reason: 'sender deve subir');
    expect(ctrl.httpBase, isNotNull);
    bindings.add('ctrl');

    final rx = FakeReceiver();
    await rx.connect('127.0.0.1', ctrl.wsPort);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(ctrl.clientCount, 1);

    ctrl.project(text: 'O nosso sol<br>Veio iluminar', footer: 'Hino 275');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(rx.received, isNotEmpty);
    final msg = rx.received.last;
    expect(msg['type'], 'projection');
    expect(msg['v'], 2);
    expect(msg['text'], contains('<br>'));
    expect(msg['footer'], 'Hino 275');

    await rx.close();
    await ctrl.disconnect();
  });

  test('audio é envelopado no proxy do sender', () async {
    final ctrl = PalcoController(
      sender: PalcoSender(httpPortFixed: 0, wsPortFixed: 0),
    );
    await ctrl.connect(const PalcoTarget(name: 'TV', ip: '127.0.0.1'));

    final rx = FakeReceiver();
    await rx.connect('127.0.0.1', ctrl.wsPort);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    ctrl.playAudio(
      'https://api.louvorja.com.br/file/musics/pt/a.mp3',
      title: 'Hino',
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final msg = rx.received.last;
    expect(msg['type'], 'audio');
    // URL deve estar envelopada no proxy local, não crua
    expect(msg['url'], startsWith('http://'));
    expect(msg['url'], contains('/proxy?url='));
    expect(msg['title'], 'Hino');

    await rx.close();
    await ctrl.disconnect();
  });

  test(
    'eventos receiver→sender (unlocked/remote-key) chegam no stream',
    () async {
      final ctrl = PalcoController(
        sender: PalcoSender(httpPortFixed: 0, wsPortFixed: 0),
      );
      await ctrl.connect(const PalcoTarget(name: 'TV', ip: '127.0.0.1'));

      final rx = FakeReceiver();
      await rx.connect('127.0.0.1', ctrl.wsPort);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final eventos = <String>[];
      final sub = ctrl.events.listen((m) => eventos.add(m.type));

      rx.sendEvent({'v': 2, 'type': 'unlocked'});
      rx.sendEvent({'v': 2, 'type': 'remote-key', 'key': 'next'});
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(eventos, containsAll(['unlocked', 'remote-key']));

      await sub.cancel();
      await rx.close();
      await ctrl.disconnect();
    },
  );

  test('timer e idle', () async {
    final ctrl = PalcoController(
      sender: PalcoSender(httpPortFixed: 0, wsPortFixed: 0),
    );
    await ctrl.connect(const PalcoTarget(name: 'TV', ip: '127.0.0.1'));

    final rx = FakeReceiver();
    await rx.connect('127.0.0.1', ctrl.wsPort);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    ctrl.startTimer(duration: 300, label: 'Sermão');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(rx.received.last['type'], 'timer');
    expect(rx.received.last['duration'], 300);

    ctrl.projectIdle();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(rx.received.last['type'], 'idle');

    await rx.close();
    await ctrl.disconnect();
  });

  test('routing: primitivas de audio (play/pause/stop) espelháveis', () async {
    final ctrl = PalcoController(
      sender: PalcoSender(httpPortFixed: 0, wsPortFixed: 0),
    );
    await ctrl.connect(const PalcoTarget(name: 'TV', ip: '127.0.0.1'));
    final rx = FakeReceiver();
    await rx.connect('127.0.0.1', ctrl.wsPort);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    ctrl.playAudio(
      'https://api.louvorja.com.br/file/musics/pt/a.mp3',
      title: 'Hino 1',
      subtitle: 'Harpa',
      cover: 'https://x/c.jpg',
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(rx.received.last['type'], 'audio');
    expect(rx.received.last['action'], 'play');
    expect(rx.received.last['subtitle'], 'Harpa');

    ctrl.pauseAudio();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(rx.received.last['type'], 'audio');
    expect(rx.received.last['action'], 'pause');

    ctrl.stopAudio();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(rx.received.last['action'], 'stop');

    await rx.close();
    await ctrl.disconnect();
  });

  test(
    'projection com background externo passa URL crua (receiver resolve proxy)',
    () async {
      final ctrl = PalcoController(
        sender: PalcoSender(httpPortFixed: 0, wsPortFixed: 0),
      );
      await ctrl.connect(const PalcoTarget(name: 'TV', ip: '127.0.0.1'));
      final rx = FakeReceiver();
      await rx.connect('127.0.0.1', ctrl.wsPort);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      ctrl.project(
        text: 'estrofe',
        footer: 'Hino 10',
        background: 'https://api.louvorja.com.br/file/images/bg1.jpg',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final msg = rx.received.last;
      expect(msg['type'], 'projection');
      expect(
        msg['background'],
        'https://api.louvorja.com.br/file/images/bg1.jpg',
      );

      await rx.close();
      await ctrl.disconnect();
    },
  );
}
