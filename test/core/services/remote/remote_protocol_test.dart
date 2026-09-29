library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

void main() {
  group('RemoteCommand', () {
    test('encode play → envelope v1 com action player.play', () {
      final json =
          jsonDecode(
                RemoteCommand(id: 'abc', action: RemoteAction.play).encode(),
              )
              as Map<String, dynamic>;
      expect(json['v'], 1);
      expect(json['type'], 'command');
      expect(json['id'], 'abc');
      expect(json['action'], 'player.play');
    });

    test('encode setVolume carrega value 0-100', () {
      final json =
          jsonDecode(
                RemoteCommand(
                  id: 'v1',
                  action: RemoteAction.setVolume,
                  volume: 80,
                ).encode(),
              )
              as Map<String, dynamic>;
      expect(json['action'], 'player.setVolume');
      expect(json['value'], 80);
    });

    test('encode seek carrega positionMs', () {
      final json =
          jsonDecode(
                RemoteCommand(
                  id: 's1',
                  action: RemoteAction.seek,
                  position: const Duration(seconds: 34),
                ).encode(),
              )
              as Map<String, dynamic>;
      expect(json['action'], 'player.seek');
      expect(json['positionMs'], 34000);
    });

    test('encode setMode carrega mode', () {
      final json =
          jsonDecode(
                RemoteCommand(
                  id: 'm1',
                  action: RemoteAction.setMode,
                  mode: 'instrumental',
                ).encode(),
              )
              as Map<String, dynamic>;
      expect(json['action'], 'player.setMode');
      expect(json['mode'], 'instrumental');
    });

    test('encode open carrega hymnId e mode', () {
      final json =
          jsonDecode(
                RemoteCommand(
                  id: 'o1',
                  action: RemoteAction.open,
                  hymnId: 15,
                  mode: 'audio',
                ).encode(),
              )
              as Map<String, dynamic>;
      expect(json['action'], 'player.open');
      expect(json['hymnId'], 15);
      expect(json['mode'], 'audio');
    });

    test('encode com token (primeira mensagem autentica)', () {
      final json =
          jsonDecode(
                RemoteCommand(
                  id: 't1',
                  action: RemoteAction.play,
                  token: 'X9K2AB',
                ).encode(),
              )
              as Map<String, dynamic>;
      expect(json['token'], 'X9K2AB');
    });

    test('round-trip: parse do próprio encode', () {
      final cmd = RemoteCommand(
        id: 'rt',
        action: RemoteAction.open,
        hymnId: 42,
        mode: 'video',
        token: 'ABC123',
      );
      final parsed = RemoteProtocol.parse(cmd.encode());
      expect(parsed, isA<RemoteCommand>());
      final c = parsed! as RemoteCommand;
      expect(c.id, 'rt');
      expect(c.action, RemoteAction.open);
      expect(c.hymnId, 42);
      expect(c.mode, 'video');
      expect(c.token, 'ABC123');
    });
  });

  group('RemoteState', () {
    test('encode+parse round-trip completo', () {
      final state = RemotePlayerState(
        hymnId: 15,
        title: 'Rocha Eterna',
        mode: 'audio',
        playing: true,
        position: const Duration(seconds: 34),
        duration: const Duration(minutes: 3, seconds: 30),
        slideIndex: 2,
        slideCount: 5,
        volume: 80,
        canPrevious: true,
        canNext: false,
      );
      final parsed = RemoteProtocol.parse(state.encode());
      expect(parsed, isA<RemotePlayerState>());
      final s = parsed! as RemotePlayerState;
      expect(s.hymnId, 15);
      expect(s.title, 'Rocha Eterna');
      expect(s.playing, isTrue);
      expect(s.position, const Duration(seconds: 34));
      expect(s.duration, const Duration(minutes: 3, seconds: 30));
      expect(s.slideIndex, 2);
      expect(s.slideCount, 5);
      expect(s.volume, 80);
      expect(s.canPrevious, isTrue);
      expect(s.canNext, isFalse);
    });

    test('estado vazio (player fechado) é válido', () {
      const raw =
          '{"v":1,"type":"state","player":{"playing":false,"positionMs":0,'
          '"durationMs":0,"slideIndex":0,"slideCount":0,"volume":0,'
          '"canPrevious":false,"canNext":false}}';
      final parsed = RemoteProtocol.parse(raw) as RemotePlayerState;
      expect(parsed.hymnId, isNull);
      expect(parsed.title, isNull);
      expect(parsed.playing, isFalse);
    });
  });

  group('RemoteHello', () {
    test('encodifica hello com device', () {
      final hello = const RemoteHello(device: 'SM-A155F', appVersion: '0.1.86');
      final map = jsonDecode(hello.encode()) as Map<String, dynamic>;
      expect(map['v'], 1);
      expect(map['type'], 'hello');
      expect(map['device'], 'SM-A155F');
      expect(map['appVersion'], '0.1.86');
    });

    test('parser aceita hello válido', () {
      final msg = RemoteProtocol.parse(
        jsonEncode({'v': 1, 'type': 'hello', 'device': 'Pixel 8'}),
      )!;
      expect(msg, isA<RemoteHello>());
      expect((msg as RemoteHello).device, 'Pixel 8');
    });

    test('parser rejeita hello sem device', () {
      expect(
        RemoteProtocol.parse(jsonEncode({'v': 1, 'type': 'hello'})),
        isNull,
      );
    });
  });

  group('ack / error / ping / pong', () {
    test('ack ok', () {
      const raw = '{"v":1,"type":"ack","id":"a1","ok":true}';
      final parsed = RemoteProtocol.parse(raw)! as RemoteAck;
      expect(parsed.id, 'a1');
      expect(parsed.ok, isTrue);
    });

    test('ack erro', () {
      final parsed =
          RemoteProtocol.parse(RemoteAck(id: 'a2', ok: false).encode())!
              as RemoteAck;
      expect(parsed.ok, isFalse);
    });

    test('error com code e message', () {
      const raw =
          '{"v":1,"type":"error","id":"e1","code":"unknown_action",'
          '"message":"ação desconhecida"}';
      final parsed = RemoteProtocol.parse(raw)! as RemoteError;
      expect(parsed.id, 'e1');
      expect(parsed.code, 'unknown_action');
      expect(parsed.message, 'ação desconhecida');
    });

    test('ping e pong', () {
      expect(RemoteProtocol.parse('{"v":1,"type":"ping"}'), isA<RemotePing>());
      final pong = RemoteProtocol.parse(RemotePong().encode())! as RemotePong;
      expect(pong.type, 'pong');
    });
  });

  group('robustez do parser', () {
    test('JSON inválido → null (ignorar, nunca quebrar)', () {
      expect(RemoteProtocol.parse('não é json'), isNull);
      expect(RemoteProtocol.parse(''), isNull);
      expect(RemoteProtocol.parse('{'), isNull);
    });

    test('sem type ou v≠1 → null', () {
      expect(RemoteProtocol.parse('{"id":"x"}'), isNull);
      expect(
        RemoteProtocol.parse(
          '{"v":2,"type":"command","id":"x",'
          '"action":"player.play"}',
        ),
        isNull,
      );
    });

    test('action desconhecida → null (peer antigo, ignora)', () {
      expect(
        RemoteProtocol.parse(
          '{"v":1,"type":"command","id":"x","action":"player.dj"}',
        ),
        isNull,
      );
    });

    test('setVolume fora de faixa → null (validação de entrada)', () {
      expect(
        RemoteProtocol.parse(
          '{"v":1,"type":"command","id":"x","action":"player.setVolume",'
          '"value":150}',
        ),
        isNull,
      );
    });

    test('seek negativo → null', () {
      expect(
        RemoteProtocol.parse(
          '{"v":1,"type":"command","id":"x","action":"player.seek",'
          '"positionMs":-5}',
        ),
        isNull,
      );
    });
  });

  group('v2 — bible/timer/countdown', () {
    test('encode bible.open carrega versionId/bookId/chapter/verse', () {
      final json =
          jsonDecode(
                RemoteCommand(
                  id: 'b1',
                  action: RemoteAction.bibleOpen,
                  versionId: 1,
                  bookId: 1,
                  chapter: 3,
                  verse: 3,
                ).encode(),
              )
              as Map<String, dynamic>;
      expect(json['action'], 'bible.open');
      expect(json['versionId'], 1);
      expect(json['bookId'], 1);
      expect(json['chapter'], 3);
      expect(json['verse'], 3);
    });

    test('encode countdown.setDuration carrega durationMs', () {
      final json =
          jsonDecode(
                RemoteCommand(
                  id: 'c1',
                  action: RemoteAction.countdownSetDuration,
                  durationMs: 60000,
                ).encode(),
              )
              as Map<String, dynamic>;
      expect(json['action'], 'countdown.setDuration');
      expect(json['durationMs'], 60000);
    });

    test('parse command bible.open (vindo de peer de teste)', () {
      final msg = RemoteProtocol.parse(
        '{"v":1,"type":"command","id":"x","action":"bible.open",'
        '"bookId":1,"chapter":2,"verse":4}',
      );
      expect(msg, isA<RemoteCommand>());
      final cmd = msg! as RemoteCommand;
      expect(cmd.action, RemoteAction.bibleOpen);
      expect(cmd.bookId, 1);
      expect(cmd.chapter, 2);
      expect(cmd.verse, 4);
    });

    test('parse command countdown.setDuration inválido (0) → null', () {
      final msg = RemoteProtocol.parse(
        '{"v":1,"type":"command","id":"x","action":"countdown.setDuration",'
        '"durationMs":0}',
      );
      expect(msg, isNull);
    });

    test('state v2 traz módulos bible/timer/countdown', () {
      final msg = RemoteProtocol.parse(
        '{"v":1,"type":"state","player":{"playing":false,"positionMs":0,'
        '"durationMs":0,"slideIndex":0,"slideCount":0,"volume":0,'
        '"canPrevious":false,"canNext":false},'
        '"liturgy":{"selectedIndex":null,"items":[]},'
        '"bible":{"bookId":1,"chapter":3,"selectedVerses":[3,4],'
        '"isProjecting":true},'
        '"timer":{"status":"running","accumulatedMs":42000,'
        '"savedTimesMs":[30000],"isProjecting":false},'
        '"countdown":{"status":"idle","durationMs":300000,'
        '"accumulatedMs":0,"finished":false,"savedTimesMs":[],'
        '"isProjecting":false}}',
      );
      expect(msg, isA<RemotePlayerState>());
      final st = msg! as RemotePlayerState;
      expect(st.bibleModule, isNotNull);
      expect(st.bibleModule!.bookId, 1);
      expect(st.bibleModule!.selectedVerses, [3, 4]);
      expect(st.bibleModule!.isProjecting, isTrue);
      expect(st.timerModule, isNotNull);
      expect(st.timerModule!.status, 'running');
      expect(st.timerModule!.savedTimesMs, [30000]);
      expect(st.countdownModule, isNotNull);
      expect(st.countdownModule!.durationMs, 300000);
      expect(st.countdownModule!.finished, isFalse);
    });

    test('state sem módulos v2 → campos null (peer v1)', () {
      final msg = RemoteProtocol.parse(
        '{"v":1,"type":"state","player":{"playing":false,"positionMs":0,'
        '"durationMs":0,"slideIndex":0,"slideCount":0,"volume":0,'
        '"canPrevious":false,"canNext":false},'
        '"liturgy":{"selectedIndex":null,"items":[]}}',
      );
      final st = msg! as RemotePlayerState;
      expect(st.bibleModule, isNull);
      expect(st.timerModule, isNull);
      expect(st.countdownModule, isNull);
    });
  });

  group('v2 fase 2 — clock/random', () {
    test('encode random.addName carrega name', () {
      final json =
          jsonDecode(
                RemoteCommand(
                  id: 'r1',
                  action: RemoteAction.randomAddName,
                  name: 'Ana',
                ).encode(),
              )
              as Map<String, dynamic>;
      expect(json['action'], 'random.addName');
      expect(json['name'], 'Ana');
    });

    test('encode clock.setConfig carrega style/showSeconds/format24h', () {
      final json =
          jsonDecode(
                RemoteCommand(
                  id: 'k1',
                  action: RemoteAction.clockSetConfig,
                  style: 'analog',
                  showSeconds: false,
                ).encode(),
              )
              as Map<String, dynamic>;
      expect(json['style'], 'analog');
      expect(json['showSeconds'], false);
      expect(json.containsKey('format24h'), isFalse);
    });

    test('state v2 fase 2 traz clock/random', () {
      final msg = RemoteProtocol.parse(
        '{"v":1,"type":"state","player":{"playing":false,"positionMs":0,'
        '"durationMs":0,"slideIndex":0,"slideCount":0,"volume":0,'
        '"canPrevious":false,"canNext":false},'
        '"liturgy":{"selectedIndex":null,"items":[]},'
        '"clock":{"style":"analog","showSeconds":false,"format24h":true,'
        '"isProjecting":true},'
        '"random":{"mode":"names","drawnCount":2,"availableCount":5,'
        '"isDrawing":true,"currentDisplay":"Ana","isProjecting":true}}',
      );
      final st = msg! as RemotePlayerState;
      expect(st.clockModule, isNotNull);
      expect(st.clockModule!.style, 'analog');
      expect(st.clockModule!.isProjecting, isTrue);
      expect(st.randomModule, isNotNull);
      expect(st.randomModule!.isDrawing, isTrue);
      expect(st.randomModule!.currentDisplay, 'Ana');
      expect(st.randomModule!.availableCount, 5);
    });
  });

  group('RemotePairing', () {
    test('gera token de 6 chars alfanumérico', () {
      final token = RemotePairing.generateToken();
      expect(token.length, 6);
      expect(RegExp(r'^[A-Z0-9]{6}$').hasMatch(token), isTrue);
    });

    test('gera tokens distintos (não constante)', () {
      final tokens = {
        for (var i = 0; i < 50; i++) RemotePairing.generateToken(),
      };
      expect(tokens.length, greaterThan(1));
    });

    test('valida token correto e rejeita errado', () {
      expect(RemotePairing.matches('ABC123', 'ABC123'), isTrue);
      expect(RemotePairing.matches('ABC123', 'abc123'), isFalse);
      expect(RemotePairing.matches('ABC123', ''), isFalse);
      expect(RemotePairing.matches('ABC123', 'ABC12'), isFalse);
    });
  });
}
