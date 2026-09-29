library;

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Nome do dispositivo para o desktop identificar quem conectou.
///
/// Android/iOS: modelo do aparelho (ex.: "SM-A155F", "iPhone 15").
/// Desktop/web: fallback "Piano LouvorJA".
abstract final class RemoteDeviceName {
  static String? _cached;
  static String? _cachedVersion;

  /// Modelo legível do aparelho; null se não conseguiu determinar.
  static Future<String?> get() async {
    if (_cached != null) return _cached;
    try {
      final device = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await device.androidInfo;
        _cached = info.model; // ex.: SM-A155F
      } else if (Platform.isIOS) {
        final info = await device.iosInfo;
        _cached = info.utsname.machine; // ex.: iPhone16,1
      } else {
        _cached = null;
      }
    } catch (_) {
      _cached = null;
    }
    return _cached;
  }

  /// Versão do app APK (ex.: 0.1.86).
  static Future<String?> appVersion() async {
    if (_cachedVersion != null) return _cachedVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedVersion = info.version;
    } catch (_) {
      _cachedVersion = null;
    }
    return _cachedVersion;
  }
}
