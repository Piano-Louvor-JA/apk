import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/presentation/shared/widgets/palco_auto_connect_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PalcoAutoConnectSheet abre em modo scanning sem crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PalcoAutoConnectSheet())),
    );
    // pump limitado: _start roda scan real (mDNS/DIAL) em background —
    // nunca pumpAndSettle (spinner some só depois do scan de rede).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Sem crash — spinner ou estado pós-scan, ambos válidos no sandbox.
    expect(tester.takeException(), isNull);
  });

}
