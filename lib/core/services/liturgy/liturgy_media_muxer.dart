import 'package:flutter/services.dart';

/// Junta streams MP4/M4A usando codecs nativos, sem recodificação nem rede.
abstract final class LiturgyMediaMuxer {
  static const _channel = MethodChannel('app.louvorja/liturgy-media');
  static Future<void> combine({
    required String video,
    required String audio,
    required String output,
  }) async {
    final ok = await _channel.invokeMethod<bool>('mux', {
      'video': video,
      'audio': audio,
      'output': output,
    });
    if (ok != true) throw StateError('mux-failed');
  }
}
