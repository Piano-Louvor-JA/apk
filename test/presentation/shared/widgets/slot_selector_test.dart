
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/slot_selector.dart';

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

  testWidgets('um único slot → seletor oculto', (tester) async {
    PalcoOrchestrator.instance.addSlot(
      id: 'a',
      label: 'TV A',
      persist: false,
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SlotSelector())),
    );
    await tester.pump();

    expect(find.text('TELA ATIVA'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('modo espelho ativo mostra chip Espelhado e clearMirror volta', (
    tester,
  ) async {
    final orch = PalcoOrchestrator.instance;
    orch.addSlot(id: 'a', label: 'TV A', persist: false);
    orch.addSlot(id: 'b', label: 'TV B', persist: false);
    orch.toggleMirror({'a', 'b'});

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SlotSelector())),
    );
    await tester.pump();

    expect(orch.isMirrorMode, isTrue);
    expect(find.text('Espelhado'), findsOneWidget);

    await tester.tap(find.text('Espelhado'));
    await tester.pump();
    expect(orch.isMirrorMode, isFalse);
  });

  testWidgets('chip off desabilitado não muda slot ativo', (tester) async {
    final orch = PalcoOrchestrator.instance;
    orch.addSlot(id: 'a', label: 'TV A', persist: false);
    orch.addSlot(id: 'b', label: 'TV B', persist: false);
    orch.setActiveSlot('a');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SlotSelector())),
    );
    await tester.pump();

    expect(find.text('off'), findsNWidgets(2));
    await tester.tap(find.text('off').first);
    await tester.pump();
    expect(orch.activeSlotId, 'a');
  });
}
