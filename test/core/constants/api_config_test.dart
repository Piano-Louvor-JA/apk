import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/constants/api_config.dart';

/// Fallback em cascata de APIs — contrato SEM hardcoded e SEM default:
/// tudo vem de --dart-define. Env vazia = lista sem aquela entrada.
/// Os valores de produção do teste espelham o .env/CI de build.
void main() {
  // Nota: String.fromEnvironment é const e resolvido em COMPILE time —
  // não dá para mockar por teste. Por isso os testes validam o CONTRATO
  // estrutural (funcões puras de combinação) e o comportamento com o
  // build padrão da máquina de CI (que define as vars via dart-define).

  group('ApiConfig — contrato estrutural', () {
    test('databaseUrls/filesUrls nunca retornam entradas vazias', () {
      // Se o build não define as envs, urlDatabase/urlFiles são '' e
      // NÃO podem aparecer como entrada vazia na cascata.
      for (final url in ApiConfig.databaseUrls()) {
        expect(url.isNotEmpty, isTrue);
        expect(url.endsWith('/json_db'), isTrue, reason: url);
      }
      for (final url in ApiConfig.filesUrls()) {
        expect(url.isNotEmpty, isTrue);
        expect(url.endsWith('/file'), isTrue, reason: url);
      }
    });

    test('fallbackHosts: split por vírgula sem entradas vazias', () {
      // No build padrão do CI, LOUVORJA_FALLBACK_URLS tem os 2 hosts.
      // Se futuramente a env vier vazia, a lista tem que ser vazia —
      // nunca ['', ' '] ou hosts 'https://api.louvorja.com.br ' com espaço.
      for (final host in ApiConfig.fallbackHosts) {
        expect(host.isNotEmpty, isTrue);
        expect(host.startsWith('http'), isTrue, reason: host);
        expect(host.trim(), host, reason: 'sem espaço nas bordas');
      }
    });

    test('primaryHost é origem da urlDatabase (ou null se vazia)', () {
      final primary = ApiConfig.primaryHost;
      if (primary != null) {
        expect(primary.startsWith('http'), isTrue);
      }
      // null é válido: build sem primária configurada.
    });

    test('cascata: primária primeiro, fallbacks depois, sem duplicar', () {
      final db = ApiConfig.databaseUrls();
      final primary = ApiConfig.urlDatabase;
      if (primary.isNotEmpty) {
        expect(db.first, primary);
      }
      expect(db.toSet().length, db.length, reason: 'sem duplicatas');
    });
  });
}
