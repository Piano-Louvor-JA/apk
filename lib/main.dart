// Entry point do LouvorJA PIANO Mobile.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/services/offline_status.dart';
import 'core/services/settings_controller.dart';
import 'core/services/sync/operator_state_boot.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
  }

  // App operador: fixar em portrait (nao faz sentido landscape no celular)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(
    outboxHook: (key, value) =>
        unawaited(OperatorStateBoot.enqueuePrefsChange(prefs, key, value)),
  );
  // Tema precisa estar pronto antes da Splash Flutter montar. SharedPreferences
  // é local/rápido e evita um flash escuro quando o usuário salvou tema claro.
  await settings.loadSettings();

  // sync v2 (apk#107): flush no boot — a fila pendente sobe quando há sessão
  // e o pull da resposta aplica LWW (agendados + prefs). Sem rede/sessão a
  // fila fica íntegra pra próxima tentativa.
  unawaited(OperatorStateBoot.flushOnBoot(prefs));
  // SPEC 7 (apk#92): quando a rede volta, a outbox sobe sem ação do usuário.
  unawaited(offlineStatus.start());
  OperatorStateBoot.bindSyncRetry(prefs, offlineStream: offlineStatus.onOfflineChanged);

  runApp(
    ChangeNotifierProvider.value(
      value: settings,
      child: EasyLocalization(
        supportedLocales: const [
          Locale('pt', 'BR'),
          Locale('en'),
          Locale('es'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('pt', 'BR'),
        // Segue o idioma do OS por padrao. Usuario pode trocar nas Configuracoes.
        useOnlyLangCode: false,
        child: const LouvorjaApp(),
      ),
    ),
  );
}
