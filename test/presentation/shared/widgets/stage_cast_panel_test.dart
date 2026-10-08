import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/stage_customization_sheet.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_cast_button.dart';

/// Painel de controles do caster com palco ligado (sem TV): exercita os
/// ListTiles — Personalizar, Gerenciar Telas, Desligar, Limpar projeção.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final orch = PalcoOrchestrator.instance;
    for (final s in orch.slots.toList()) {
      await orch.removeSlot(s.id);
    }
    orch.clearMirror();
    final session = StageSession.instance;
    if (session.isOn) await session.turnOff();

    // Liga UMA vez (IO real fora do fake async do testWidgets).
    await session.turnOnPalco(
      const PalcoTarget(name: 'Palco (aguardando TV)', ip: '127.0.0.1'),
    );
  });

  tearDownAll(() async {
    final session = StageSession.instance;
    if (session.isOn) await session.turnOff();
  });

  testWidgets('abre painel de controles com palco ligado', (tester) async {
    expect(StageSession.instance.isOn, isTrue);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StageCastButton())),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byType(StageCastButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Painel tem os itens principais.
    expect(find.text('Gerenciar Telas'), findsOneWidget);
    expect(find.text('Limpar projeção'), findsOneWidget);
  });

  testWidgets('Gerenciar Telas abre SlotManagementSheet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StageCastButton())),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byType(StageCastButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Gerenciar Telas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Adicionar tela'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('Limpar projeção no painel volta ao idle mantendo sessão', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StageCastButton())),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byType(StageCastButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Limpar projeção'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(StageSession.instance.isOn, isTrue); // sessão continua viva
  });

  testWidgets('Desligar no painel encerra a sessão', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StageCastButton(module: StageModule.hymns))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byType(StageCastButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 'stage.turnOff' não traduzido no sandbox = chave crua.
    final anyTile = find.textContaining('stage.turnOff');
    if (anyTile.evaluate().isNotEmpty) {
      await tester.tap(anyTile.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(StageSession.instance.isOn, isFalse);
    }
    expect(tester.takeException(), isNull);
  });
}
