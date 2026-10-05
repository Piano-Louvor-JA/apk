/// Identidade de plataforma do cliente — padrão da org (X-Client-Platform).
///
/// Headers pra injetar em todo Dio (BaseOptions.headers) — a API usa isso
/// pra telemetria por tipo de acesso (app/web/apk/palco).
///
/// Valores: apk-android / apk-ios (detectado via dart:io Platform).
library;

import 'dart:io' show Platform;

const String kClientPlatformHeader = 'X-Client-Platform';
const String kClientVersionHeader = 'X-Client-Version';

/// apk-android ou apk-ios.
String clientPlatform() =>
    Platform.isIOS ? 'apk-ios' : 'apk-android';

/// Headers prontos pro spread nos BaseOptions:
/// `headers: {'Api-Token': token, ...clientPlatformHeaders()}`
Map<String, String> clientPlatformHeaders({String? version}) => {
      kClientPlatformHeader: clientPlatform(),
      if (version != null && version.isNotEmpty)
        kClientVersionHeader: version,
    };
