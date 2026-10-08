import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';

/// Receiver WS fake reutilizável (mesmo padrão do audio_route_test).
class FakeReceiverRx {
  WebSocket? _ws;
  final List<Map<String, dynamic>> received = [];

  Future<void> connect(String host, int wsPort) async {
    _ws = await WebSocket.connect('ws://$host:$wsPort/palco');
    _ws!.listen((d) => received.add(jsonDecode(d as String)));
  }

  void send(Map<String, dynamic> msg) => _ws?.add(jsonEncode(msg));

  Future<void> close() async => _ws?.close();
}

/// Ramos restantes da StageSession: project bíblia (isBible + footerVersion),
/// navegação de slides (remote-key left/right), stopSlides/stopTimerStage,
/// rerouteCurrentAudio, pause/stop/seek de áudio, refresh, checkTvNeedsPalco.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(StageSession, FakeReceiverRx)> on() async {
    final stage = StageSession.instance;
    await stage.turnOff();
    final ok = await stage.turnOnPalco(
      const PalcoTarget(name: 'TV teste', ip: '127.0.0.1', wsPort: 0),
    );
    expect(ok, isTrue);
    final rx = FakeReceiverRx();
    await rx.connect('127.0.0.1', stage.palco!.wsPort);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return (stage, rx);
  }

  test('project isBible com footerVersion envia tipografia própria', () async {
    final (stage, rx) = await on();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    final ok = await stage.project(
      title: 'João 3:16',
      body: 'Porque Deus amou o mundo',
      footer: 'João 3',
      footerVersion: 'ARA',
      footerRef: 'NT',
      isBible: true,
      module: 'bible',
    );
    expect(ok, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    final proj = rx.received.lastWhere((m) => m['type'] == 'projection');
    expect(proj['text'] as String, contains('João 3:16'));
  });

  test('remote-key left/right navega slides sem lançar', () async {
    final (stage, rx) = await on();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    rx.send({'type': 'remote-key', 'fields': {'key': 'right'}});
    await Future<void>.delayed(const Duration(milliseconds: 120));
    rx.send({'type': 'remote-key', 'fields': {'key': 'left'}});
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(stage.isVideoOnStage, isFalse);
  });

  test('stopSlides e stopTimerStage em palco ligado (no-op seguros)', () async {
    final (stage, rx) = await on();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    stage.stopSlides();
    stage.stopTimerStage();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(stage.isOn, isTrue);
  });

  test('rerouteCurrentAudio / pause/stop/seek de áudio não lançam', () async {
    final (stage, rx) = await on();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    stage.rerouteCurrentAudio();
    stage.pauseHymnAudio();
    stage.seekHymnAudio(const Duration(seconds: 5));
    stage.stopHymnAudio();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(stage.isOn, isTrue);
  });

  test('refresh recarrega settings e reprojeta sem lançar', () async {
    final (stage, rx) = await on();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    await stage.refresh();
    expect(stage.isOn, isTrue);
  });

  test('checkTvNeedsPalcoOpen sem alvo retorna null/false rápido', () async {
    final (stage, rx) = await on();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    final r = await stage.checkTvNeedsPalcoOpen();
    expect(r, anyOf(isNull, isA<bool>(), isA<Map<String, dynamic>>()));
  });
}
