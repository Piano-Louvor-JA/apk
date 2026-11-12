import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['pt-BR', 'en', 'es']) {
    test('tipo áudio tem rótulo traduzido em $locale', () {
      final bundle =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        bundle['liturgy']['types']['audio'],
        isA<String>().having((s) => s.isNotEmpty, 'não vazio', true),
      );
    });
  }
}
