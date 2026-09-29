import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_proxy.dart';

void main() {
  group('PalcoProxyHeaders.forUrl', () {
    test('MP3 da API ganha UA Web0S + Accept áudio + Referer', () {
      final h = PalcoProxyHeaders.forUrl(
        'https://api.louvorja.com.br/file/musics/pt/hino.mp3',
      );
      expect(h['User-Agent'], contains('Web0S'));
      expect(h['Accept'], startsWith('audio/mpeg'));
      expect(h['Referer'], 'https://api.louvorja.com.br/');
    });

    test('JSON da API ganha Accept application/json', () {
      final h = PalcoProxyHeaders.forUrl(
        'https://api.louvorja.com.br/json_db/music_1',
      );
      expect(h['Accept'], 'application/json');
    });

    test('MP4 ganha Accept de vídeo', () {
      final h = PalcoProxyHeaders.forUrl('http://x/video.mp4');
      expect(h['Accept'], startsWith('video/mp4'));
    });

    test('Imagem genérica', () {
      final h = PalcoProxyHeaders.forUrl(
        'https://api.louvorja.com.br/file/images/a.jpg',
      );
      expect(h['Accept'], '*/*');
      expect(h.containsKey('Referer'), isFalse);
    });
  });

  group('PalcoProxyHeaders.reencodePath', () {
    test('acentos e espaços são encodados', () {
      final out = PalcoProxyHeaders.reencodePath(
        'https://api.louvorja.com.br/file/musics/pt/1992 - Brilha Jesus/Nosso Sol É Jesus.mp3',
      );
      expect(out, contains('%20'));
      expect(out, contains('%C3%89')); // É
      expect(Uri.parse(out).path.contains(' '), isFalse);
    });

    test('URL já limpa não muda', () {
      const url = 'https://api.louvorja.com.br/file/images/a.jpg';
      expect(PalcoProxyHeaders.reencodePath(url), url);
    });
  });

  group('PalcoProxyHeaders wrap/unwrap', () {
    test('round-trip preserva a URL', () {
      const original = 'https://api.louvorja.com.br/file/images/hasd_132B.jpg';
      final wrapped = PalcoProxyHeaders.wrapForProxy(
        'http://192.168.1.5:7080',
        original,
      );
      expect(wrapped, startsWith('http://192.168.1.5:7080/proxy?url='));
      final query = wrapped.split('?url=')[1];
      expect(PalcoProxyHeaders.unwrapFromProxy('url=$query'), original);
    });

    test('base com barra final não duplica', () {
      final wrapped = PalcoProxyHeaders.wrapForProxy(
        'http://1.2.3.4:7080/',
        'http://x/a.mp3',
      );
      expect(wrapped, startsWith('http://1.2.3.4:7080/proxy?url='));
      expect(wrapped.contains('//proxy'), isFalse);
    });

    test('query inválida retorna null', () {
      expect(PalcoProxyHeaders.unwrapFromProxy('foo=bar'), isNull);
    });
  });

  group('PalcoContentType', () {
    test('extensões conhecidas', () {
      expect(PalcoContentType.forPath('/a/b.png'), 'image/png');
      expect(PalcoContentType.forPath('/a/b.MP3'), 'audio/mpeg');
      expect(PalcoContentType.forPath('/a/b.mp4'), 'video/mp4');
      expect(PalcoContentType.forPath('/a/bxyz'), 'application/octet-stream');
    });
  });

  group('PalcoRangeResponse', () {
    test('sem Range → 200 com total', () {
      final r = PalcoRangeResponse.forRange(null, 1000, 'video/mp4');
      expect(r.status, 200);
      expect(r.contentLength, 1000);
      expect(r.contentRange, isNull);
      expect(r.headers['Accept-Ranges'], 'bytes');
    });

    test('Range com fim → 206 parcial', () {
      final r = PalcoRangeResponse.forRange(
        'bytes=0-999',
        2204842,
        'video/mp4',
      );
      expect(r.status, 206);
      expect(r.contentLength, 1000);
      expect(r.contentRange, 'bytes 0-999/2204842');
    });

    test('Range aberto (bytes=1000-) → até o fim', () {
      final r = PalcoRangeResponse.forRange('bytes=1000-', 2000, 'video/mp4');
      expect(r.status, 206);
      expect(r.contentLength, 1000);
      expect(r.contentRange, 'bytes 1000-1999/2000');
    });

    test('Range inválido → 200 full (parseRange null)', () {
      final r = PalcoRangeResponse.forRange('bytes=5000-', 2000, 'video/mp4');
      expect(r.status, 200);
    });

    test('Range com end > total é clampado', () {
      final r = PalcoRangeResponse.forRange('bytes=0-99999', 100, 'video/mp4');
      expect(r.contentLength, 100);
      expect(r.contentRange, 'bytes 0-99/100');
    });
  });
}
