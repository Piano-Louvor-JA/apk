import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/platform_header.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('identifica Android sem depender de dart:io no navegador', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(clientPlatformHeaders(), {'X-Client-Platform': 'apk-android'});
  });

  test('identifica iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(clientPlatformHeaders(), {'X-Client-Platform': 'apk-ios'});
  });

  test('inclui versão somente quando informada e não vazia', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(clientPlatformHeaders(version: ''), {
      'X-Client-Platform': 'apk-android',
    });
    expect(clientPlatformHeaders(version: '0.4.0'), {
      'X-Client-Platform': 'apk-android',
      'X-Client-Version': '0.4.0',
    });
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('API preserva Api-Token e identifica ${platform.name}', () {
      debugDefaultTargetPlatformOverride = platform;
      final api = LouvorjaApiImpl.single(
        baseUrl: 'https://api.test/json_db',
        filesUrl: 'https://api.test/file',
        apiToken: 'token-de-teste',
      );
      addTearDown(() => api.dio.close());
      expect(api.dio.options.headers['Api-Token'], 'token-de-teste');
      expect(
        api.dio.options.headers['X-Client-Platform'],
        platform == TargetPlatform.iOS ? 'apk-ios' : 'apk-android',
      );
    });
  }
}
