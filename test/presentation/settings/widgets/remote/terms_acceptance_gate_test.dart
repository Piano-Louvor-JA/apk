// Gate de termos no fluxo QR (apk#95): os termos devem ser aceitáveis e
// dispensáveis ANTES do conectar, sem sobreposição que bloqueie o botão.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/terms_acceptance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHost(
    WidgetTester tester, {
    double height = 800,
    Future<bool> Function(BuildContext)? action,
  }) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('pt', 'BR')],
        path: 'assets/translations',
        fallbackLocale: const Locale('pt', 'BR'),
        startLocale: const Locale('pt', 'BR'),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: SizedBox(
                height: height,
                width: 400,
                child: Center(
                  child: FilledButton(
                    key: const Key('open-gate'),
                    onPressed: () async {
                      final ok = await (action ?? ensureTermsAccepted)(
                        context,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('gate=$ok')),
                        );
                      }
                    },
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('termos NAO aceitos: sheet abre com Aceitar e dispensar', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open-gate')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('terms-accept')), findsOneWidget);
    expect(find.byKey(const Key('terms-dismiss')), findsOneWidget);
  });

  testWidgets('Aceitar persiste a aceitação e retorna true', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open-gate')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('terms-accept')));
    await tester.pumpAndSettle();

    expect(find.text('gate=true'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('terms_accepted_at'), isNotNull);
    // aceito: próxima chamada NÃO abre sheet
    final ctx = tester.state(find.byType(Scaffold)).context;
    expect(await TermsAcceptance.instance.isAccepted(), isTrue);
    expect(await ensureTermsAccepted(ctx), isTrue);
  });

  testWidgets('Dispensar NÃO persiste e retorna false (dispensável)', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open-gate')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('terms-dismiss')));
    await tester.pumpAndSettle();

    expect(find.text('gate=false'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('terms_accepted_at'), isNull);
  });

  testWidgets('tela pequena: botões ficam acessíveis (scroll, sem overlap)', (
    tester,
  ) async {
    await pumpHost(tester, height: 420);
    await tester.tap(find.byKey(const Key('open-gate')));
    await tester.pumpAndSettle();

    // botão Aceitar visível e taptável mesmo em tela baixa
    await tester.ensureVisible(find.byKey(const Key('terms-accept')));
    await tester.tap(find.byKey(const Key('terms-accept')));
    await tester.pumpAndSettle();
    expect(find.text('gate=true'), findsOneWidget);
  });

  testWidgets('termos JÁ aceitos: nada abre, conecta direto', (tester) async {
    SharedPreferences.setMockInitialValues({
      'terms_accepted_at': 'x',
      'terms_version': TermsAcceptance.currentVersion,
    });
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open-gate')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('terms-sheet')), findsNothing);
    expect(find.text('gate=true'), findsOneWidget);
  });
}
