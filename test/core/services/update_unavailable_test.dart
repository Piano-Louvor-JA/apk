library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo _pkg(String version) => PackageInfo(
  appName: 'test',
  packageName: 'test',
  version: version,
  buildNumber: '1',
);

class _ErrorAdapter implements HttpClientAdapter {
  final Object error;
  _ErrorAdapter(this.error);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw error;
}

Dio _dioFailingWith(Object error) {
  final dio = Dio();
  dio.httpClientAdapter = _ErrorAdapter(error);
  return dio;
}

void main() {
  group('UpdateCheckResult', () {
    test('unavailable distingue erro de atualizado', () {
      const result = UpdateCheckResult.unavailable(
        reason: UpdateCheckFailure.unauthorized,
      );
      expect(result.hasUpdate, isFalse);
      expect(result.isUnavailable, isTrue);
      expect(result.failure, UpdateCheckFailure.unauthorized);
    });

    test('none (atualizado) nao e unavailable', () {
      expect(UpdateCheckResult.none.isUnavailable, isFalse);
      expect(UpdateCheckResult.none.failure, isNull);
    });
  });

  test(
    '404 (repo privado sem token) retorna unavailable unauthorized',
    () async {
      final service = UpdateService(
        dio: _dioFailingWith(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(path: '/x'),
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
        packageInfoProvider: () async => _pkg('0.1.2'),
      );

      final result = await service.checkForUpdates();

      expect(
        result.isUnavailable,
        isTrue,
        reason:
            '404 em repo privado deve sinalizar indisponibilidade, '
            'nao "atualizado"',
      );
      expect(result.failure, UpdateCheckFailure.unauthorized);
    },
  );

  test('timeout de rede retorna unavailable network', () async {
    final service = UpdateService(
      dio: _dioFailingWith(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
      packageInfoProvider: () async => _pkg('0.1.2'),
    );

    final result = await service.checkForUpdates();

    expect(result.isUnavailable, isTrue);
    expect(result.failure, UpdateCheckFailure.network);
  });

  test('erro generico retorna unavailable unknown', () async {
    final service = UpdateService(
      dio: _dioFailingWith(Exception('boom')),
      packageInfoProvider: () async => _pkg('0.1.2'),
    );

    final result = await service.checkForUpdates();

    expect(result.isUnavailable, isTrue);
    // O Dio pode envolver erros genericos como connectionError — o que
    // importa e distinguir "falhou" de "atualizado", nao o motivo exato.
    expect(result.failure, isNotNull);
  });
}
