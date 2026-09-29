library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/constants/app_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Este teste deve rodar antes de qualquer outro que use AppVersion
  // porque _cachedVersion e estatico e persiste.
  test('onTimeout retorna PackageInfo fallback com version 0.0.0', () async {
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          // Simula demora maior que o timeout de 2s
          await Future.delayed(const Duration(seconds: 3));
          return <String, dynamic>{
            'appName': 'LouvorJA PIANO',
            'packageName': 'com.louvorja.piano.mobile',
            'version': '9.9.9',
            'buildNumber': '1',
            'buildSignature': '',
            'installerStore': null,
          };
        });

    // O timeout interno (2s) deve disparar antes dos 3s do mock
    final version = await AppVersion.version;
    expect(version, '0.0.0');
  });
}
