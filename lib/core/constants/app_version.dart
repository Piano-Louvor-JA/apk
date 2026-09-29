library;

import 'package:package_info_plus/package_info_plus.dart';

/// Versao do app lida dinamicamente do pubspec.yaml.
///
/// Nunca hardcodar versao em widgets -- sempre usar esta classe.
/// Quando o version do pubspec.yaml muda, todos os widgets atualizam.
abstract final class AppVersion {
  static String? _cachedVersion;

  static Future<String> _getVersion() async {
    if (_cachedVersion != null) return _cachedVersion!;
    try {
      final info = await PackageInfo.fromPlatform().timeout(
        const Duration(seconds: 2),
        onTimeout: () => PackageInfo(
          appName: 'LouvorJA PIANO',
          packageName: 'com.louvorja.piano.mobile',
          version: '0.0.0',
          buildNumber: '',
          buildSignature: '',
          installerStore: null,
        ),
      );
      _cachedVersion = info.version;
      return _cachedVersion!;
    } catch (_) {
      _cachedVersion = '0.0.0';
      return _cachedVersion!;
    }
  }

  /// Retorna apenas o numero de versao (ex: "0.1.0-alpha").
  static Future<String> get version => _getVersion();

  /// Versao curta para splash/footer (ex: "v0.1.0-alpha").
  static Future<String> get displayVersion async {
    final v = await _getVersion();
    return 'v$v';
  }
}
