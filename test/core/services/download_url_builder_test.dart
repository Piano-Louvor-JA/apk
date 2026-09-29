library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import 'package:louvorja_piano_mobile/core/services/download_url_builder.dart';

void main() {
  group('DownloadUrlBuilder.build', () {
    test('encoda espacos e acentos do caminho', () {
      final url = DownloadUrlBuilder.build(
        '/musics/pt/1993 - Já é Tempo/Todos Animados no Senhor.mp3',
      );
      // Nenhum caractere bruto de espaco/acentos fora de %XX
      expect(url, contains('%20'));
      expect(url, isNot(contains(' ')));
      expect(url, isNot(contains('Já')));
    });

    test('preserva barras separadoras do path', () {
      final url = DownloadUrlBuilder.build('/musics/pt/pasta/arquivo.mp3');
      // Base vem de ApiConfig.urlFiles (--dart-define); sem env = ''.
      expect(url, '${ApiConfig.urlFiles}/musics/pt/pasta/arquivo.mp3');
    });

    test('URL absoluta http retorna inalterada', () {
      const absolute = 'https://cdn.exemplo.com/a.mp3';
      expect(DownloadUrlBuilder.build(absolute), absolute);
    });

    test('remove barras iniciais duplicadas', () {
      final url = DownloadUrlBuilder.build('//musics/a.mp3');
      expect(url, '${ApiConfig.urlFiles}/musics/a.mp3');
    });

    test('path vazio nao quebra', () {
      expect(DownloadUrlBuilder.build(''), isNotEmpty);
    });

    test('resultado e sempre URI valida (parse nao lanca)', () {
      final url = DownloadUrlBuilder.build(
        '/musics/pt/1993 - Já é Tempo/Santo! (Deus Está Aqui).mp3',
      );
      expect(() => Uri.parse(url), returnsNormally);
    });
  });
}
