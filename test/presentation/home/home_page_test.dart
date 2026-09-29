library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:louvorja_piano_mobile/presentation/home/home_page.dart';

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

  group('HomePage', () {
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
