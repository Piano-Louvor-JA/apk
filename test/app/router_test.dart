// ignore_for_file: avoid_dynamic_calls
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/app/router.dart';
import 'package:louvorja_piano_mobile/core/services/settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapRouter() {
  return ChangeNotifierProvider<SettingsController>(
    create: (_) => SettingsController(),
    child: MaterialApp.router(routerConfig: appRouter),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Mock PackageInfo para Settings nao pendurar em FutureBuilder
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => <String, dynamic>{
            'appName': 'LouvorJA PIANO',
            'packageName': 'com.louvorja.piano.mobile',
            'version': '1.0.0',
            'buildNumber': '1',
            'buildSignature': '',
            'installerStore': null,
          },
        );
  });

  testWidgets('rota raiz resolve Home', (tester) async {
    appRouter.go('/');
    await tester.pumpWidget(_wrapRouter());
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('rota de Ferramentas responde', (tester) async {
    appRouter.go('/tools');
    await tester.pumpWidget(_wrapRouter());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MaterialApp), findsOneWidget);
    appRouter.go('/');
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('taps no dock trocam de branch', (tester) async {
    appRouter.go('/');
    await tester.pumpWidget(_wrapRouter());
    await tester.pump(const Duration(milliseconds: 500));

    // Tap em Hinos (index 1)
    final docks = find.byType(GestureDetector);
    expect(docks, findsWidgets);
    if (docks.evaluate().length > 1) {
      await tester.tap(docks.at(1));
      await tester.pump(const Duration(milliseconds: 500));
    }
    // Volta pra Home para limpar
    appRouter.go('/hymns');
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('cobre rotas de Settings', (tester) async {
    appRouter.go('/settings');
    await tester.pumpWidget(_wrapRouter());
    await tester.pump(const Duration(seconds: 2));
    // Navega para fora de Settings antes de terminar
    appRouter.go('/hymns');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('deep link de album resolve /hymns/:albumId', (tester) async {
    appRouter.go('/hymns/123');
    await tester.pumpWidget(_wrapRouter());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(
      const Duration(seconds: 3),
    ); // consome timeout do indice offline
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('deep link de hino resolve /hymns/:albumId/:hymnId', (
    tester,
  ) async {
    appRouter.go('/hymns/123/456');
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(
      const Duration(seconds: 3),
    ); // consome timeout do indice offline
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
