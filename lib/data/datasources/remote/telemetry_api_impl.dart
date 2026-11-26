library;

import 'package:dio/dio.dart';

import '../../../core/constants/api_config.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/network/api_dio.dart';
import '../../../core/platform_header.dart';
import '../../../core/services/telemetry/heartbeat.dart';
import '../../../domain/repositories/telemetry_api_client.dart';

/// Implementacao Dio do [TelemetryApiClient].
///
/// Envia para o primeiro host da API Piano que responder (mesma cascata do
/// catalogo, `ApiConfig.databaseUrls()`). Erro de rede ou 5xx passa ao
/// proximo host; 4xx nao insiste. Headers X-Client-* como o resto do app.
class TelemetryApiImpl implements TelemetryApiClient {
  final List<String> _urls;
  final Dio _dio;
  final Future<String> Function() _version;

  TelemetryApiImpl({
    List<String>? baseUrls,
    Dio? dio,
    Future<String> Function()? version,
  }) : _urls = heartbeatUrlsFrom(baseUrls ?? ApiConfig.databaseUrls()),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 8),
             ),
           ),
       _version = version ?? (() => AppVersion.version);

  List<String> get urls => List.unmodifiable(_urls);

  @override
  Future<bool> sendHeartbeat(Map<String, Object?> body) async {
    final headers = clientPlatformHeaders(version: await _version());
    for (final url in _urls) {
      try {
        final partnerKey = partnerKeyForUri(Uri.parse(url));
        final res = await _dio.post<void>(
          url,
          data: body,
          options: Options(
            headers: {
              ...headers,
              if (partnerKey.isNotEmpty) 'X-Partner-Key': partnerKey,
            },
            contentType: Headers.jsonContentType,
          ),
        );
        final status = res.statusCode ?? 0;
        if (status >= 200 && status < 300) return true;
        if (status < 500) return false;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status != null && status < 500) return false;
        // rede/timeout/5xx: tenta o proximo host
      }
    }
    return false;
  }
}
