library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/settings/widgets/remote/remote_section.dart';

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

  testWidgets('renderiza a seção e os dois fluxos de conexão', (tester) async {
    await pumpSection(tester);
    expect(find.byType(RemoteSection), findsOneWidget);
    expect(find.byKey(const Key('remote-host')), findsOneWidget);
    expect(find.byKey(const Key('remote-connect')), findsOneWidget);
    expect(find.byKey(const Key('remote-weblink')), findsOneWidget);
  });

  testWidgets('Conectar fica desabilitado sem IP:porta', (tester) async {
    await pumpSection(tester);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('remote-connect')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('IP:porta válido habilita Conectar; valor inválido não', (
    tester,
  ) async {
    await pumpSection(tester);
    await tester.enterText(
      find.byKey(const Key('remote-host')),
      '192.168.1.50:7070',
    );
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('remote-connect')))
          .onPressed,
      isNotNull,
    );

    await tester.enterText(find.byKey(const Key('remote-host')), 'abc');
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('remote-connect')))
          .onPressed,
      isNull,
    );
  });
}
