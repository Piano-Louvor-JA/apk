import 'package:flutter/services.dart';

abstract final class LiturgyExternalPlayer {
  static const _channel = MethodChannel('app.louvorja/liturgy-media');
  static Future<void> open(String path, String playerId) async {
    final ok = await _channel.invokeMethod<bool>('openPlayer', {
      'path': path,
      'playerId': playerId,
    });
    if (ok != true) throw StateError('player-missing');
  }
}
