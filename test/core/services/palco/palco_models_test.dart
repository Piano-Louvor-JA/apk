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
}
