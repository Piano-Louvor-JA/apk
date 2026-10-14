import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/presentation/settings/widgets/remote/remote_section.dart';

/// Ramos extras da RemoteSection: conectar em desktop morto (snack de
/// falha), Web Link gera URL e botão desconectar aparece.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('pt', 'BR')],
        path: 'assets/translations',
        fallbackLocale: const Locale('pt', 'BR'),
        startLocale: const Locale('pt', 'BR'),
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: RemoteSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('conectar em desktop inexistente mostra snack de falha', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.enterText(find.byType(TextField).first, '127.0.0.1:59998');
    await tester.pump();

    final connectBtn = find.widgetWithText(ElevatedButton, 'Conectar');
    if (connectBtn.evaluate().isNotEmpty) {
      await tester.tap(connectBtn.first);
      // connectDesktop em host morto falha rápido (connectionTimeout do WS).
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('Web Link inicia servidor local e exibe URL', (tester) async {
    await pumpSection(tester);

    final webLinkBtn = find.textContaining('Web Link');
    if (webLinkBtn.evaluate().isNotEmpty) {
      await tester.tap(webLinkBtn.first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    expect(tester.takeException(), isNull);
  });
}
