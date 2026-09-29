library;

import 'dart:async';
import 'package:flutter/services.dart';

/// Controles de mídia nativos (notificação, lock screen, PiP).
///
/// Android: MediaSessionCompat + NotificationCompat.MediaStyle.
/// Web/iOS: falha silenciosa (sem equivalente neste canal).
abstract final class MediaSession {
  static const _ch = MethodChannel('app.louvorja/media');
  static bool _active = false;

  /// Callbacks vindos da notificação/PiP/lock screen.
  static void Function(bool play)? onPlayPause;
  static void Function()? onPrev;
  static void Function()? onNext;

  static Future<void> init() async {
    _ch.setMethodCallHandler(_handle);
    try {
      await _ch.invokeMethod<void>('init');
      _active = true;
    } catch (_) {
      _active = false;
    }
  }

  static Future<void> setMetadata({
    required String title,
    required String album,
    String? artUrl,
    int durationMs = 0,
  }) async {
    if (!_active) return;
    try {
      await _ch.invokeMethod<void>('setMetadata', {
        'title': title,
        'album': album,
        'artUrl': artUrl,
        'durationMs': durationMs,
      });
    } catch (_) {}
  }

  static Future<void> setPlaybackState({
    required bool isPlaying,
    int positionMs = 0,
  }) async {
    if (!_active) return;
    try {
      await _ch.invokeMethod<void>('setPlaybackState', {
        'isPlaying': isPlaying,
        'positionMs': positionMs,
      });
    } catch (_) {}
  }

  static Future<void> show() async {
    if (!_active) return;
    try {
      await _ch.invokeMethod<void>('show');
    } catch (_) {}
  }

  static Future<void> hide() async {
    if (!_active) return;
    try {
      await _ch.invokeMethod<void>('hide');
    } catch (_) {}
  }

  static Future<void> release() async {
    try {
      await _ch.invokeMethod<void>('release');
    } catch (_) {}
    _ch.setMethodCallHandler(null);
    _active = false;
  }

  static Future<dynamic> _handle(MethodCall call) async {
    switch (call.method) {
      case 'onPlayPause':
        onPlayPause?.call(call.arguments as bool? ?? true);
      case 'onPrev':
        onPrev?.call();
      case 'onNext':
        onNext?.call();
    }
  }
}
