// Entry point do LouvorJA PIANO Mobile.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/services/bundle/bundle_sync_boot.dart';
import 'core/services/media_state_mirror.dart';
import 'core/services/onboarding_preferences.dart';
import 'core/services/offline_status.dart';
import 'core/services/settings_controller.dart';
import 'core/services/sync/operator_state_boot.dart';
import 'core/services/sync/operator_state_client.dart';
import 'core/services/telemetry/heartbeat.dart';
import 'core/telemetry/telemetry.dart';
import 'data/datasources/remote/telemetry_api_impl.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
  }

  // App operador: fixar em portrait (nao faz sentido landscape no celular)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  // Telemetria de dispositivos: SharedPreferences vazias antes de qualquer
  // gravacao = instalacao nova → assistente completo na Home (cor, animacao,
  // distrito/igreja). Quem ja usava ve so distrito/igreja, se faltar.
  if (prefs.getKeys().isEmpty) {
    await OnboardingPreferences.markFreshInstall();
  }
  final settings = SettingsController(
    outboxHook: (key, value) =>
        unawaited(OperatorStateBoot.enqueuePrefsChange(prefs, key, value)),
  );
  // Tema precisa estar pronto antes da Splash Flutter montar. SharedPreferences
  // é local/rápido e evita um flash escuro quando o usuário salvou tema claro.
  await settings.loadSettings();
  // O pull recarrega o controller sem chamar setters/enfileirar novamente.
  OperatorStateBoot.client(prefs, onApplied: settings.loadSettings);
  OperatorStateClient.onEnqueued = OperatorStateBoot.scheduleFlush;

  // sync v2 (apk#107): flush no boot — a fila pendente sobe quando há sessão
  // e o pull da resposta aplica LWW (agendados + prefs). Sem rede/sessão a
  // fila fica íntegra pra próxima tentativa.
  unawaited(OperatorStateBoot.flushOnBoot(prefs));

  // Bundle-first (SPEC piano-bundle-sync v1.2.0): catálogo+Bíblia por ZIP
  // condicional (manifest digest/24h). Flush unawaited — o boot não espera
  // rede; snapshots aplicados servem offline e o legado item-a-item segue
  // como fallback (RF-03/04/06). Storage: <documents>/bundle.
  if (!kIsWeb) {
    unawaited(
      BundleSyncBoot.flushOnBoot(await getApplicationDocumentsDirectory()),
    );
  }
  // SPEC 7 (apk#92): quando a rede volta, a outbox sobe sem ação do usuário.
  unawaited(offlineStatus.start());
  OperatorStateBoot.bindSyncRetry(
    prefs,
    offlineStream: offlineStatus.onOfflineChanged,
  );

  // SPEC media-service (apk#132 follow-up): espelho player → MediaSession.
  // Notificação MediaStyle, lock screen e barra do PiP leem a MESMA sessão
  // (padrão YouTube/Spotify). Sem isso a barra nativa nasce com estado
  // congelado e nenhum controle tem efeito (evidência A15 15:57).
  MediaStateMirror.start();

  await runWithTelemetry(() async {
    runApp(
      ChangeNotifierProvider.value(
        value: settings,
        child: EasyLocalization(
          supportedLocales: const [
            Locale('pt', 'BR'),
            Locale('en'),
            Locale('es'),
            Locale('ru'),
            Locale('uk'),
            Locale('fr'),
            Locale('ja'),
            Locale('ko'),
            Locale('zh'),
            Locale('tr'),
            Locale('ar'),
            Locale('hi'),
          ],
          path: 'assets/translations',
          fallbackLocale: const Locale('pt', 'BR'),
          // Portugues por padrao, independente do idioma do OS. A escolha feita
          // nas Configuracoes fica salva e tem prioridade sobre este valor.
          startLocale: const Locale('pt', 'BR'),
          useOnlyLangCode: false,
          child: const LouvorjaApp(),
        ),
      ),
    );
    // Sinal de "online" (POST /v1/telemetry/heartbeat) a cada 5 min com o
    // app em primeiro plano. Sempre ligado; falha e silenciosa.
    if (!kIsWeb) {
      HeartbeatLoop(
        api: TelemetryApiImpl(),
        builder: HeartbeatBodyBuilder(),
      ).start();
    }
  });
}
