import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/slot_management_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final orch = PalcoOrchestrator.instance;
    for (final s in orch.slots.toList()) {
      await orch.removeSlot(s.id);
    }
    orch.clearMirror();
  });

  testWidgets('SlotManagementSheet renderiza slot principal e botão adicionar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SlotManagementSheet())),
    );
    await tester.pump(); // initState + loadStoredConfig assíncrono
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Gerenciar Telas'), findsOneWidget);
    expect(find.text('Adicionar tela'), findsOneWidget);
    expect(find.text('Adicionar tela'), findsOneWidget);
  });

  testWidgets('adicionar tela via dialog cria slot novo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SlotManagementSheet())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Adicionar tela'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Lateral Esq');
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(
      PalcoOrchestrator.instance.slots.any((s) => s.label == 'Lateral Esq'),
      isTrue,
    );
  });

  testWidgets('nome vazio no dialog não cria slot', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SlotManagementSheet())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final before = PalcoOrchestrator.instance.slots.length;

    await tester.tap(find.text('Adicionar tela'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(PalcoOrchestrator.instance.slots.length, before);
  });

  testWidgets('remover tela exclui slot extra', (tester) async {
    PalcoOrchestrator.instance.addSlot(id: 'principal', label: 'Principal', persist: false);
    PalcoOrchestrator.instance.addSlot(id: 'extra', label: 'Extra', persist: false);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SlotManagementSheet())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Expande o tile do slot extra e remove.
    await tester.tap(find.text('Extra'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Remover tela'), findsOneWidget);
    await tester.tap(find.text('Remover tela'));
    await tester.pumpAndSettle();

    expect(
      PalcoOrchestrator.instance.slots.any((s) => s.id == 'extra'),
      isFalse,
    );
  });
}
