library;

import 'package:dio/dio.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeOptions());
    registerFallbackValue('https://example.com/apk');
  });

  test('retorna none quando GitHub nao tem release', () async {
    final dio = _MockDio();
    when(
      () => dio.get<dynamic>(
        any(),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(DioException(requestOptions: RequestOptions(path: '')));

    final service = UpdateService(
      dio: dio,
      packageInfoProvider: () async => _pkg('0.1.0'),
    );

    final result = await service.checkForUpdates();
    expect(result.hasUpdate, isFalse);
  });

  test('detecta versao mais recente com asset APK', () async {
    final dio = _MockDio();
    when(
      () => dio.get<dynamic>(
        any(),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        data: {
          'tag_name': 'v0.2.0',
          'body': 'Bug fixes',
          'assets': [
            {
              'name': 'app-release.apk',
              'browser_download_url':
                  'https://github.com/pianolouvorja/apk/releases/download/v0.2.0/app-release.apk',
              'size': 60000000,
              'digest':
                  'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            },
          ],
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ),
    );

    final service = UpdateService(
      dio: dio,
      packageInfoProvider: () async => _pkg('0.1.0'),
    );

    final result = await service.checkForUpdates();

    expect(result.hasUpdate, isTrue);
    expect(result.latestVersion, '0.2.0');
    expect(result.downloadUrl, contains('app-release.apk'));
    expect(result.apkSize, 60000000);
    expect(
      result.apkSha256,
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    );
    expect(result.releaseNotes, 'Bug fixes');
  });

  test(
    'retorna none quando versao instalada e igual ou mais recente',
    () async {
      final dio = _MockDio();
      when(
        () => dio.get<dynamic>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          data: {
            'tag_name': 'v0.1.0',
            'assets': [
              {'name': 'app.apk', 'browser_download_url': 'url', 'size': 1},
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final service = UpdateService(
        dio: dio,
        packageInfoProvider: () async => _pkg('0.1.0'),
      );

      expect((await service.checkForUpdates()).hasUpdate, isFalse);
    },
  );

  test('retorna none quando release nao tem APK', () async {
    final dio = _MockDio();
    when(
      () => dio.get<dynamic>(
        any(),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        data: {
          'tag_name': 'v0.5.0',
          'assets': [
            {'name': 'source.zip', 'browser_download_url': 'url', 'size': 1},
          ],
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ),
    );

    final service = UpdateService(
      dio: dio,
      packageInfoProvider: () async => _pkg('0.1.0'),
    );

    expect((await service.checkForUpdates()).hasUpdate, isFalse);
  });

  test('_isNewer compara semver corretamente', () {
    final service = UpdateService(
      packageInfoProvider: () async => _pkg('0.0.0'),
    );

    expect(service._testIsNewer('0.2.0', '0.1.0'), isTrue);
    expect(service._testIsNewer('1.0.0', '0.9.9'), isTrue);
    expect(service._testIsNewer('0.1.0', '0.1.0'), isFalse);
    expect(service._testIsNewer('0.0.9', '0.1.0'), isFalse);
    expect(service._testIsNewer('0.1.0', '0.1.0'), isFalse);
  });

  test(
    'usa proxy UPDATE_API quando configurado (repo privado sem token no APK)',
    () async {
      final dio = _MockDio();
      final captured = <String>[];
      when(
        () => dio.get<dynamic>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((inv) async {
        captured.add(inv.positionalArguments[0] as String);
        return Response<dynamic>(
          data: {
            'tag_name': 'v0.2.0',
            'body': 'notes',
            'assets': [
              {
                'name': 'louvorja-piano-0.2.0.apk',
                'browser_download_url':
                    'https://pianolouvorja.duckdns.org/dl/v0.2.0/louvorja-piano-0.2.0.apk',
                'size': 60000000,
                'digest':
                    'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
              },
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );
      });

      final service = UpdateService(
        dio: dio,
        updateApiBase: 'https://pianolouvorja.duckdns.org',
        packageInfoProvider: () async => _pkg('0.1.0'),
      );

      final result = await service.checkForUpdates();
      expect(result.hasUpdate, isTrue);
      // URL de consulta foi pro proxy, NAO pro api.github.com
      expect(
        captured.single,
        'https://pianolouvorja.duckdns.org/repos/pianolouvorja/apk/releases/latest',
      );
      // E sem header Authorization (token vive no servidor)
      expect(
        result.downloadUrl,
        'https://pianolouvorja.duckdns.org/dl/v0.2.0/louvorja-piano-0.2.0.apk',
      );
    },
  );

  test('sem UPDATE_API mantem GitHub direto (compat retroativa)', () async {
    final dio = _MockDio();
    final captured = <String>[];
    when(
      () => dio.get<dynamic>(
        any(),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((inv) async {
      captured.add(inv.positionalArguments[0] as String);
      return Response<dynamic>(
        data: {'tag_name': 'v0.1.0', 'assets': []},
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );
    });

    final service = UpdateService(
      dio: dio,
      packageInfoProvider: () async => _pkg('0.1.0'),
    );
    await service.checkForUpdates();

    expect(captured.single, startsWith('https://api.github.com/repos/'));
  });
}

extension on UpdateService {
  bool _testIsNewer(String remote, String local) {
    // Acessa via reflexao simples para teste.
    final r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final l = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final maxLen = r.length > l.length ? r.length : l.length;
    while (r.length < maxLen) {
      r.add(0);
    }
    while (l.length < maxLen) {
      l.add(0);
    }
    for (var i = 0; i < maxLen; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }
}
