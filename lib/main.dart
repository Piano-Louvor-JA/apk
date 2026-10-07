// Entry point do LouvorJA PIANO Mobile.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/services/media_state_mirror.dart';
import 'core/services/settings_controller.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
  }

  // App operador: fixar em portrait (nao faz sentido landscape no celular)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final settings = SettingsController();
  // Tema precisa estar pronto antes da Splash Flutter montar. SharedPreferences
  // é local/rápido e evita um flash escuro quando o usuário salvou tema claro.
  await settings.loadSettings();

  // SPEC media-service (apk#132 follow-up): espelho player → MediaSession.
  // Notificação MediaStyle, lock screen e barra do PiP leem a MESMA sessão
  // (padrão YouTube/Spotify). Sem isso a barra nativa nasce com estado
  // congelado e nenhum controle tem efeito (evidência A15 15:57).
  MediaStateMirror.start();

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
