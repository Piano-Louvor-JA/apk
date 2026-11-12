import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/presentation/tools/tools_page.dart';

/// Card Conexões: agrega Transmissão, Conectar monitor e Palco.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder card(String name) => find.byKey(Key('tool-card-$name'));

  testWidgets('galeria mostra Conexões e esconde os três cards agregados', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ToolsPage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(card('connections'), 200);
    expect(card('connections'), findsOneWidget);
    for (final name in ['transmission', 'desktopMonitors', 'palco']) {
      expect(card(name), findsNothing);
    }
  });

  testWidgets('Conexões abre a grade com os três e o voltar retorna', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ToolsPage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(card('connections'), 200);
    await tester.ensureVisible(card('connections'));
    await tester.pumpAndSettle();
    await tester.tap(card('connections'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tools-connections-back')), findsOneWidget);
    for (final name in ['transmission', 'desktopMonitors', 'palco']) {
      expect(card(name), findsOneWidget);
    }
    expect(card('bible'), findsNothing);

    await tester.tap(find.byKey(const Key('tools-connections-back')));
    await tester.pumpAndSettle();
    expect(find.text('tools.title'), findsOneWidget);
    expect(find.byKey(const Key('tools-connections-back')), findsNothing);
    expect(card('palco'), findsNothing);
  });
}
