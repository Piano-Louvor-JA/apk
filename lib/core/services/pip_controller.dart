library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// PiP Android é ativado pelo sistema quando usuário sai do NowPlaying.
/// Falha silenciosa em web/desktop/iOS, onde a plataforma não oferece PiP.
///
/// SPEC 13 (apk#132): o Flutter PRECISA saber quando está em PiP pra
/// renderizar o layout minimalista (a janela do PiP mostra o próprio app
/// reduzido — sem esse sinal, a UI inteira entra na janelinha congestionada).
///
/// Canais (fix 06/10 — antes o Dart escutava em `app.louvorja/updater`,
/// mas o Kotlin envia `onPipChanged` em `app.louvorja/pip`; o sinal nunca
/// chegava e o layout mínimo nunca renderizava):
///   - comandos Flutter→Android: `app.louvorja/updater`
///   - evento  Android→Flutter:  `app.louvorja/pip`
abstract final class PipController {
  static const _cmdChannel = MethodChannel('app.louvorja/updater');
  static const _eventChannel = MethodChannel('app.louvorja/pip');

  /// true quando a Activity está em modo Picture-in-Picture.
  /// Sempre false em plataformas sem PiP (web/desktop/iOS).
  static final ValueNotifier<bool> isActive = ValueNotifier<bool>(false);

  static bool _listenerRegistered = false;

  static Future<void> setEnabled(bool enabled) async {
    try {
      await _cmdChannel
          .invokeMethod<void>('setPipEnabled', {'enabled': enabled});
      if (!_listenerRegistered) {
        _listenerRegistered = true;
        _eventChannel.setMethodCallHandler(_onPlatformCall);
        await _cmdChannel.invokeMethod<void>('setPipEventListener');
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
