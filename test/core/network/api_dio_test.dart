import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/network/api_dio.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'cliente de catálogo usa os defines do build sem contaminar fallback',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'Piano',
        packageName: 'com.louvorja.piano.mobile',
        version: '2.3.4',
        buildNumber: '1',
        buildSignature: '',
      );
      final api = LouvorjaApiImpl.single(
        baseUrl: 'https://api-stg.pianolouvorja.com.br/json_db',
        filesUrl: 'https://api-stg.pianolouvorja.com.br/file',
        apiToken: 'legado',
      );
      addTearDown(() => api.dio.close());
      final captured = <RequestOptions>[];
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured.add(options);
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: {}),
            );
          },
        ),
      );
      for (final host in [
        'api-stg.pianolouvorja.com.br',
        'api.pianolouvorja.com.br',
        'api.louvorja.com.br',
      ]) {
        await api.dio.get<dynamic>('https://$host/file/teste');
      }
      expect(captured.first.headers['X-Client-Version'], '2.3.4');
      const configuredKeys = [
        String.fromEnvironment('PARTNER_KEY_STG'),
        String.fromEnvironment('PARTNER_KEY_PROD'),
      ];
      const override = String.fromEnvironment('PARTNER_KEY');
      for (var i = 0; i < configuredKeys.length; i++) {
        final options = captured[i];
        final expected = (override.isEmpty ? configuredKeys[i] : override).trim();
        expect(
          options.headers['X-Partner-Key'],
          expected.startsWith('plj_') ? expected : null,
        );
        expect(options.headers['Api-Token'], 'legado');
      }
      expect(captured.last.headers.containsKey('X-Partner-Key'), isFalse);
    },
  );

  Future<RequestOptions> request(String url, {String key = 'plj_teste'}) async {
    final dio = createApiDio(
      options: BaseOptions(
        headers: {'Authorization': 'Bearer sessao', 'Api-Token': 'legado'},
      ),
      partnerKey: key,
      version: () async => '1.2.3',
    );
    addTearDown(() => dio.close());
    late RequestOptions captured;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response(requestOptions: options, data: {}, statusCode: 200),
          );
        },
      ),
    );
    await dio.get<dynamic>(url);
    return captured;
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'identifica ${platform.name} e preserva autenticação existente',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final options = await request(
          'https://api-stg.pianolouvorja.com.br/v1/custom/collections',
        );
        expect(options.headers, containsPair('X-Partner-Key', 'plj_teste'));
        expect(
          options.headers,
          containsPair(
            'X-Client-Platform',
            platform == TargetPlatform.iOS ? 'apk-ios' : 'apk-android',
          ),
        );
        expect(options.headers, containsPair('X-Client-Version', '1.2.3'));
        expect(options.headers, containsPair('Authorization', 'Bearer sessao'));
        expect(options.headers, containsPair('Api-Token', 'legado'));
      },
    );
  }

  for (final url in [
    'https://api.louvorja.com.br/db/manifest.json',
    'https://googleapis.com/auth',
    'https://api.pianolouvorja.com.br.exemplo.com/file/a',
    'http://api.pianolouvorja.com.br/v1/liturgy',
  ]) {
    test('não envia chave nem identificação para $url', () async {
      final options = await request(url);
      expect(options.headers.containsKey('X-Partner-Key'), isFalse);
      expect(options.headers.containsKey('X-Client-Platform'), isFalse);
      expect(options.headers.containsKey('X-Client-Version'), isFalse);
    });
  }

  for (final key in ['', '   ', 'invalida']) {
    test('chave ausente ou inválida mantém acesso sem token: "$key"', () async {
      final options = await request(
        'https://api.pianolouvorja.com.br/v1/liturgy',
        key: key,
      );
      expect(options.headers.containsKey('X-Partner-Key'), isFalse);
      expect(options.headers['X-Client-Version'], '1.2.3');
    });
  }

  test('seleciona chave por ambiente e aceita override', () {
    const stg = 'https://api-stg.pianolouvorja.com.br/v1/liturgy';
    const prod = 'https://api.pianolouvorja.com.br/v1/liturgy';
    expect(
      partnerKeyForUri(
        Uri.parse(stg),
        stagingKey: 'plj_stg',
        productionKey: 'plj_prod',
      ),
      'plj_stg',
    );
    expect(
      partnerKeyForUri(
        Uri.parse(prod),
        stagingKey: 'plj_stg',
        productionKey: 'plj_prod',
      ),
      'plj_prod',
    );
    expect(
      partnerKeyForUri(
        Uri.parse('http://localhost:8787/v1/liturgy'),
        stagingKey: 'plj_stg',
      ),
      'plj_stg',
    );
    expect(
      partnerKeyForUri(
        Uri.parse(prod),
        override: ' plj_override ',
        productionKey: 'plj_prod',
      ),
      'plj_override',
    );
    expect(
      partnerKeyForUri(
        Uri.parse('https://example.com'),
        override: 'plj_override',
      ),
      '',
    );
  });
}
