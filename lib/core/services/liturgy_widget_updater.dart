library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Notifica o widget nativo de liturgia para atualizar.
///
/// Chamado pelo LiturgyRepository após salvar itens.
/// Falha silenciosa em web/iOS.
abstract final class LiturgyWidgetUpdater {
  static const _ch = MethodChannel('app.louvorja/updater');
  static const _method = 'updateLiturgyWidget';

  static Future<void> notify() async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod<void>(_method);
    } catch (_) {}
  }
}
