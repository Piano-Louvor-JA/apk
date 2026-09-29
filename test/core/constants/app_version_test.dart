library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/constants/app_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => <String, dynamic>{
            'appName': 'LouvorJA PIANO',
            'packageName': 'com.louvorja.piano.mobile',
            'version': '1.2.3',
            'buildNumber': '9',
            'buildSignature': '',
            'installerStore': null,
          },
        );
  });

  test('formata versão para exibição', () async {
    expect(await AppVersion.version, '1.2.3');
    expect(await AppVersion.displayVersion, 'v1.2.3');
  });
}
