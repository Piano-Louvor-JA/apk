import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// apk#90 — Palco não conecta pelo celular.
///
/// Android 13+ (API 33): Apps com targetSdk 33+ que usam redes locais
/// (mDNS/multicast, scans) precisam de NEARBY_WIFI_DEVICES (ou o prompt
/// de "redes próximas") e ACCESS_NETWORK_STATE. Sem essas permissões no
/// manifest, a descoberta mDNS da TV falha silenciosamente no A15 —
/// exatamente o relato "Procurando TV webOS na rede…" infinito.
///
/// Este teste trava o contrato: o AndroidManifest DEVE declarar
/// ACCESS_NETWORK_STATE e NEARBY_WIFI_DEVICES (neverForLocation).
void main() {
  test('AndroidManifest declara permissões de rede local (apk#90)', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.ACCESS_NETWORK_STATE'),
      reason: 'Sem ACCESS_NETWORK_STATE o connectivity check do '
          'PalcoAutoConnectSheet falha no Android 13+.',
    );
    expect(
      manifest,
      contains('android.permission.NEARBY_WIFI_DEVICES'),
      reason: 'Android 13+ exige NEARBY_WIFI_DEVICES para descoberta '
          'mDNS/local de TVs na rede — sem ela o scan falha em silêncio '
          '(apk#90).',
    );
    // NEARBY_WIFI_DEVICES nunca deve exigir location por design do app
    // (LGPD / dados mínimos).
    final nearby = RegExp(
      r'<uses-permission[^>]*android\.permission\.NEARBY_WIFI_DEVICES[^>]*>',
    ).firstMatch(manifest);
    expect(nearby, isNotNull);
    expect(
      nearby!.group(0),
      contains('neverForLocation'),
      reason: 'Palco não precisa de localização — neverForLocation evita '
          'o prompt de GPS (dados mínimos).',
    );
  });
}
