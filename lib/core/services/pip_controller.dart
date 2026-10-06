library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// PiP Android é ativado pelo sistema quando usuário sai do NowPlaying.
/// Falha silenciosa em web/desktop/iOS, onde a plataforma não oferece PiP.
///
/// SPEC 13 (apk#132): o Flutter PRECISA saber quando está em PiP pra
/// renderizar o layout minimalista (a janela do PiP mostra o próprio app
/// reduzido — sem esse sinal, a UI inteira entra na janelinha congestionada).
abstract final class PipController {
  static const _channel = MethodChannel('app.louvorja/updater');

  /// true quando a Activity está em modo Picture-in-Picture.
  /// Sempre false em plataformas sem PiP (web/desktop/iOS).
  static final ValueNotifier<bool> isActive = ValueNotifier<bool>(false);

  static bool _listenerRegistered = false;

  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setPipEnabled', {'enabled': enabled});
      if (!_listenerRegistered) {
        _listenerRegistered = true;
        _channel.setMethodCallHandler(_onPlatformCall);
        await _channel.invokeMethod<void>('setPipEventListener');
      }
    } catch (_) {
      // Plataforma sem PiP: player continua normalmente (isActive fica false).
    }
  }

  static Future<dynamic> _onPlatformCall(MethodCall call) async {
    if (call.method == 'onPipChanged') {
      isActive.value = call.arguments == true;
    }
    return null;
  }
}
