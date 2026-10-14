library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hymn_audio_player.dart';
import 'hymn_player_adapter.dart';

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
///
/// Ações de mídia (mediaPlay/mediaPause/mediaPrev/mediaNext) chegam por
/// este MESMO canal quando a página do hino NÃO está viva: o receiver de
/// MANIFEST (MediaActionReceiver) recebe o broadcast do shell do PiP e o
/// MainActivity repassa via dartPoke. O player é o singleton global — o
/// mesmo que toca a faixa (e que o PipMinimalOverlay escuta).
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
      debugPrint('LouvorPip(dart): onPipChanged=${call.arguments}');
      isActive.value = call.arguments == true;
      return null;
    }
    // Ações de mídia nativas (página do hino pode não estar viva).
    if (call.method == 'mediaPlay' || call.method == 'mediaPause') {
      debugPrint('LouvorPip(dart): ${call.method}');
      final p = HymnPlayerAdapter(HymnAudioPlayer.instance);
      if (call.method == 'mediaPlay') {
        await p.resume();
      } else {
        await p.pause();
      }
      return null;
    }
    if (call.method == 'mediaPrev' || call.method == 'mediaNext') {
      debugPrint('LouvorPip(dart): ${call.method}');
      await _skip(call.method == 'mediaNext' ? 15 : -15);
      return null;
    }
    return null;
  }

  /// ±15s no player global (sem slides aqui — mesma semântica da
  /// notificação de mídia). A posição atual vem do último evento do
  /// positionStream (sem getter síncrono na interface).
  static Future<void> _skip(int seconds) async {
    final p = HymnAudioPlayer.instance;
    try {
      Duration? pos;
      await for (final d in p.positionStream.take(1)) {
        pos = d;
        break;
      }
      var target = (pos ?? Duration.zero) + Duration(seconds: seconds);
      if (target < Duration.zero) target = Duration.zero;
      await p.seek(target);
    } catch (_) {}
  }
}
