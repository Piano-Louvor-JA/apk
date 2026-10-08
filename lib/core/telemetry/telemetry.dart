import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Telemetria de erros → Glitchtip self-hosted (VM Oracle).
///
/// - DSN via `--dart-define=TELEMETRIA_DSN=...` (build oficial). Sem DSN = telemetria
///   desligada e NENHUM request sai do app (dev e builds locais ficam mudos).
/// - `runZonedGuarded` + `FlutterError.onError`: nenhum erro morre no console.
/// - Falha de init nunca derruba o app.
const _telemetryDsn = String.fromEnvironment('TELEMETRIA_DSN', defaultValue: '');

/// Executa [appBoot] dentro da zona de telemetria (quando habilitada).
Future<void> runWithTelemetry(Future<void> Function() appBoot) async {
  if (_telemetryDsn.isEmpty) {
    await appBoot();
    return;
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = _telemetryDsn;
      options.tracesSampleRate = 0; // sem performance tracing — só erros
      options.sendDefaultPii = false;
      options.environment = kReleaseMode ? 'production' : 'development';
      options.beforeSend = (event, hint) {
        // só erro/fatal sai da máquina
        final level = event.level;
        if (level != null && (level == SentryLevel.info || level == SentryLevel.debug)) {
          return null;
        }
        return event;
      };
    },
    // init falhou → app segue sem telemetria
    appRunner: appBoot,
  );
}

/// Captura um erro fora da zona (callbacks assíncronos soltos); nunca lança.
void reportTelemetryError(Object error, {Map<String, dynamic>? context}) {
  if (_telemetryDsn.isEmpty) return;
  try {
    Sentry.captureException(error, stackTrace: StackTrace.current, hint: null);
    if (context != null && context.isNotEmpty) {
      Sentry.addBreadcrumb(Breadcrumb(message: 'context: $context', level: SentryLevel.error));
    }
  } catch (_) {
    // telemetria nunca é motivo de quebra
  }
}
