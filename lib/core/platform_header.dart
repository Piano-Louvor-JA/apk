/// Identidade de plataforma do cliente — padrão da org (X-Client-Platform).
///
/// Headers pra injetar em todo Dio (BaseOptions.headers) — a API usa isso
/// pra telemetria por tipo de acesso (app/web/apk/palco).
///
/// Valores: apk-android / apk-ios (detectado pela plataforma do Flutter).
library;

import 'package:flutter/foundation.dart';

const String kClientPlatformHeader = 'X-Client-Platform';
const String kClientVersionHeader = 'X-Client-Version';

/// apk-android ou apk-ios.
String clientPlatform() =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'apk-ios' : 'apk-android';

/// Headers prontos pro spread nos BaseOptions:
/// `headers: {'Api-Token': token, ...clientPlatformHeaders()}`
Map<String, String> clientPlatformHeaders({String? version}) => {
  kClientPlatformHeader: clientPlatform(),
  if (version != null && version.isNotEmpty) kClientVersionHeader: version,
};
