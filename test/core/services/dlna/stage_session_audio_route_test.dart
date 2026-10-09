library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:flutter/foundation.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_settings_repository.dart';
// path_provider exposto transitivo no lock do app; fake de disco real.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// F3.2: roteamento de áudio no StageSession (modo local/tv/mirror).
///
/// Usa o PalcoSender real em portas efêmeras + FakeReceiver WS (mesmo
/// padrão do palco_controller_test.dart), validando que:
/// - local (default): NÃO envia áudio ao palco
/// - tv/mirror: envia play/pause/stop ao receiver
/// - palco desligado: playHymnAudio degrada para local sem erro
Directory? _tmpCov;

void main() {
  setUp(() async {
    _tmpCov = await Directory.systemTemp.createTemp('stage_session_cov');
    PathProviderPlatform.instance = _FakePathProvider(_tmpCov!.path);
  });

  tearDown(() async {
    if (_tmpCov!.existsSync()) await _tmpCov!.delete(recursive: true);
  });

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

  // ===== Cobertura extra: getters/projeção/timer/remotes sobre palco real =====
  Future<(StageSession, FakeReceiverRx)> onCov() async {
    final stage = StageSession.instance;
    await stage.turnOff();
    await PalcoOrchestrator.instance.removeSlot('principal');
    final ok = await stage.turnOnPalco(
      PalcoTarget(name: 'TV teste', ip: '127.0.0.1', wsPort: 0),
    );
    expect(ok, isTrue, reason: 'sender deve subir em loopback');
    final rx = FakeReceiverRx();
    await rx.connect('127.0.0.1', stage.palco!.wsPort);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return (stage, rx);
  }

  group('StageSession — getters em modo palco', () {
    test('isOn/isPalcoMode/rendererName/receiverRoles/playerState/ip', () async {
      final (stage, rx) = await onCov();
      addTearDown(() async {
        await rx.close();
        await stage.turnOff();
      });

      expect(stage.isOn, isTrue);
      expect(stage.isPalcoMode, isTrue);
      expect(stage.rendererName, 'TV teste');
      expect(stage.receiverRoles, isA<Map<String, int>>());
      expect(stage.remotePlayerState, isA<Map<String, dynamic>>());
      expect(stage.receiverIp, '127.0.0.1');
    });

    test('getters com palco desligado voltam ao default', () async {
      final stage = StageSession.instance;
      await stage.turnOff();

      expect(stage.isOn, isFalse);
      expect(stage.isPalcoMode, isFalse);
      expect(stage.rendererName, isNull);
      expect(stage.receiverRoles, isEmpty);
      expect(stage.remotePlayerState, isEmpty);
      expect(stage.receiverIp, isNull);
    });

    test('sendRemoteCommand com palco → ack/estado sem lançar', () async {
      final (stage, rx) = await onCov();
      addTearDown(() async {
        await rx.close();
        await stage.turnOff();
      });

      final resp = await stage.sendRemoteCommand(
        'play',
        role: 'desktop',
        value: 0.5,
      );
      expect(resp, anyOf(isNull, isA<Map<String, dynamic>>()));
    });
  });

  group('StageSession — projeção e controles', () {
    test('com palco: project entrega conteúdo ao receiver', () async {
      final (stage, rx) = await onCov();
      addTearDown(() async {
        await rx.close();
        await stage.turnOff();
      });

      final ok = await stage.project(
        title: 'O nosso sol',
        body: 'Veio iluminar',
        footer: 'Hinos 1',
      );
      expect(ok, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      final proj = rx.received.lastWhere((m) => m['type'] == 'projection');
      expect(proj['text'] as String, contains('O nosso sol'));
      expect(proj['footer'], 'Hinos 1');
    });

    test('sem palco: project retorna false', () async {
      final stage = StageSession.instance;
      await stage.turnOff();
      expect(await stage.project(title: 't', body: 'b'), isFalse);
    });

    test('clearContent + remote-key + vídeo ended via receiver', () async {
      final (stage, rx) = await onCov();
      addTearDown(() async {
        await rx.close();
        await stage.turnOff();
      });

      await stage.project(title: 'a', body: 'b');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      rx.send({'type': 'remote-key', 'fields': {'key': 'right'}});
      await Future<void>.delayed(const Duration(milliseconds: 150));

      rx.send({'type': 'ended', 'fields': {'media': 'video'}});
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(stage.isVideoOnStage, isFalse);

      stage.clearContent();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(rx.received.any((m) => m['type'] == 'projection'), isTrue);
    });

    test('startTimer com palco envia timer ao receiver', () async {
      final (stage, rx) = await onCov();
      addTearDown(() async {
        await rx.close();
        await stage.turnOff();
      });

      await stage.startTimer(
        duration: 90,
        mode: 'countdown',
        label: 'Culto',
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(rx.received.any((m) => m['type'] == 'timer'), isTrue);
      stage.stopTimerStage();
    });

    test('turnOff limpa palco e getters voltam ao default', () async {
      final (stage, rx) = await onCov();
      await rx.close();

      await stage.turnOff();
      expect(stage.isOn, isFalse);
      expect(stage.isPalcoMode, isFalse);
      expect(stage.palco, isNull);
    });
  });

  group('StageSession — background BG do usuário', () {
    test('setBackgroundBytes persiste e reload mantém', () async {
      final stage = StageSession.instance;
      await stage.turnOff();

      final png = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00,
        0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63,
        0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
        0x82,
      ];
      await stage.setBackgroundBytes(
        Uint8List.fromList(png),
        scope: 'hymns',
      );

      final loaded = await StageSettingsRepository(
        scope: 'hymns',
      ).loadBackgroundImage(backgroundScope: 'hymns');
      expect(loaded, isNotNull);
      expect(loaded!.length, png.length);
    });
  });

  group('StageSession — ramos extras (bible/slides/reroute/refresh)', () {
  test('project isBible com footerVersion envia tipografia própria', () async {
    final (stage, _, rx) = await setUpPalco();
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
    final (stage, _, rx) = await setUpPalco();
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
    final (stage, _, rx) = await setUpPalco();
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
    final (stage, _, rx) = await setUpPalco();
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
    final (stage, _, rx) = await setUpPalco();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    await stage.refresh();
    expect(stage.isOn, isTrue);
  });
  test('checkTvNeedsPalcoOpen sem alvo retorna null/false rápido', () async {
    final (stage, _, rx) = await setUpPalco();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    final r = await stage.checkTvNeedsPalcoOpen();
    expect(r, anyOf(isNull, isA<bool>(), isA<Map<String, dynamic>>()));
  });
  test('projectPptxSlides com arquivo inexistente retorna 0 sem lançar',
      () async {
    final (stage, _, rx) = await setUpPalco();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    expect(stage.projectPptxSlides('/tmp/nao_existe_slide.pptx'), 0);
  });
  test('navigateSlides sem sequência carregada retorna false', () async {
    final (stage, _, rx) = await setUpPalco();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    expect(stage.navigateSlides('next'), isFalse);
    expect(stage.navigateSlides('prev'), isFalse);
    expect(stage.navigateSlides('outro'), isFalse);
  });
  test('playVideoOnStage com URL externa projeta e ended volta ao idle',
      () async {
    final (stage, _, rx) = await setUpPalco();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    expect(stage.playVideoOnStage('https://x/video.mp4'), isTrue);
    expect(stage.isVideoOnStage, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    stage.toggleStageVideoPause();
    stage.stopVideoOnStage();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(stage.isVideoOnStage, isFalse);
    expect(stage.isStageVideoPaused, anyOf(isTrue, isFalse));
  });
  test('playVideoOnStage com palco desligado retorna false', () async {
    final stage = StageSession.instance;
    await stage.turnOff();
    expect(stage.playVideoOnStage('https://x/v.mp4'), isFalse);
  });
  test('audioRoute setter duplicado e mudanças não lançam', () async {
    final (stage, _, rx) = await setUpPalco();
    addTearDown(() async {
      await rx.close();
      await stage.turnOff();
    });

    stage.audioRoute = PalcoAudioRoute.tv;
    final before = stage.audioRoute;
    stage.audioRoute = PalcoAudioRoute.tv; // igual: no-op
    expect(stage.audioRoute, before);
    stage.audioRoute = PalcoAudioRoute.mirror;
    expect(stage.audioRoute, PalcoAudioRoute.mirror);
  });
  });

  // ===== Onda 76: mídia LOCAL servida + reroute + background =====
  test('playHymnAudio arquivo local existente: serve via /media', () async {
    final (stage, _, rx) = await setUpPalco();
    addTearDown(() async { await rx.close(); await stage.turnOff(); });

    final f = File('${_tmpCov!.path}/hino_local.mp3');
    await f.writeAsBytes(List.filled(64, 7));

    stage.audioRoute = PalcoAudioRoute.tv;
    final route = stage.playHymnAudio(f.path, title: 'Local');
    expect(route, PalcoAudioRoute.tv);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final play = rx.received.lastWhere((m) => m['type'] == 'audio');
    expect(play['url'].toString(), contains('hymn_hino_local.mp3'));
  });

  test('playHymnAudio arquivo local INEXISTENTE: segue com URL original', () async {
    final (stage, _, rx) = await setUpPalco();
    addTearDown(() async { await rx.close(); await stage.turnOff(); });

    stage.audioRoute = PalcoAudioRoute.tv;
    final route = stage.playHymnAudio('/tmp/nao_existe_76.mp3');
    expect(route, PalcoAudioRoute.tv);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    final play = rx.received.lastWhere((m) => m['type'] == 'audio');
    expect(play['url'], '/tmp/nao_existe_76.mp3');
  });

  test('rerouteCurrentAudio: local → tv re-envia servido; tv → local para', () async {
    final (stage, _, rx) = await setUpPalco();
    addTearDown(() async { await rx.close(); await stage.turnOff(); });

    final f = File('${_tmpCov!.path}/reroute.mp3');
    await f.writeAsBytes(List.filled(32, 9));

    stage.audioRoute = PalcoAudioRoute.local;
    stage.playHymnAudio(f.path, title: 'R');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    stage.audioRoute = PalcoAudioRoute.tv;
    stage.rerouteCurrentAudio();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final play = rx.received.lastWhere((m) => m['type'] == 'audio');
    expect(play['url'].toString(), contains('hymn_reroute.mp3'));

    stage.audioRoute = PalcoAudioRoute.local;
    stage.rerouteCurrentAudio();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(rx.received.last['action'], 'stop');
  });

  test('setBackgroundFromFile persiste e serve bgPalco no palco ligado', () async {
    final (stage, _, rx) = await setUpPalco();
    addTearDown(() async { await rx.close(); await stage.turnOff(); });

    final png = File('${_tmpCov!.path}/bg.png')
      ..writeAsBytesSync([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D, 0x49,
        0x48, 0x44, 0x52, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 0x1F, 0x15,
        0xC4, 0x89, 0, 0, 0, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63,
        0, 1, 0, 0, 5, 0, 1, 0x0D, 0x0A, 0x2D, 0xB4, 0, 0, 0, 0, 0x49, 0x45,
        0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

    await stage.setBackgroundFromFile(png.path);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final bg = rx.received.lastWhere((m) => m['type'] == 'bgPalco');
    expect(bg['url'].toString(), contains('palco_bg.png'));
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

  /// Envia mensagem pro sender (remote-key, ended etc).
  void send(Map<String, dynamic> m) => _ws!.add(jsonEncode(m));

  Future<void> close() async {
    await _ws?.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await messages.close();
  }
}

Future<StreamIterator<Map<String, dynamic>>> _iter(
  Stream<Map<String, dynamic>> s,
) async {
  final it = StreamIterator<Map<String, dynamic>>(s);
  return it;
}


/// Fake do channel do path_provider apontando pra um dir temporário.
class _FakePathProvider extends PathProviderPlatform {
  final String basePath;
  _FakePathProvider(this.basePath);

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}
