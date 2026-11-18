library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';

/// RED 8 (SPEC v1.2.0): origem /db/* exclusivamente de LOUVORJA_URL_BUNDLES
/// (default público upstream). O override é compile-time (--dart-define),
/// então este teste é BICONDICIONAL: roda verde sem define (default) e com
/// define (override verificado pelo comando documentado abaixo).
///
/// Override verificado com:
///   flutter test --dart-define=LOUVORJA_URL_BUNDLES=https://bundles.test.example \
///     test/core/constants/api_config_bundles_origin_test.dart
void main() {
  test('bundlesUrls: default upstream sem define; override quando definido',
      () {
    const override = String.fromEnvironment('LOUVORJA_URL_BUNDLES');
    final urls = ApiConfig.bundlesUrls();

    if (override.isEmpty) {
      // Sem --dart-define: exatamente o default público, nenhuma outra origem.
      expect(urls, [ApiConfig.defaultBundlesOrigin]);
      expect(urls.first, 'https://api.louvorja.com.br');
    } else {
      // Com --dart-define: override em primeiro lugar (default como reserva
      // documentada atrás, nunca à frente do override).
      expect(urls.first, override);
      expect(urls.indexOf(override), lessThan(urls.indexOf(
        ApiConfig.defaultBundlesOrigin,
      )));
    }

    // Invariante nas duas configurações: nada derivado de database/json_db.
    expect(urls.where((u) => u.contains('json_db')), isEmpty);
    expect(urls.where((u) => u.contains('pianolouvorja.com.br')), isEmpty);
  });
}
