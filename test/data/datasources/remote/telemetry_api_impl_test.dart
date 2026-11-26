library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/telemetry_api_impl.dart';

/// Responde cada requisicao com o proximo status da lista (null = erro de rede).
Dio _dioWith(List<int?> statuses, List<RequestOptions> seen) {
  final dio = Dio();
  var i = 0;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        seen.add(options);
        final status = statuses[i++];
        if (status == null) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
          return;
        }
        final response = Response<void>(
          requestOptions: options,
          statusCode: status,
        );
        if (status >= 400) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: response,
              type: DioExceptionType.badResponse,
            ),
          );
        } else {
          handler.resolve(response);
        }
      },
    ),
  );
  return dio;
}

const _bases = [
  'https://api-stg.pianolouvorja.com.br/json_db',
  'https://api.louvorja.com.br/json_db',
  'https://api.pianolouvorja.com.br/json_db',
];

void main() {
  group('TelemetryApiImpl', () {
    test('POST JSON no primeiro host Piano com X-Client-*', () async {
      final seen = <RequestOptions>[];
      final api = TelemetryApiImpl(
        baseUrls: _bases,
        dio: _dioWith([204], seen),
        version: () async => '0.1.90',
      );
      expect(api.urls, [
        'https://api-stg.pianolouvorja.com.br/v1/telemetry/heartbeat',
        'https://api.pianolouvorja.com.br/v1/telemetry/heartbeat',
      ]);
      expect(await api.sendHeartbeat({'install_id': 'x'}), isTrue);
      expect(seen, hasLength(1));
      expect(seen.single.method, 'POST');
      expect(seen.single.data, {'install_id': 'x'});
      expect(seen.single.headers['X-Client-Platform'], startsWith('apk-'));
      expect(seen.single.headers['X-Client-Version'], '0.1.90');
    });

    test('rede ou 5xx cai no proximo host; tudo fora devolve false', () async {
      final seen = <RequestOptions>[];
      final api = TelemetryApiImpl(
        baseUrls: _bases,
        dio: _dioWith([null, 204], seen),
        version: () async => '1.0.0',
      );
      expect(await api.sendHeartbeat({}), isTrue);
      expect(seen, hasLength(2));

      final down = TelemetryApiImpl(
        baseUrls: _bases,
        dio: _dioWith([503, 502], []),
        version: () async => '1.0.0',
      );
      expect(await down.sendHeartbeat({}), isFalse);
    });

    test('4xx nao insiste em outro host', () async {
      final seen = <RequestOptions>[];
      final api = TelemetryApiImpl(
        baseUrls: _bases,
        dio: _dioWith([404, 204], seen),
        version: () async => '1.0.0',
      );
      expect(await api.sendHeartbeat({}), isFalse);
      expect(seen, hasLength(1));
    });

    test('3xx resolvido sem erro conta como recusa (nao 2xx)', () async {
      final api = TelemetryApiImpl(
        baseUrls: _bases,
        dio: _dioWith([304], []),
        version: () async => '1.0.0',
      );
      expect(await api.sendHeartbeat({}), isFalse);
    });
  });
}
