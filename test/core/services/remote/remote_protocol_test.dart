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

  group('onda 2 — parsing completo dos módulos', () {
    const playerBase =
        '{"v":1,"type":"state","player":{"playing":false,"positionMs":0,'
        '"durationMs":0,"slideIndex":0,"slideCount":0,"volume":0,'
        '"canPrevious":false,"canNext":false}';

    test('liturgy: items completos, seleção e campos opcionais', () {
      final msg = RemoteProtocol.parse(
        '$playerBase,"liturgy":{"selectedIndex":2,"items":['
        '{"index":0,"type":"hymn","title":"Hino 1","done":true,'
        '"subtitle":"Harpa","isCategory":false,"accentColor":"#FF0000"},'
        '{"index":1,"type":"category","isCategory":true},'
        '{"index":"x"},'
        '"não-é-map"]}}',
      )! as RemotePlayerState;
      expect(msg.liturgySelectedIndex, 2);
      expect(msg.liturgyItems.length, 2);
      expect(msg.liturgyItems[0].index, 0);
      expect(msg.liturgyItems[0].type, 'hymn');
      expect(msg.liturgyItems[0].title, 'Hino 1');
      expect(msg.liturgyItems[0].done, isTrue);
      expect(msg.liturgyItems[0].subtitle, 'Harpa');
      expect(msg.liturgyItems[0].isCategory, isFalse);
      expect(msg.liturgyItems[0].accentColor, '#FF0000');
      expect(msg.liturgyItems[1].isCategory, isTrue);
      expect(msg.liturgyItems[1].title, isNull);
    });

    test('liturgy: ausente → lista vazia e seleção null', () {
      final msg = RemoteProtocol.parse('$playerBase}')! as RemotePlayerState;
      expect(msg.liturgyItems, isEmpty);
      expect(msg.liturgySelectedIndex, isNull);
    });

    test('media: searchResults filtra ids inválidos e preserva track', () {
      final msg = RemoteProtocol.parse(
        '$playerBase,"media":{"query":"amor","searchResults":['
        '{"musicId":10,"name":"Amor","track":3},'
        '{"musicId":0,"name":"inválido"},'
        '{"musicId":12,"name":"Sem track"}]}}',
      )! as RemotePlayerState;
      expect(msg.mediaModule, isNotNull);
      expect(msg.mediaModule!.query, 'amor');
      expect(msg.mediaModule!.searchResults.length, 2);
      expect(msg.mediaModule!.searchResults[0].musicId, 10);
      expect(msg.mediaModule!.searchResults[0].track, 3);
      expect(msg.mediaModule!.searchResults[1].track, isNull);
    });

    test('media: query não-string e results não-lista → defaults', () {
      final msg = RemoteProtocol.parse(
        '$playerBase,"media":{"query":42,"searchResults":"x"}}',
      )! as RemotePlayerState;
      expect(msg.mediaModule!.query, isNull);
      expect(msg.mediaModule!.searchResults, isEmpty);
    });

    test('clock: defaults quando style não-string', () {
      final msg = RemoteProtocol.parse(
        '$playerBase,"clock":{"style":42,"showSeconds":true,'
        '"format24h":false,"isProjecting":false}}',
      )! as RemotePlayerState;
      expect(msg.clockModule!.style, 'digital');
      expect(msg.clockModule!.showSeconds, isTrue);
      expect(msg.clockModule!.format24h, isFalse);
    });

    test('random: listas convertidas, vazias filtradas e defaults', () {
      final msg = RemoteProtocol.parse(
        '$playerBase,"random":{"mode":"numbers","numberMin":1,'
        '"numberMax":100,"available":["Ana","","João"],'
        '"drawn":["Bia"],"currentDisplay":7,"drawnCount":1}}',
      )! as RemotePlayerState;
      final r = msg.randomModule!;
      expect(r.mode, 'numbers');
      expect(r.numberMin, 1);
      expect(r.numberMax, 100);
      expect(r.available, ['Ana', 'João']);
      expect(r.drawn, ['Bia']);
      expect(r.currentDisplay, isNull);
      expect(r.drawnCount, 1);
    });

    test('bible: books e versions filtram entradas inválidas', () {
      final msg = RemoteProtocol.parse(
        '$playerBase,"bible":{"bookId":2,"chapter":5,'
        '"selectedVerses":[1,"x",3],"isProjecting":true,"versionId":7,'
        '"books":[{"id":1,"name":"Gênesis","chapters":50,"number":1},'
        '{"id":"x","name":"inválido"},{"name":"sem id"}],'
        '"versions":[{"id":2,"abbreviation":"ARC"},'
        '{"id":"x","abbreviation":"inválido"}]}}',
      )! as RemotePlayerState;
      final b = msg.bibleModule!;
      expect(b.selectedVerses, [1, 3]);
      expect(b.versionId, 7);
      expect(b.books.length, 1);
      expect(b.books[0].id, 1);
      expect(b.books[0].chapters, 50);
      expect(b.versions.length, 1);
      expect(b.versions[0].abbreviation, 'ARC');
    });

    test('timer: campos completos e status não-string → default', () {
      final msg = RemoteProtocol.parse(
        '$playerBase,"timer":{"status":42,"accumulatedMs":65000,'
        '"savedTimesMs":[1000,2000],"isProjecting":true}}',
      )! as RemotePlayerState;
      final t = msg.timerModule!;
      expect(t.status, 'idle');
      expect(t.accumulatedMs, 65000);
      expect(t.savedTimesMs, [1000, 2000]);
      expect(t.isProjecting, isTrue);
    });

    test('countdown: finished e status default', () {
      final msg = RemoteProtocol.parse(
        '$playerBase,"countdown":{"status":"running","durationMs":90000,'
        '"accumulatedMs":1000,"finished":true,"savedTimesMs":[500]}}',
      )! as RemotePlayerState;
      final c = msg.countdownModule!;
      expect(c.status, 'running');
      expect(c.finished, isTrue);
      expect(c.accumulatedMs, 1000);
    });
  });

  group('onda 2 — validações de command', () {
    test('liturgySelect com value não-inteiro → null', () {
      expect(
        RemoteProtocol.parse(
          '{"v":1,"type":"command","id":"x","action":"liturgy.select",'
          '"value":1.5}',
        ),
        isNull,
      );
    });

    test('liturgySelect com value negativo → null', () {
      expect(
        RemoteProtocol.parse(
          '{"v":1,"type":"command","id":"x","action":"liturgy.select",'
          '"value":-1}',
        ),
        isNull,
      );
    });

    test('setVolume value não-num → null', () {
      expect(
        RemoteProtocol.parse(
          '{"v":1,"type":"command","id":"x","action":"player.setVolume",'
          '"value":"80"}',
        ),
        isNull,
      );
    });

    test('command com positionMs negativo → null', () {
      expect(
        RemoteProtocol.parse(
          '{"v":1,"type":"command","id":"x","action":"player.seek",'
          '"positionMs":-1}',
        ),
        isNull,
      );
    });

    test('command com mode fora da lista → null', () {
      expect(
        RemoteProtocol.parse(
          '{"v":1,"type":"command","id":"x","action":"player.setMode",'
          '"mode":"karaoke"}',
        ),
        isNull,
      );
    });

    test('bible.open chapter < 1 → null', () {
      expect(
        RemoteProtocol.parse(
          '{"v":1,"type":"command","id":"x","action":"bible.open",'
          '"bookId":1,"chapter":0}',
        ),
        isNull,
      );
    });

    test('bible.open versionId < 1 → null', () {
      expect(
        RemoteProtocol.parse(
          '{"v":1,"type":"command","id":"x","action":"bible.open",'
          '"versionId":0}',
        ),
        isNull,
      );
    });

    test('countdown.setDuration negativo → null', () {
      expect(
        RemoteProtocol.parse(
          '{"v":1,"type":"command","id":"x","action":"countdown.setDuration",'
          '"durationMs":-5}',
        ),
        isNull,
      );
    });

    test('token não-string em command → ignorado ou null (comportamento atual)',
        () {
      final msg = RemoteProtocol.parse(
        '{"v":1,"type":"command","id":"x","action":"player.play",'
        '"token":42}',
      );
      // Documenta o comportamento atual: token não-string é descartado.
      if (msg != null) {
        expect((msg as RemoteCommand).token, isNull);
      }
    });
  });
}
