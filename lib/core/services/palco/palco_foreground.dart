library;

import 'package:flutter/services.dart';

/// Wrapper do foreground service do Palco (F3.3).
///
/// Mantém o processo Android vivo (rede + áudio) quando o app sai de
/// primeiro plano — sem isso o One UI congela o HttpServer do sender
/// ("AudioHardening", evidência 2026-08-18) e a TV perde a conexão.
abstract final class PalcoForeground {
  static const _ch = MethodChannel('app.louvorja/updater');

  /// Liga o service. Retorna false se a plataforma não suportar
  /// (web/desktop de teste) — falha silenciosa é aceitável: em foreground
  /// natural o app funciona de qualquer forma.
  static Future<bool> start() async {
    try {
      return await _ch.invokeMethod<bool>('startPalcoForeground') ?? false;
    } catch (_) {
      // PlatformException/MissingPluginException (testes, web, desktop):
      // foreground natural já basta nesses ambientes.
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _ch.invokeMethod<void>('stopPalcoForeground');
    } catch (_) {
      // idempotente: nunca falha o turnOff por causa da notificação
    }
  }
}
