library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:louvorja_piano_mobile/app/app.dart';

/// Integration test: app completo com splash + navegação entre todas as tabs.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() {
    // Navegacao: assistente de primeira inicializacao ja concluido (senao a
    // etapa de distrito/igreja abre por cima da Home e bloqueia o dock).
    SharedPreferences.setMockInitialValues({
      'onboarding.state': '{"completedAt":"2026-01-01T00:00:00Z"}',
      'home.location': '{"district":"Distrito E2E","church":"Igreja E2E"}',
    });
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return <String, dynamic>{
        'appName': 'LouvorJA PIANO',
        'packageName': 'com.louvorja.piano.mobile',
        'version': '0.1.0-alpha',
        'buildNumber': '1',
        'buildSignature': '',
        'installerStore': null,
      };
    });
  });

  group('E2E: App init + navegação', () {
    testWidgets('mostra splash ao iniciar', (tester) async {
      await tester.pumpWidget(const LouvorjaApp());
      await tester.pump();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('splash desaparece e app principal aparece', (tester) async {
      await tester.pumpWidget(const LouvorjaApp());
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));

      expect(find.text('LouvorJA'), findsOneWidget);
    });

    testWidgets('5 labels de navegação existem após boot', (tester) async {
      await tester.pumpWidget(const LouvorjaApp());
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Hinos'), findsWidgets);
      expect(find.text('Liturgia'), findsWidgets);
      expect(find.text('Bíblia'), findsWidgets);
      expect(find.text('Mais'), findsWidgets);
    });

    testWidgets('navegação: Início -> Hinos -> Bíblia -> Mais -> Início',
        (tester) async {
      await tester.pumpWidget(const LouvorjaApp());
      await tester.pump(const Duration(seconds: 5));

      // Início ativo
      expect(find.text('LouvorJA'), findsOneWidget);

      // -> Hinos
      await tester.tap(find.text('Hinos').first);
      await tester.pumpAndSettle();

      // -> Bíblia
      await tester.tap(find.text('Bíblia').first);
      await tester.pumpAndSettle();

      // -> Mais
      await tester.tap(find.text('Mais').first);
      await tester.pumpAndSettle();

      // -> Início
      await tester.tap(find.text('Início'));
      await tester.pumpAndSettle();

      expect(find.text('LouvorJA'), findsOneWidget);
    });
  });
}
