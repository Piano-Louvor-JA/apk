import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Captura a página nativa para projetar sites que não permitem iframe.
abstract final class LiturgyWebSnapshot {
  static const _channel = MethodChannel('app.louvorja/liturgy-media');
  static Future<Uint8List> capture() async {
    final bytes = await _channel.invokeMethod<Uint8List>('webSnapshot');
    if (bytes == null || bytes.isEmpty) throw StateError('web-snapshot');
    return bytes;
  }
}
