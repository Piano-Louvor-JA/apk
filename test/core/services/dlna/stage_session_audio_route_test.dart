library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';

/// F3.2: roteamento de áudio no StageSession (modo local/tv/mirror).
///
/// Usa o PalcoSender real em portas efêmeras + FakeReceiver WS (mesmo
/// padrão do palco_controller_test.dart), validando que:
/// - local (default): NÃO envia áudio ao palco
/// - tv/mirror: envia play/pause/stop ao receiver
/// - palco desligado: playHymnAudio degrada para local sem erro
void main() {
  Future<(StageSession, StreamIterator<Map<String, dynamic>>, FakeReceiverRx)>
  setUpPalco() async {
    final stage = StageSession.instance;
    final ok = await stage.turnOnPalco(
      PalcoTarget(name: 'TV teste', ip: '127.0.0.1', wsPort: 0),
    );
    // turnOnPalco usa PalcoController com portas FIXAS — em teste precisamos
    // de efêmeras. Como StageSession cria o controller interno, montamos o
    // cenário via o controller exposto (palco) quando disponível.
    expect(ok, isTrue, reason: 'sender deve subir em loopback');
    final rx = FakeReceiverRx();
    await rx.connect('127.0.0.1', stage.palco!.wsPort);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return (stage, await _iter(rx.messages.stream), rx);
  }

  test('modo local (default): playHymnAudio não envia nada ao palco', () async {
    final (stage, iter, rx) = await setUpPalco();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    final route = stage.playHymnAudio('https://x/a.mp3', title: 'Hino');
    expect(route, PalcoAudioRoute.local);

    // nenhuma mensagem de audio nos próximos 300ms
    var sawAudio = false;
    final timer = Future<void>.delayed(const Duration(milliseconds: 300), () {
      for (final m in rx.received) {
        if (m['type'] == 'audio') sawAudio = true;
      }
    });
    await timer;
    expect(sawAudio, isFalse, reason: 'modo local não roteia áudio à TV');
  });

  test('modo tv: play/pause/stop chegam ao receiver', () async {
    final (stage, iter, rx) = await setUpPalco();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    stage.audioRoute = PalcoAudioRoute.tv;
    final route = stage.playHymnAudio(
      'https://x/a.mp3',
      title: 'Hino',
      subtitle: 'Harpa',
      cover: 'https://x/c.jpg',
    );
    expect(route, PalcoAudioRoute.tv);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final play = rx.received.lastWhere((m) => m['type'] == 'audio');
    expect(play['action'], 'play');
    expect(play['title'], 'Hino');

    stage.pauseHymnAudio();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final pause = rx.received.last;
    expect(pause['type'], 'audio');
    expect(pause['action'], 'pause');

    stage.stopHymnAudio();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(rx.received.last['action'], 'stop');
  });

  test('palco desligado: playHymnAudio degrada para local', () async {
    final stage = StageSession.instance;
    expect(stage.isOn, isFalse);
    final route = stage.playHymnAudio('https://x/a.mp3');
    expect(route, PalcoAudioRoute.local);
    // pause/stop não lançam com palco desligado
    stage.pauseHymnAudio();
    stage.stopHymnAudio();
  });
}

/// Receiver fake com stream de mensagens decodificadas.
class FakeReceiverRx {
  WebSocket? _ws;
  final List<Map<String, dynamic>> received = [];
  final messages = StreamController<Map<String, dynamic>>.broadcast();

  Future<void> connect(String host, int wsPort) async {
    _ws = await WebSocket.connect('ws://$host:$wsPort/palco');
    _ws!.listen((d) {
      final m = jsonDecode(d as String) as Map<String, dynamic>;
      received.add(m);
      messages.add(m);
    });
  }

  Future<void> close() async {
    await messages.close();
    await _ws?.close();
  }
}

Future<StreamIterator<Map<String, dynamic>>> _iter(
  Stream<Map<String, dynamic>> s,
) async {
  final it = StreamIterator<Map<String, dynamic>>(s);
  return it;
}
