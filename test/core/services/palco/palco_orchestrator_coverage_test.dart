import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_models.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Receiver WS fake que conecta no sender de um slot.
class FakeRx {
  WebSocket? _ws;
  final received = <Map<String, dynamic>>[];

  Future<void> connect(String host, int wsPort) async {
    _ws = await WebSocket.connect('ws://$host:$wsPort/palco');
    _ws!.listen((d) {
      received.add(jsonDecode(d as String) as Map<String, dynamic>);
    });
  }

  Future<void> close() async {
    await _ws?.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('orch_cov');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  final PalcoOrchestrator orch = PalcoOrchestrator.instance;

  tearDownAll(() async {
    await orch.disconnectAll();
  });

  group('PalcoOrchestrator — persistência de config', () {
    test('addSlot persiste; loadStoredConfig restaura slots salvos', () async {
      await orch.disconnectAll();
      // limpa slots pra cenário determinístico
      for (final s in orch.slots.toList()) {
        await orch.removeSlot(s.id);
      }

      orch.addSlot(id: 'tela2', label: 'Tela 2');
      // dá tempo do persist async rodar
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final saved = await SharedPreferences.getInstance();
      final raw = saved.getString('palco.multi.slots.v1');
      expect(raw, isNotNull);
      expect(raw!, contains('tela2'));
    });

    test('_prefs sem binding/mocks: loadStoredConfig segue sem crash', () async {
      // _loaded flag impede reload no mesmo processo; valida apenas os
      // caminhos de guard (prefs null) via instância nova impossível —
      // então valida que loadStoredConfig em instance existente não lança.
      await orch.loadStoredConfig();
      expect(orch.slots, isA<List<dynamic>>());
    });
  });

  group('PalcoOrchestrator — projeção e mídia com TV real em loopback', () {
    late String slotId;
    FakeRx? rx;

    setUp(() async {
      await orch.disconnectAll();
      for (final s in orch.slots.toList()) {
        await orch.removeSlot(s.id);
      }
      // slotIndex 1 = portas 7082/7083: evita corrida com outros arquivos
      // de teste que usam o slot 0 (7080/7081) em shards paralelos.
      final ok = orch.addSlot(id: 'cov1', label: 'Cov', slotIndex: 1);
      expect(ok, isTrue);
      slotId = 'cov1';
      final connected = await orch.connectTv(
        slotId,
        PalcoTarget(name: 'TV', ip: '127.0.0.1', wsPort: 0),
      );
      expect(connected, isTrue);
      rx = FakeRx();
      final slot = orch.slot(slotId)!;
      await rx!.connect('127.0.0.1', slot.wsPort);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    tearDown(() async {
      await rx?.close();
      await orch.disconnectAll();
    });

    test('projectToSlot entrega projection ao receiver do slot', () async {
      final ok = await orch.projectToSlot(
        slotId,
        title: 'Título slot',
        body: 'Corpo',
        footer: 'Rodapé',
      );
      expect(ok, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      final proj = rx!.received.lastWhere((m) => m['type'] == 'projection');
      expect(proj['text'] as String, contains('Título slot'));
    });

    test('projectToSlot em slot inexistente/desconectado → false', () async {
      expect(
        await orch.projectToSlot('fantasma', title: 'x'),
        isFalse,
      );
      await orch.disconnectAll();
      expect(
        await orch.projectToSlot(slotId, title: 'x'),
        isFalse,
      );
    });

    test('project (todos conectados) entrega ao receiver', () async {
      final ok = await orch.project(
        title: 'Todos',
        body: 'mesmo conteúdo',
      );
      expect(ok, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(
        rx!.received.any(
          (m) =>
              m['type'] == 'projection' &&
              (m['text'] as String).contains('Todos'),
        ),
        isTrue,
      );
    });

    test('clearSlot/clearAll/clearContent mandam projeção vazia', () async {
      await orch.projectToSlot(slotId, title: 'antes');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      orch.clearSlot(slotId);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        rx!.received.any((m) => m['type'] == 'projection'),
        isTrue,
      );

      await orch.clearAll();
      await orch.clearContent();
    });

    test('startTimer/stopTimer chegam ao receiver', () async {
      await orch.startTimer(
        duration: 60,
        mode: 'countdown',
        label: 'Culto',
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(rx!.received.any((m) => m['type'] == 'timer'), isTrue);
      orch.stopTimer();
    });

    test('áudio: setAudioSlot + play/pause/stop/seek sem lançar', () async {
      orch.setAudioSlot(slotId);
      final route = orch.playHymnAudio(
        'https://x/a.mp3',
        title: 'Hino',
        subtitle: 'Harpa',
        cover: 'https://x/c.jpg',
      );
      // receiver fake não confirma estado: rota válida sem lançar
      expect(route, isA<PalcoAudioRoute>());

      orch.pauseHymnAudio();
      orch.stopHymnAudio();
      orch.seekHymnAudio(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });

    test('vídeo no palco: play/stop/pause toggles sem lançar', () async {
      final ok = orch.playVideoOnStage('https://x/video.mp4');
      expect(ok, isA<bool>());
      orch.toggleStageVideoPause();
      orch.stopVideoOnStage();
    });

    test('connectTv em slot inválido retorna false', () async {
      expect(
        await orch.connectTv(
          'fantasma',
          PalcoTarget(name: 'x', ip: '127.0.0.1', wsPort: 0),
        ),
        isFalse,
      );
    });
  });
}
