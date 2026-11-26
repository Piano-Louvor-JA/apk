library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:louvorja_piano_mobile/core/services/home_location_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/onboarding_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/settings_controller.dart';
import 'package:louvorja_piano_mobile/core/services/sync/operator_state_boot.dart';
import 'package:louvorja_piano_mobile/presentation/home/home_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Assistente de primeira inicializacao no APK (paridade com o desktop).
///
/// Sem EasyLocalization: ele e um singleton global e montar de novo no mesmo
/// processo quebra a arvore (ver offline_banner_test.dart). Sem ele, `.tr()`
/// devolve a propria chave — os testes conferem as chaves; o texto de cada
/// idioma e coberto pelos testes de i18n.
Widget _wrapHome(SettingsController settings) {
  return ChangeNotifierProvider.value(
    value: settings,
    child: const MaterialApp(home: Scaffold(body: HomePage())),
  );
}

/// O logo do assistente pulsa sem parar: pumpAndSettle nunca assentaria.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester, SettingsController settings) async {
  await tester.pumpWidget(_wrapHome(settings));
  await _settle(tester);
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key) async {
  // O dialogo rola: garante o botao na tela antes de tocar.
  await tester.ensureVisible(_key(key));
  await tester.pump();
  await tester.tap(_key(key));
  await _settle(tester);
}

Future<OnboardingState> _state() async => OnboardingPreferences.load();

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OperatorStateBoot.resetForTest();
  });

  testWidgets(
    'instalacao nova: cor → animacao → distrito/igreja obrigatorios, e conclui',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding.state': '{"freshInstall":true}',
      });
      final settings = SettingsController();
      await _open(tester, settings);

      expect(_key('onboarding-dialog'), findsOneWidget);
      expect(_key('onboarding-welcome'), findsOneWidget);
      expect(find.text('ONBOARDING.WIZARDTITLE'), findsOneWidget);
      expect(_key('onboarding-step-accent'), findsOneWidget);
      expect(_key('onboarding-back'), findsNothing);

      await _tap(tester, 'onboarding-accent-teal');
      expect(settings.accent, AccentKey.teal);
      await _tap(tester, 'onboarding-primary');
      expect(_key('onboarding-step-interaction'), findsOneWidget);
      await _tap(tester, 'onboarding-interaction-mist');
      expect(settings.interaction, InteractionKey.mist);
      await _tap(tester, 'onboarding-back');
      expect(_key('onboarding-step-accent'), findsOneWidget);
      await _tap(tester, 'onboarding-primary');
      await _tap(tester, 'onboarding-primary');

      // Distrito/igreja: obrigatorios para concluir.
      expect(_key('onboarding-default'), findsNothing);
      expect(_key('onboarding-required'), findsOneWidget);
      final primary = tester.widget<FilledButton>(_key('onboarding-primary'));
      expect(primary.onPressed, isNull);

      await tester.enterText(_key('onboarding-district'), ' Bertioga ');
      await tester.enterText(_key('onboarding-church'), 'Rio da Praia');
      await tester.pump();
      expect(_key('onboarding-required'), findsNothing);
      await _tap(tester, 'onboarding-primary');
      await _settle(tester);

      expect(_key('onboarding-dialog'), findsNothing);
      final saved = await HomeLocationPreferences.load();
      expect(saved.district, 'Bertioga');
      expect(saved.church, 'Rio da Praia');
      final state = await _state();
      expect(state.completedAt, isNotNull);
      expect(state.freshInstall, isFalse);
      // A Home mostra o que o assistente gravou.
      expect(find.text('Bertioga'), findsOneWidget);
    },
  );

  testWidgets('"Usar padrao" volta laranja/dinamico e segue', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.state': '{"freshInstall":true}',
    });
    final settings = SettingsController();
    await settings.setAccent(AccentKey.rose);
    await settings.setInteraction(InteractionKey.soft);
    await _open(tester, settings);

    await _tap(tester, 'onboarding-default');
    expect(settings.accent, AccentKey.orange);
    expect(_key('onboarding-step-interaction'), findsOneWidget);
    await _tap(tester, 'onboarding-default');
    expect(settings.interaction, InteractionKey.dynamic_);
    expect(_key('onboarding-district'), findsOneWidget);
  });

  testWidgets(
    'atualizacao sem distrito/igreja: so essa etapa, com titulo de atualizacao',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'home.location': jsonEncode({'district': 'Norte', 'church': ''}),
      });
      final settings = SettingsController();
      await _open(tester, settings);

      expect(_key('onboarding-dialog'), findsOneWidget);
      expect(find.text('ONBOARDING.UPDATE.WIZARDTITLE'), findsOneWidget);
      expect(find.text('onboarding.update.title'), findsOneWidget);
      expect(find.text('onboarding.welcome.title'), findsNothing);
      expect(_key('onboarding-default'), findsNothing);
      expect(find.text('onboarding.save'), findsOneWidget);

      await tester.enterText(_key('onboarding-church'), 'Sede');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);

      expect(_key('onboarding-dialog'), findsNothing);
      final saved = await HomeLocationPreferences.load();
      expect(saved.district, 'Norte');
      expect(saved.church, 'Sede');
    },
  );

  testWidgets('quem ja preencheu nao ve assistente nem lembrete', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'home.location': jsonEncode({'district': 'Norte', 'church': 'Sede'}),
    });
    await _open(tester, SettingsController());
    expect(_key('onboarding-dialog'), findsNothing);
    expect(_key('home-location-reminder'), findsNothing);
  });

  testWidgets('lembrete da Home: "Lembrar depois" e "Nao perguntar mais"', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.state': '{"completedAt":"2026-01-01T00:00:00Z"}',
    });
    await _open(tester, SettingsController());
    expect(_key('home-location-reminder'), findsOneWidget);
    await _tap(tester, 'home-reminder-snooze');
    expect(_key('home-location-reminder'), findsNothing);
    expect((await _state()).reminderSnoozedUntil, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    SharedPreferences.setMockInitialValues({
      'onboarding.state': '{"completedAt":"2026-01-01T00:00:00Z"}',
    });
    await _open(tester, SettingsController());
    await _tap(tester, 'home-reminder-dismiss');
    expect(_key('home-location-reminder'), findsNothing);
    expect((await _state()).reminderDismissed, isTrue);
  });
}
