import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contrato das declarações adicionadas ao manifest para apk#90.
/// A presença no XML não comprova concessão em execução ou pareamento.
void main() {
  test('AndroidManifest declara permissões de rede local (apk#90)', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.ACCESS_NETWORK_STATE'),
      reason: 'Preserva a declaração de acesso ao estado da rede.',
    );
    expect(
      manifest,
      contains('android.permission.NEARBY_WIFI_DEVICES'),
      reason: 'Preserva a declaração de dispositivos Wi-Fi próximos.',
    );
    // O flag declara que os dados não são usados para inferir localização.
    // Ele não dispensa a concessão da permissão de dispositivos próximos.
    final nearby = RegExp(
      r'<uses-permission[^>]*android\.permission\.NEARBY_WIFI_DEVICES[^>]*>',
    ).firstMatch(manifest);
    expect(nearby, isNotNull);
    expect(
      nearby!.group(0),
      contains('neverForLocation'),
      reason: 'A declaração deve preservar a finalidade sem localização.',
    );
  });
}
