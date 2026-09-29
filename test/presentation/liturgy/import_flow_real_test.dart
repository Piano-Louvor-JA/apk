// Reproduz o import COMPLETO com o .ja real da igreja.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/ja_liturgy_parser.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Reproduz o import COMPLETO com o .ja real da igreja. O arquivo fica fora
  // do repo (dado real): teste só roda onde o arquivo existe (padrão do repo
  // — igual media_duration_reader_test).
  const realFile =
      '/media/rafaelejosi/NovoVolume/nvme-mint/Downloads/liturgia.ja';

  test('import real: sáb (ES) em saturday, culto sex em friday', () async {
    if (!File(realFile).existsSync()) {
      // ignore: avoid_print
      print('skip: arquivo de teste ausente');
      return;
    }
    final bytes = File(realFile).readAsBytesSync();
    final imported = JaLiturgyParser.parse(decodeJaFile(bytes));

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = LiturgyRepository(prefs);

    // mesmo fluxo do liturgy_page (overwrite=true)
    for (final day in imported.keys) {
      final target = LiturgyWeekdayJa.fromJaDay(day);
      if (target == null) continue;
      await repo.saveItems(target, imported[day]!);
    }

    final sab = repo.loadItems(LiturgyWeekday.saturday);
    final dom = repo.loadItems(LiturgyWeekday.sunday);
    final sex = repo.loadItems(LiturgyWeekday.friday);

    // Sábado = Escola Sabatina
    expect(sab, isNotEmpty);
    expect(
      sab.any((i) => i.name.toLowerCase().contains('escola sabatina')),
      isTrue,
      reason:
          'sábado deve ter Escola Sabatina, tem: ${sab.take(3).map((e) => e.name)}',
    );
    // Domingo = Momentos de Louvor / Somos Teus
    expect(dom, isNotEmpty);
    expect(dom.first.name, contains('Momentos de Louvor'));
    // Sexta = culto 18h
    expect(sex, isNotEmpty);
    expect(sex.first.name, contains('18:00'));
  });
}
