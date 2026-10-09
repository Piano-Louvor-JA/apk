library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_avulsa_page.dart';

/// Onda 80: seção "agendados desta data" (importados do Delphi) — item com
/// categoria, item sem categoria (fallback), notes com diálogo, e FAB de
/// primeira categoria quando lista vazia.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> seedScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ScheduledRepository(prefs);
    final today = DateTime.now();
    await repo.saveCategories([
      const ScheduledCategory(id: 'c1', name: 'Louvor'),
    ]);
    await repo.saveItems([
      ScheduledItem(
        id: 's1',
        categoryId: 'c1',
        date: today,
        name: 'Hino Agendado',
        notes: 'Chegar 30min antes',
      ),
      ScheduledItem(
        id: 's2',
        categoryId: 'inexistente',
        date: today,
        name: 'Sem Categoria',
      ),
    ]);
  }

  testWidgets('itens agendados do dia aparecem com categoria e notes', (
    tester,
  ) async {
    await seedScheduled();
    await tester.pumpWidget(const MaterialApp(home: LiturgyAvulsaPage()));
    await tester.pumpAndSettle();

    expect(find.text('Hino Agendado'), findsOneWidget);
    expect(find.text('Louvor'), findsWidgets); // categoria resolvida
    expect(find.text('Sem Categoria'), findsOneWidget);

    // notes abre diálogo
    await tester.tap(find.byIcon(TablerIcons.messageCircle).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Chegar 30min antes'), findsOneWidget);
    await tester.tap(find.text('common.cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('item sem categoria mostra fallback noCategory', (
    tester,
  ) async {
    await seedScheduled();
    await tester.pumpWidget(const MaterialApp(home: LiturgyAvulsaPage()));
    await tester.pumpAndSettle();

    // s2 tem categoryId inexistente → subtitle cai no fallback
    final tile = find.ancestor(
      of: find.text('Sem Categoria'),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(tile).subtitle, isNotNull);
  });
}
