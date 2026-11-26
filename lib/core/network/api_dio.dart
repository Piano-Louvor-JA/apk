import 'package:dio/dio.dart';

import 'package:louvorja_piano_mobile/core/constants/app_version.dart';
import 'package:louvorja_piano_mobile/core/platform_header.dart';

const _partnerHeader = 'X-Partner-Key';
const _productionHost = 'api.pianolouvorja.com.br';
const _stagingHost = 'api-stg.pianolouvorja.com.br';

/// A chave pertence à API Piano, nunca ao upstream, CDN ou autenticação Google.
bool isPianoApiUri(Uri uri) {
  if (!uri.hasAuthority || uri.userInfo.isNotEmpty) return false;
  final local = uri.host == 'localhost' || uri.host == '127.0.0.1';
  return (uri.scheme == 'https' || (local && uri.scheme == 'http')) &&
      (local || uri.host == _productionHost || uri.host == _stagingHost);
}

/// Seleção pela URL efetiva impede misturar STG/prod em chamadas e fallbacks.
/// PARTNER_KEY sobrescreve o perfil, como no desktop; sem chave, acesso atual.
String partnerKeyForUri(
  Uri uri, {
  String override = const String.fromEnvironment('PARTNER_KEY'),
  String stagingKey = const String.fromEnvironment('PARTNER_KEY_STG'),
  String productionKey = const String.fromEnvironment('PARTNER_KEY_PROD'),
}) {
  if (!isPianoApiUri(uri)) return '';
  final key = override.trim().isNotEmpty
      ? override.trim()
      : (uri.host == _productionHost ? productionKey : stagingKey).trim();
  return key.startsWith('plj_') ? key : '';
}

/// Cliente comum de rede. Resolve identidade por requisição, inclusive downloads
/// e URLs absolutas, sem alterar Api-Token ou Authorization já existentes.
Dio createApiDio({
  BaseOptions? options,
  String? partnerKey,
  Future<String> Function()? version,
}) {
  final dio = Dio(options);
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (isPianoApiUri(options.uri)) {
          final clientVersion = await (version ?? () => AppVersion.version)();
          final headers = clientPlatformHeaders(version: clientVersion);
          final key = partnerKey == null
              ? partnerKeyForUri(options.uri)
              : partnerKeyForUri(
                  options.uri,
                  override: partnerKey,
                  stagingKey: '',
                  productionKey: '',
                );
          if (key.isNotEmpty) headers[_partnerHeader] = key;
          for (final entry in headers.entries) {
            final exists = options.headers.keys.any(
              (name) => name.toLowerCase() == entry.key.toLowerCase(),
            );
            if (!exists) options.headers[entry.key] = entry.value;
          }
        }
        handler.next(options);
      },
    ),
  );
  return dio;
}
