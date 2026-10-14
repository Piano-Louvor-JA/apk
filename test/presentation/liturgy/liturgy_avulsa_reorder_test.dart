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

  testWidgets('reorder com destravar move item e persiste', (tester) async {
    final repo = await _seed(DateTime.now());
    await _pump(tester);

    // Página inicia destravada; arrastar pelo handle real da lista.
    final handle = find.byIcon(TablerIcons.gripVertical);
    expect(handle, findsNWidgets(2));
    final gesture = await tester.startGesture(tester.getCenter(handle.first));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(0, 140));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    final loaded = repo.loadAvulsa(DateTime.now());
    expect(loaded.first.name, 'Segundo', reason: 'reorder persistido');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reorder com travar é no-op', (tester) async {
    await _seed(DateTime.now());
    await _pump(tester);

    // Alternar trava oculta as alças de arrasto.
    await tester.tap(find.byKey(const Key('avulsa-lock-toggle')));
    await tester.pumpAndSettle();
    expect(find.byIcon(TablerIcons.gripVertical), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
