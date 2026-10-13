// Gate de termos no fluxo QR (apk#95): os termos devem ser aceitáveis e
// dispensáveis ANTES do conectar, sem sobreposição que bloqueie o botão.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:go_router/go_router.dart';
import 'package:louvorja_piano_mobile/presentation/settings/terms_page.dart';

import 'package:louvorja_piano_mobile/core/services/terms_acceptance.dart';

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore() : super.empty();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith(TermsAcceptance.versionKey)) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHost(
    WidgetTester tester, {
    double height = 800,
    Future<bool> Function(BuildContext)? action,
  }) async {
    await tester.binding.setSurfaceSize(Size(400, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
                      final ok = await (action ?? ensureTermsAccepted)(context);
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('gate=$ok')));
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

    expect(find.byKey(const Key('terms-accept')), findsNothing);
    expect(find.text('gate=true'), findsOneWidget);
  });
  testWidgets('versão antiga volta a solicitar aceite', (tester) async {
    SharedPreferences.setMockInitialValues({
      TermsAcceptance.acceptedAtKey: 'anterior',
      TermsAcceptance.versionKey: 'antiga',
    });
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open-gate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('terms-accept')), findsOneWidget);
    await tester.tap(find.byKey(const Key('terms-dismiss')));
    await tester.pumpAndSettle();
    expect(find.text('gate=false'), findsOneWidget);
  });

  testWidgets('falha ao salvar não autoriza continuar e permite dispensar', (
    tester,
  ) async {
    SharedPreferencesStorePlatform.instance = _FailingStore();
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open-gate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('terms-accept')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('gate=true'), findsNothing);
    expect(find.text('errors.unknown'.tr()), findsOneWidget);
    expect(find.byKey(const Key('terms-accept')), findsOneWidget);
    expect(await TermsAcceptance.instance.isAccepted(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(TermsAcceptance.acceptedAtKey), isNull);
    await tester.ensureVisible(find.byKey(const Key('terms-dismiss')));
    await tester.tap(find.byKey(const Key('terms-dismiss')));
    await tester.pumpAndSettle();
    expect(find.text('gate=false'), findsOneWidget);
  });

  testWidgets('fechar pela barreira retorna false sem aceite', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open-gate')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('gate=false'), findsOneWidget);
    expect(await TermsAcceptance.instance.isAccepted(), isFalse);
  });

  testWidgets('links abrem textos e voltar preserva o sheet de aceite', (
    tester,
  ) async {
    late BuildContext hostContext;
    final router = GoRouter(
      initialLocation: '/remote-control',
      routes: [
        GoRoute(
          path: '/remote-control',
          builder: (context, _) {
            hostContext = context;
            return Scaffold(
              body: FilledButton(
                key: const Key('open-gate'),
                onPressed: () => ensureTermsAccepted(context),
                child: const Text('go'),
              ),
            );
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(),
          routes: [
            GoRoute(
              path: 'terms',
              builder: (_, _) => const TermsPage(isPrivacy: false),
            ),
            GoRoute(
              path: 'privacy',
              builder: (_, _) => const TermsPage(isPrivacy: true),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const Key('open-gate')));
    await tester.pumpAndSettle();
    for (final key in ['settings.termsOfUse', 'settings.privacyPolicy']) {
      await tester.tap(find.text(key.tr()).last);
      await tester.pumpAndSettle();
      expect(find.byType(TermsPage), findsOneWidget);
      expect(find.byKey(const Key('terms-accept')).hitTestable(), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('terms-accept')), findsOneWidget);
      expect(await TermsAcceptance.instance.isAccepted(), isFalse);
    }
    expect(hostContext.mounted, isTrue);
  });
}
