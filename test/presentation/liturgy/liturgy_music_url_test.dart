// Testes da montagem de URL de audio da liturgia (F3.3a).
//
// Bug real: executor montava URL crua (sem percent-encode) — hinos com
// espaco/acento no path quebravam (audio intermitente no culto).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/services/liturgy_item_executor.dart';

void main() {
  group('buildLiturgyMusicUrl', () {
    test('encoda path relativo com espaco e acento por segmento', () {
      final url = buildLiturgyMusicUrl(
        '/musics/pt/1993 - Ja e Tempo/Nosso Sol É Jesus.mp3',
      );
      // Base vem de ApiConfig.urlFiles (--dart-define); sem env = ''.
      expect(
        url,
        '${ApiConfig.urlFiles}/musics/pt/1993%20-%20Ja%20e%20Tempo/Nosso%20Sol%20%C3%89%20Jesus.mp3',
      );
    });

    test('encoda cada segmento preservando barras', () {
      final url = buildLiturgyMusicUrl('/musics/pt/pasta/arquivo.mp3');
      expect(url, '${ApiConfig.urlFiles}/musics/pt/pasta/arquivo.mp3');
    });

    test('URL absoluta http passa inalterada', () {
      const abs = 'http://example.com/a%20b.mp3';
      expect(buildLiturgyMusicUrl(abs), abs);
    });

    test('URL absoluta https passa inalterada', () {
      const abs = 'https://cdn.louvorja.com.br/x.mp3';
      expect(buildLiturgyMusicUrl(abs), abs);
    });

    test('barras iniciais duplicadas sao normalizadas', () {
      final url = buildLiturgyMusicUrl('//musics/pt/a.mp3');
      expect(url, '${ApiConfig.urlFiles}/musics/pt/a.mp3');
    });

    test('segmento com cedilha e til sao encodados', () {
      final url = buildLiturgyMusicUrl('/musics/pt/Sermão/Coração.mp3');
      expect(url.contains('%C3%A3'), isTrue); // ã
      expect(url.contains('/'), isTrue);
      expect(url.contains(' '), isFalse);
    });
  });
}
