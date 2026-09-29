library;

import 'package:flutter/services.dart';

/// PiP Android é ativado pelo sistema quando usuário sai do NowPlaying.
/// Falha silenciosa em web/desktop/iOS, onde a plataforma não oferece PiP.
abstract final class PipController {
  static const _channel = MethodChannel('app.louvorja/updater');

  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setPipEnabled', {'enabled': enabled});
    } catch (_) {
      // Plataforma sem PiP: player continua normalmente.
    }
  }
}
