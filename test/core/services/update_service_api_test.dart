library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/update_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MockDio extends Mock implements Dio {}

class _FakeOptions extends Fake implements Options {}

PackageInfo _pkg(String version) => PackageInfo(
  appName: 'test',
  packageName: 'test',
  version: version,
  buildNumber: '1',
  buildSignature: '',
  installerStore: null,
);

const _host = 'https://api.exemplo.test';
const _sha = 'a61ede7b3f6323c6cd2535768a07dfafe3d29c10f29fbda5201ab1930b53af5b';

/// Dio de mentira: responde por URL e anota quem foi chamado.
(_MockDio, List<String>) _dio(Response<dynamic> Function(String url) answer) {
  final dio = _MockDio();
  final calls = <String>[];
  when(
    () => dio.get<dynamic>(
      any(),
      options: any(named: 'options'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((inv) async {
    final url = inv.positionalArguments[0] as String;
    calls.add(url);
    return answer(url);
  });
  return (dio, calls);
}

Response<dynamic> _ok(Object data) => Response<dynamic>(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: ''),
);

Never _notFound() => throw DioException(
  requestOptions: RequestOptions(path: ''),
  response: Response<dynamic>(
    statusCode: 404,
    requestOptions: RequestOptions(path: ''),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeOptions());
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('pergunta primeiro à nossa API e baixa o apk dela', () async {
    final (dio, calls) = _dio(
      (_) => _ok({
        'version': '1.0.1',
        'apk_url': '/v1/app/apk/louvorja-piano-1.0.1.apk',
        'size': 157040991,
        'sha256': _sha,
        'notes': '## Novidades',
        'published_at': '2026-11-18T12:00:00Z',
      }),
    );
    final service = UpdateService(
      dio: dio,
      apiHost: '$_host/',
      packageInfoProvider: () async => _pkg('1.0.0'),
    );

    final result = await service.checkForUpdates();
    expect(calls, ['$_host/v1/app/version']);
    expect(result.hasUpdate, isTrue);
    expect(result.latestVersion, '1.0.1');
    expect(result.downloadUrl, '$_host/v1/app/apk/louvorja-piano-1.0.1.apk');
    expect(result.apkSha256, _sha);
    expect(result.apkSize, 157040991);
    expect(result.releaseNotes, '## Novidades');
  });

  test('API com a mesma versão: sem atualização e sem GitHub', () async {
    final (dio, calls) = _dio(
      (_) => _ok({
        'version': '1.0.0',
        'apk_url': '/v1/app/apk/louvorja-piano-1.0.0.apk',
      }),
    );
    final service = UpdateService(
      dio: dio,
      apiHost: _host,
      packageInfoProvider: () async => _pkg('1.0.0'),
    );
    expect((await service.checkForUpdates()).hasUpdate, isFalse);
    expect(calls, ['$_host/v1/app/version']);
  });

  test('API sem nada publicado (404): cai no GitHub com o repo novo', () async {
    final (dio, calls) = _dio((url) {
      if (url.startsWith(_host)) _notFound();
      return _ok({
        'tag_name': 'v1.0.1',
        'assets': [
          {
            'name': 'louvorja-piano-1.0.1.apk',
            'browser_download_url':
                'https://github.com/Piano-Louvor-JA/apk/releases/download/v1.0.1/louvorja-piano-1.0.1.apk',
            'size': 10,
            'digest': 'sha256:$_sha',
          },
        ],
      });
    });
    final service = UpdateService(
      dio: dio,
      apiHost: _host,
      packageInfoProvider: () async => _pkg('1.0.0'),
    );

    final result = await service.checkForUpdates();
    expect(calls, [
      '$_host/v1/app/version',
      'https://api.github.com/repos/Piano-Louvor-JA/apk/releases/latest',
    ]);
    expect(result.hasUpdate, isTrue);
    expect(result.downloadUrl, contains('github.com/Piano-Louvor-JA/apk'));
  });

  test('resposta estranha da API também cai no GitHub', () async {
    final (dio, calls) = _dio(
      (url) => url.startsWith(_host)
          ? _ok({'oi': 1})
          : _ok({'tag_name': 'v1.0.0', 'assets': []}),
    );
    final service = UpdateService(
      dio: dio,
      apiHost: _host,
      packageInfoProvider: () async => _pkg('1.0.0'),
    );
    await service.checkForUpdates();
    expect(calls.length, 2);
  });

  test(
    'no iPhone/iPad não consulta nada (atualização pela App Store)',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final (dio, calls) = _dio((_) => _ok({}));
      final service = UpdateService(
        dio: dio,
        apiHost: _host,
        packageInfoProvider: () async => _pkg('0.1.0'),
      );
      final result = await service.checkForUpdates();
      expect(UpdateService.inAppUpdateSupported, isFalse);
      expect(result.hasUpdate, isFalse);
      expect(result.isUnavailable, isFalse);
      expect(calls, isEmpty);
    },
  );
}
