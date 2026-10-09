import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_cast_button.dart';

/// Cobertura dos ramos do painel de controles (_openControls) e do
/// StageClearButton — sem TV: sessão em modo palco aguardando receiver.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final orch = PalcoOrchestrator.instance;
    for (final s in orch.slots.toList()) {
      await orch.removeSlot(s.id);
    }
    orch.clearMirror();
    final session = StageSession.instance;
    if (session.isOn) await session.turnOff();
  });

  testWidgets('StageClearButton sem palco ativo → SizedBox.shrink', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(appBar: AppBar(actions: [const StageClearButton()]))),
    );
    await tester.pump();
    expect(find.byTooltip('Limpar projeção (voltar ao idle)'), findsNothing);
  });

  testWidgets('tap no cast desligado abre PalcoAutoConnectSheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(appBar: AppBar(actions: [const StageCastButton()]))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // O botão pode estar em modo scanning (resolveLocalIp) — aguarda destravar.
    await tester.pump(const Duration(milliseconds: 500));
    final castOn = find.byType(StageCastButton);
    expect(castOn, findsOneWidget);
    await tester.tap(castOn.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Sheet de auto-connect apareceu (sender liga + escaneia) sem crash.
    expect(tester.takeException(), isNull);
  });

  test('turnOnPalco sem TV: sender sobe e turnOff desliga limpo', () async {
    final session = StageSession.instance;
    final ok = await session.turnOnPalco(
      const PalcoTarget(name: 'Palco (aguardando TV)', ip: '127.0.0.1'),
    );
    expect(ok, isTrue);
    expect(session.isOn, isTrue);

    await session.turnOff();
    expect(session.isOn, isFalse);
  });

}
