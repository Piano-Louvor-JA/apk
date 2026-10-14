import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/presentation/remote/remote_control_tool_page.dart';

/// Smoke do controle remoto sem sessão: tabs renderizam, estado idle
/// ("não conectado") sem crash. RemoteSession.instance em modo idle não
/// abre sockets (connect só sob demanda).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RemoteControlToolPage renderiza em modo idle sem crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RemoteControlToolPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('desconectar em modo idle mantém página estável', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RemoteControlToolPage()),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Botão existe mesmo sem sessão; disconnect precisa ser idempotente.
    await tester.tap(find.byTooltip('remote.disconnect'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(TabBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('modo idle sem sessão não mostra TabBar (estado vazio)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RemoteControlToolPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Sem alvo conectado, a página mostra estado vazio (sem controles).
    expect(find.byType(TabBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
