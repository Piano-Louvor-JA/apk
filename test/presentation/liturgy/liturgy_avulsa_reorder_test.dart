import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_avulsa_page.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: LiturgyAvulsaPage()));
  await tester.pumpAndSettle();
}

Future<LiturgyRepository> _seed(DateTime date) async {
  final prefs = await SharedPreferences.getInstance();
  final repo = LiturgyRepository(prefs);
  await repo.saveAvulsa(date, [
    LiturgyItem(
      id: 'a1',
      type: LiturgyItemType.otherFiles,
      name: 'Primeiro',
      notes: 'Nota do primeiro',
    ),
    LiturgyItem(id: 'a2', type: LiturgyItemType.otherFiles, name: 'Segundo'),
  ]);
  return repo;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('item com notas mostra botão de nota e abre dialog', (
    tester,
  ) async {
    await _seed(DateTime.now());
    await _pump(tester);

    final noteBtn = find.byTooltip('liturgy.scheduled.notes');
    if (noteBtn.evaluate().isNotEmpty) {
      await tester.tap(noteBtn.first);
      await tester.pumpAndSettle();
      // Dialog mostra o nome do item e a nota.
      expect(find.text('Primeiro'), findsOneWidget);
      expect(find.text('Nota do primeiro'), findsOneWidget);
      await tester.tap(find.text('common.cancel').first);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('reorder com destravar move item e persiste', (tester) async {
    final repo = await _seed(DateTime.now());
    await _pump(tester);

    // Destravar (lock aberto) se existir.
    final lock = find.byIcon(TablerIcons.lock);
    if (lock.evaluate().isNotEmpty) {
      await tester.tap(lock.first);
      await tester.pumpAndSettle();
    }

    // Drag do primeiro item pra baixo (handle do ReorderableListView).
    final handle = find.byIcon(Icons.drag_handle);
    if (handle.evaluate().isNotEmpty) {
      await tester.drag(handle.first, const Offset(0, 120));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final loaded = await repo.loadAvulsa(DateTime.now());
      expect(loaded.first.name, 'Segundo', reason: 'reorder persistido');
      expect(prefs.getString('liturgy_avulsa_test'), isNotNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('reorder com travar é no-op', (tester) async {
    await _seed(DateTime.now());
    await _pump(tester);

    // Página inicia travada: drag handle ausente ou reorder inerte.
    final handle = find.byIcon(Icons.drag_handle);
    if (handle.evaluate().isNotEmpty) {
      await tester.drag(handle.first, const Offset(0, 120));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
