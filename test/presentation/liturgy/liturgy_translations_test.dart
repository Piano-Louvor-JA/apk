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
      for (final file
          in Directory('lib/presentation/liturgy')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        for (final match in RegExp(
          r"'liturgy\.(parity|richNotes)\.([A-Za-z]+)'",
        ).allMatches(file.readAsStringSync())) {
          expect(
            bundle['liturgy'][match[1]][match[2]],
            isA<String>(),
            reason: '${match[0]} em $locale',
          );
        }
      }
      expect(
        bundle['liturgy']['types']['audio'],
        isA<String>().having((s) => s.isNotEmpty, 'não vazio', true),
      );
    });
  }
}
