import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/pip_minimal_overlay.dart';

/// SPEC piano-a11y v1.0.0 (RF-1): controles do PiP devem ter rótulo
/// acessível (tooltip → Semantics) para TalkBack.
///
/// O PipMinimalOverlay usa streams do player real; para o teste de
/// semantics não precisamos de áudio — basta montar o widget e verificar
/// que os IconButtons possuem tooltip não-vazio. Se um tooltip sumir
/// (regressão), este teste quebra.
void main() {
  // PipMinimalOverlay toca HymnAudioPlayer.instance via adapter estático.
  // Em ambiente de teste o player é lazy e as streams podem não emitir;
  // pumpWidget com wrap básico é suficiente para inspecionar a árvore.
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PiP: todos os IconButtons possuem tooltip acessível', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PipMinimalOverlay())),
    );
    await tester.pump();

    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons.length, greaterThanOrEqualTo(3));

    for (final button in buttons) {
      expect(
        button.tooltip,
        isNotNull,
        reason: 'IconButton sem tooltip não é anunciado pelo TalkBack',
      );
      expect(button.tooltip!, isNotEmpty);
    }
  });
}
