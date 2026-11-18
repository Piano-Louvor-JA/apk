import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Toda chave `liturgy.*` usada na Liturgia existe em PT, EN e ES
/// (chave faltando aparece crua na tela, ex.: "liturgy.actions.add").
void main() {
  final keyPattern = RegExp(r"""['"](liturgy\.[A-Za-z0-9_.]+)['"]\s*\.tr\(""");

  Set<String> usedKeys() {
    final keys = <String>{};
    final dirs = [
      Directory('lib/presentation/liturgy'),
      Directory('lib/data/repositories'),
    ];
    for (final dir in dirs) {
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        for (final m in keyPattern.allMatches(file.readAsStringSync())) {
          keys.add(m.group(1)!);
        }
      }
    }
    return keys;
  }

  bool has(Map<String, dynamic> json, String key) {
    Object? node = json;
    for (final part in key.split('.')) {
      if (node is! Map<String, dynamic> || !node.containsKey(part)) {
        return false;
      }
      node = node[part];
    }
    return node is String;
  }

  for (final lang in ['pt-BR', 'en', 'es']) {
    test('chaves da Liturgia existem em $lang', () {
      final json =
          jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
              as Map<String, dynamic>;
      final missing = usedKeys().where((k) => !has(json, k)).toList()..sort();
      expect(missing, isEmpty, reason: 'faltando em $lang');
    });
  }
}
