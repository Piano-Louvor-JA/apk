import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/sync/operator_state_boot.dart';
import 'package:louvorja_piano_mobile/core/services/settings_controller.dart';

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? request;
  String response = '{"operator_state":[]}';

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      response,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OperatorStateBoot.resetForTest();
  });
  tearDown(() {
    OperatorStateBoot.resetForTest();
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('sync usa Bearer e identifica ${platform.name}', () async {
      debugDefaultTargetPlatformOverride = platform;
      final adapter = _CaptureAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close());
      final prefs = await SharedPreferences.getInstance();
      final client = OperatorStateBoot.client(
        prefs,
        dio: dio,
        apiBaseUrl: 'https://api.test',
        sessionToken: () async => 'sessao-teste',
      );
      await client.enqueuePrefs({'accent': 'azure'});
      await client.flush();
      expect(adapter.request!.headers['Authorization'], 'Bearer sessao-teste');
      expect(
        adapter.request!.headers['X-Client-Platform'],
        platform == TargetPlatform.iOS ? 'apk-ios' : 'apk-android',
      );
    });
  }

  test('pull atualiza as preferências em memória sem reenfileirar', () async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsController(
      outboxHook: (_, _) => fail('pull reenfileirou'),
    );
    addTearDown(settings.dispose);
    final adapter = _CaptureAdapter()
      ..response =
          '{"operator_state":[{"namespace":"prefs","key":"values","updated_at_ms":1000,"value_json":"{\\"themeMode\\":\\"dark\\"}"}]}';
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close());
    final client = OperatorStateBoot.client(
      prefs,
      dio: dio,
      apiBaseUrl: 'https://api.test',
      sessionToken: () async => 'sessao-teste',
      onApplied: settings.loadSettings,
    );
    await client.flush();
    expect(settings.themeMode, ThemeMode.dark);
    expect(client.outboxCount(), 0);
  });
}
