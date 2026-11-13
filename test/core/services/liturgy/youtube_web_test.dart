import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/youtube_web.dart';

void main() {
  test('embed usa os mesmos parâmetros do player do desktop', () {
    final uri = Uri.parse(YoutubeWeb.embedUrl('abcDEF12345'));
    expect(uri.host, 'www.youtube.com');
    expect(uri.path, '/embed/abcDEF12345');
    expect(uri.queryParameters, {
      'autoplay': '1',
      'controls': '0',
      'rel': '0',
      'fs': '0',
      'iv_load_policy': '3',
      'disablekb': '1',
      'modestbranding': '1',
      'playsinline': '1',
    });
    expect(
      YoutubeWeb.watchUrl('abcDEF12345'),
      'https://www.youtube.com/watch?v=abcDEF12345',
    );
  });

  test('o embed vai com Referer de localhost (evita o erro 153)', () {
    expect(YoutubeWeb.headers, {'Referer': 'http://localhost/'});
  });

  test('o script de anúncio silencia, leva ao fim e clica em Pular', () {
    final script = YoutubeWeb.adSkipScript;
    expect(script, contains('ad-showing'));
    expect(script, contains('.ytp-skip-ad-button'));
    expect(script, contains('muted = true'));
    expect(script, contains('currentTime = duration'));
    expect(script, contains('setInterval'));
  });

  test('a página nunca se vê oculta (o YouTube pausaria ao minimizar)', () {
    final script = YoutubeWeb.adSkipScript;
    expect(script, contains("'visibilityState'"));
    expect(script, contains("'hidden'"));
    expect(script, contains('stopImmediatePropagation'));
  });

  test('comandos agem no vídeo da página', () {
    expect(YoutubeWeb.playScript, contains('.play()'));
    expect(YoutubeWeb.pauseScript, contains('.pause()'));
    expect(
      YoutubeWeb.seekScript(const Duration(milliseconds: 12500)),
      contains('currentTime = 12.5'),
    );
    expect(YoutubeWeb.volumeScript(0.4), contains('volume = 0.4'));
    expect(YoutubeWeb.volumeScript(0), contains('muted = true'));
  });

  group('estado lido da página', () {
    test('aceita JSON direto ou como string (Android devolve aspas)', () {
      const raw =
          '{"playing":true,"position":3.5,"duration":316,"ended":false,'
          '"error":false,"hasData":true}';
      for (final value in [raw, '"${raw.replaceAll('"', r'\"')}"']) {
        final state = YoutubeWebState.parse(value)!;
        expect(state.playing, isTrue);
        expect(state.position, const Duration(milliseconds: 3500));
        expect(state.duration, const Duration(seconds: 316));
        expect(state.ended, isFalse);
        expect(state.error, isFalse);
        expect(state.hasData, isTrue);
      }
    });

    test('anúncio na tela não conta como reprodução do vídeo', () {
      final state = YoutubeWebState.parse(
        '{"playing":true,"position":2,"duration":15,"ad":true}',
      )!;
      expect(state.ad, isTrue);
    });

    test('resposta inválida vira null', () {
      expect(YoutubeWebState.parse(null), isNull);
      expect(YoutubeWebState.parse('null'), isNull);
      expect(YoutubeWebState.parse('xx'), isNull);
    });
  });
}
