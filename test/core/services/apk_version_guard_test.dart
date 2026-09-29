library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/apk_version_guard.dart';

void main() {
  group('ApkVersionGuard (bloqueia APK regredido)', () {
    test('instala quando instalado < disponível', () {
      final r = ApkVersionGuard.canInstall(
        installed: '0.1.15',
        available: '0.1.16',
      );
      expect(r.allowed, isTrue);
    });

    test('bloqueia quando disponível == instalado (mesma versão)', () {
      final r = ApkVersionGuard.canInstall(
        installed: '0.1.15',
        available: '0.1.15',
      );
      expect(r.allowed, isFalse);
      expect(r.reason, ApkVersionRejectReason.sameVersion);
    });

    test('bloqueia quando disponível < instalado (regressão)', () {
      final r = ApkVersionGuard.canInstall(
        installed: '0.1.16',
        available: '0.1.15',
      );
      expect(r.allowed, isFalse);
      expect(r.reason, ApkVersionRejectReason.regression);
    });

    test('compara corretamente minor/patch (0.2.0 > 0.1.9)', () {
      expect(
        ApkVersionGuard.canInstall(
          installed: '0.1.9',
          available: '0.2.0',
        ).allowed,
        isTrue,
      );
      expect(
        ApkVersionGuard.canInstall(
          installed: '0.1.10',
          available: '0.1.9',
        ).allowed,
        isFalse,
      );
    });

    test('versão inválida/ausente não bloqueia (fail-open controlado)', () {
      expect(
        ApkVersionGuard.canInstall(installed: '', available: '0.1.16').allowed,
        isTrue,
      );
      expect(
        ApkVersionGuard.canInstall(installed: 'x', available: 'y').allowed,
        isTrue,
      );
    });
  });
}
