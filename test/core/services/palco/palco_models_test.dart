import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_models.dart';

void main() {
  group('PalcoMessage round-trip', () {
    test('projection serializa e desserializa', () {
      final m = PalcoMessage.projection(
        text: 'O nosso sol<br>Veio iluminar',
        footer: 'Nosso Sol é Jesus',
        background: 'https://api.louvorja.com.br/file/images/hasd_132B.jpg',
      );
      final json = m.toJson();
      expect(json['v'], 2);
      expect(json['type'], 'projection');
      expect(json['text'], contains('<br>'));

      final back = PalcoMessage.fromJson(json);
      expect(back.type, 'projection');
      expect(back.fields['footer'], 'Nosso Sol é Jesus');
      expect(back.fields['background'], isNotNull);
    });

    test('audio com now-playing', () {
      final m = PalcoMessage.audio(
        'http://192.168.1.5:7080/proxy?url=x.mp3',
        title: 'Hino 275',
        subtitle: 'Aquieta minh\'alma',
      );
      final json = m.toJson();
      expect(json['title'], 'Hino 275');
      expect(json['action'], 'play');
      final back = PalcoMessage.fromJson(json);
      expect(back.fields['subtitle'], isNotNull);
    });

    test('audio sem opcionais não inclui chaves nulas', () {
      final m = PalcoMessage.audio('http://x/a.mp3');
      expect(m.toJson().containsKey('title'), isFalse);
    });

    test('timer countdown', () {
      final m = PalcoMessage.timer(
        action: 'start',
        duration: 300,
        label: 'Sermão',
      );
      final json = m.toJson();
      expect(json['duration'], 300);
      expect(json['mode'], 'countdown');
    });

    test('bgPalco com url nula vira string vazia', () {
      final m = PalcoMessage.bgPalco(null);
      expect(m.toJson()['url'], '');
    });

    test('idle v1 é aceito (retrocompatibilidade)', () {
      final back = PalcoMessage.fromJson({'v': 1, 'type': 'idle'});
      expect(back.version, 1);
      expect(back.type, 'idle');
    });
  });

  group('PalcoMessage validação', () {
    test('rejeita versão desconhecida', () {
      expect(
        () => PalcoMessage.fromJson({'v': 3, 'type': 'idle'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejeita sem type', () {
      expect(
        () => PalcoMessage.fromJson({'v': 2}),
        throwsA(isA<FormatException>()),
      );
    });

    test('remote-key expõe key', () {
      final back = PalcoMessage.fromJson({
        'v': 2,
        'type': 'remote-key',
        'key': 'next',
      });
      expect(back.remoteKey, 'next');
    });

    test('ended expõe media', () {
      final back = PalcoMessage.fromJson({
        'v': 2,
        'type': 'ended',
        'media': 'audio',
      });
      expect(back.endedMedia, 'audio');
    });
  });

  group('onda 2 — projection com todos os opcionais', () {
    test('projection completa serializa todos os campos opcionais', () {
      final msg = PalcoMessage.projection(
        text: 'Santo, Santo, Santo<br>Santo é o Senhor',
        footer: 'Hino 23',
        background: '#001122',
        footerRef: 'Is 6:3',
        footerColor: '#FFAA00',
        footerWeight: 700,
        footerVersion: 'ARC',
        textShadow: true,
        shadowBlur: 8.0,
        shadowIntensity: 0.6,
        textBox: true,
        boxOpacity: 0.4,
        boxBorder: {'color': '#FFF', 'width': 2},
        textAlign: 'center',
        textVerticalAlign: 'middle',
        fontSize: 48.0,
        fontWeight: 600,
      );
      final json = msg.toJson();
      expect(json['type'], 'projection');
      expect(json['text'], contains('<br>'));
      expect(json['footerRef'], 'Is 6:3');
      expect(json['footerColor'], '#FFAA00');
      expect(json['footerWeight'], 700);
      expect(json['footerVersion'], 'ARC');
      expect(json['textShadow'], isTrue);
      expect(json['shadowBlur'], 8.0);
      expect(json['shadowIntensity'], 0.6);
      expect(json['textBox'], isTrue);
      expect(json['boxOpacity'], 0.4);
      expect(json['boxBorder'], {'color': '#FFF', 'width': 2});
      expect(json['textAlign'], 'center');
      expect(json['textVerticalAlign'], 'middle');
      expect(json['fontSize'], 48.0);
      expect(json['fontWeight'], 600);
      // round-trip preserva
      final back = PalcoMessage.fromJson(
        Map<String, dynamic>.from(json),
      );
      expect(back.fields['footerRef'], 'Is 6:3');
      expect(back.fields['boxBorder'], {'color': '#FFF', 'width': 2});
    });

    test('audio com positionMs e now-playing completo (F3.3g)', () {
      final msg = PalcoMessage.audio(
        'http://192.168.1.10:8765/audio/15.mp3',
        action: 'play',
        title: 'Rocha Eterna',
        subtitle: 'Harpa Cristã',
        cover: 'http://192.168.1.10:8765/cover/15.jpg',
        background: '#112233',
        positionMs: 45000,
      );
      final json = msg.toJson();
      expect(json['url'], contains('192.168.1.10'));
      expect(json['positionMs'], 45000);
      expect(json['title'], 'Rocha Eterna');
      expect(json['subtitle'], 'Harpa Cristã');
      expect(json['cover'], contains('cover/15.jpg'));
      expect(json['background'], '#112233');
      final back = PalcoMessage.fromJson(json);
      expect(back.fields['positionMs'], 45000);
    });

    test('video play e pause', () {
      expect(
        PalcoMessage.video('http://x/v.mp4').toJson()['action'],
        'play',
      );
      expect(
        PalcoMessage.video('http://x/v.mp4', action: 'pause')
            .toJson()['action'],
        'pause',
      );
    });

    test('timer com estilos completos', () {
      final msg = PalcoMessage.timer(
        action: 'start',
        duration: 300,
        mode: 'countdown',
        label: 'Intervalo',
        color: '#00FF00',
        fontSize: 96.0,
        fontWeight: 800,
        textShadow: false,
        shadowBlur: 2.0,
        shadowIntensity: 0.2,
        textAlign: 'left',
        textVerticalAlign: 'top',
      );
      final json = msg.toJson();
      expect(json['duration'], 300);
      expect(json['label'], 'Intervalo');
      expect(json['color'], '#00FF00');
      expect(json['fontSize'], 96.0);
      expect(json['fontWeight'], 800);
      expect(json['textShadow'], isFalse);
      expect(json['shadowBlur'], 2.0);
      expect(json['shadowIntensity'], 0.2);
      expect(json['textAlign'], 'left');
      expect(json['textVerticalAlign'], 'top');
    });

    test('remote.command com id e value; ack accessor', () {
      final cmd = PalcoMessage.remoteCommand(
        'volume',
        id: 'cmd-1',
        value: 55.0,
      );
      final json = cmd.toJson();
      expect(json['type'], 'remote.command');
      expect(json['command'], 'volume');
      expect(json['id'], 'cmd-1');
      expect(json['value'], 55.0);

      final ack = PalcoMessage.fromJson(
        {'v': 2, 'type': 'remote.ack', 'id': 'cmd-1', 'ok': true},
      );
      expect(ack.remoteAckId, 'cmd-1');
      expect(ack.remoteAckOk, isTrue);
    });

    test('remote.state com snapshot e sem state', () {
      final st = PalcoMessage.fromJson({
        'v': 2,
        'type': 'remote.state',
        'state': {'playing': true, 'position': 12},
      });
      expect(st.remoteState['playing'], isTrue);
      expect(PalcoMessage.fromJson({'v': 2, 'type': 'remote.state'}).remoteState,
          isEmpty);
    });

    test('hello role e remote-key accessor', () {
      expect(
        PalcoMessage.fromJson({'v': 2, 'type': 'hello', 'role': 'tv'})
            .helloRole,
        'tv',
      );
      expect(
        PalcoMessage.fromJson({'v': 2, 'type': 'remote-key', 'key': 'next'})
            .remoteKey,
        'next',
      );
      expect(
        PalcoMessage.fromJson({'v': 2, 'type': 'ended', 'media': 'audio'})
            .endedMedia,
        'audio',
      );
    });
  });
}
