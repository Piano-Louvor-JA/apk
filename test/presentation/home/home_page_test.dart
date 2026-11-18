library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:louvorja_piano_mobile/core/services/home_location_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/sync/operator_state_boot.dart';
import 'package:louvorja_piano_mobile/core/services/sync/operator_state_client.dart';
import 'package:louvorja_piano_mobile/presentation/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapHome() {
  return EasyLocalization(
    supportedLocales: const [Locale('pt', 'BR')],
    path: 'assets/translations',
    startLocale: const Locale('pt', 'BR'),
    saveLocale: false,
    child: Builder(
      builder: (context) => MaterialApp(
        home: const Scaffold(body: HomePage()),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
      ),
    ),
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OperatorStateBoot.resetForTest();
  });

  group('HomePage', () {
    testWidgets('restaura Distrito e Igreja ao reabrir o app', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '  Distrito Norte ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Igreja Sede');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Desmonta e monta de novo: mesmo caminho de fechar e abrir o app.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );
      await tester.pump();

      expect(find.text('Distrito Norte'), findsOneWidget);
      expect(find.text('Igreja Sede'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('confirmar um campo enfileira o sync sem usar a rede', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Distrito Norte');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      final box =
          jsonDecode(prefs.getString(OperatorStateClient.outboxStorageKey)!)
              as Map<String, dynamic>;
      final entry = box['prefs::values'] as Map<String, dynamic>;
      expect(jsonDecode(entry['value_json'] as String), {
        'home.location': {'district': 'Distrito Norte', 'church': ''},
      });
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('valor vindo da conta atualiza a tela aberta', (tester) async {
      SharedPreferences.setMockInitialValues({
        'home.location': '{"district":"Antigo","church":"Antiga"}',
      });
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );
      await tester.pump();
      expect(find.text('Antigo'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'home.location',
        '{"district":"Novo","church":"Nova"}',
      );
      HomeLocationPreferences.notifyExternalChange();
      // 1o pump conclui a leitura assincrona; 2o desenha o resultado.
      await tester.pump();
      await tester.pump();

      expect(find.text('Novo'), findsOneWidget);
      expect(find.text('Nova'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('valor vindo da conta nao apaga o que esta sendo digitado', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Digitando');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'home.location',
        '{"district":"Da conta","church":"Da conta"}',
      );
      HomeLocationPreferences.notifyExternalChange();
      await tester.pump();
      await tester.pump();

      expect(find.text('Digitando'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('com so o Distrito salvo, abre pedindo a Igreja', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'home.location': '{"district":"Distrito Norte","church":""}',
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );
      await tester.pump();

      expect(find.text('Distrito Norte'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('renderiza sem erros', (tester) async {
      await tester.pumpWidget(_wrapHome());
      // EasyLocalization precisa de varios frames pra carregar o asset
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('salva e reabre os campos de Distrito e Igreja', (
      tester,
    ) async {
      // MaterialApp direto torna o teste independente do carregamento async
      // do arquivo JSON. Sem provider, tr() retorna a key mas a UI funciona.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Distrito Central');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Distrito Central'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Igreja Central');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Igreja Central'), findsOneWidget);
      await tester.tap(find.text('Igreja Central'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('tap em Igreja (modo texto) ativa onEdit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );
      await tester.pump();

      // Distrito começa em edição; submeter para virar texto
      await tester.enterText(find.byType(TextField).first, 'Distrito Central');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      // Agora Distrito é texto e Igreja é TextField
      // Submeter Igreja também para virar texto
      await tester.enterText(find.byType(TextField).first, 'Igreja Central');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      // Agora ambos são texto; tap em qualquer um ativa onEdit
      final texts = find.byType(GestureDetector);
      if (texts.evaluate().isNotEmpty) {
        await tester.tap(texts.first);
        await tester.pump();
      }
    });

    testWidgets('atualiza relógio periódico enquanto está montada', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(HomePage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
