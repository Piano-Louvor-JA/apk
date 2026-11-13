import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'youtube_web.dart';

/// Vídeo tocado numa página web (YouTube) dentro do player da Liturgia local.
/// O controlador vive no player: minimizar ou trocar de aba não recarrega.
abstract class LiturgyWebVideo {
  Future<void> load(String url, {Map<String, String> headers = const {}});
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setCaptionsHidden(bool hidden);
  Future<YoutubeWebState?> probe();
  Widget view();
  Future<void> dispose();

  /// Espelho limpo para as telas (ver [YoutubeWeb.mirrorGlueScript]): saem
  /// `{slotId, message}` para repassar ao slot, ou `{error}`.
  Stream<Map<String, dynamic>> get mirrorOut;
  Future<void> mirrorStart(String slotId, {required bool muted});
  Future<void> mirrorRemove(String slotId);
  Future<void> mirrorStop();
  Future<void> mirrorHandle(Map<String, dynamic> message);
}

class WebViewLiturgyVideo implements LiturgyWebVideo {
  WebViewLiturgyVideo() {
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'LouvorjaMirror',
        onMessageReceived: (message) {
          try {
            final decoded = jsonDecode(message.message);
            if (decoded is Map && !_mirrorOut.isClosed) {
              _mirrorOut.add(decoded.cast<String, dynamic>());
            }
          } catch (_) {
            /* mensagem inválida da página não chega às telas */
          }
        },
      )
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          // Injeta o pulador de anúncio a cada página do YouTube carregada.
          onPageFinished: (_) {
            _run(YoutubeWeb.adSkipScript);
            if (_captionsHidden) _run(YoutubeWeb.captionsScript(true));
          },
        ),
      );
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      // autoplay=1 do embed: sem isso o Android exige um toque na página.
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  final controller = WebViewController();
  bool _disposed = false, _captionsHidden = false;
  final _mirrorOut = StreamController<Map<String, dynamic>>.broadcast();
  static String? _mirrorLibrary;

  /// network-mirror.js (o mesmo do desktop) + ligação; a página pode ter
  /// recarregado (fallback), então garante a cada início.
  Future<void> _ensureMirror() async {
    final library = _mirrorLibrary ??= await rootBundle.loadString(
      'assets/palco/network-mirror.js',
    );
    await _run('if (!window.PianoNetworkMirror) {\n$library\n}');
    await _run(YoutubeWeb.mirrorGlueScript);
  }

  @override
  Stream<Map<String, dynamic>> get mirrorOut => _mirrorOut.stream;

  @override
  Future<void> mirrorStart(String slotId, {required bool muted}) async {
    await _ensureMirror();
    await _run(YoutubeWeb.mirrorStartScript(slotId, muted: muted));
  }

  @override
  Future<void> mirrorRemove(String slotId) =>
      _run(YoutubeWeb.mirrorRemoveScript(slotId));

  @override
  Future<void> mirrorStop() => _run(YoutubeWeb.mirrorStopScript);

  @override
  Future<void> mirrorHandle(Map<String, dynamic> message) =>
      _run(YoutubeWeb.mirrorHandleScript(message));

  Future<void> _run(String script) async {
    if (_disposed) return;
    try {
      await controller.runJavaScript(script);
    } catch (_) {
      /* página ainda carregando ou fora do YouTube */
    }
  }

  @override
  Future<void> load(String url, {Map<String, String> headers = const {}}) =>
      controller.loadRequest(Uri.parse(url), headers: headers);

  @override
  Future<void> play() => _run(YoutubeWeb.playScript);

  @override
  Future<void> pause() => _run(YoutubeWeb.pauseScript);

  @override
  Future<void> seekTo(Duration position) =>
      _run(YoutubeWeb.seekScript(position));

  @override
  Future<void> setVolume(double volume) =>
      _run(YoutubeWeb.volumeScript(volume));

  @override
  Future<void> setCaptionsHidden(bool hidden) {
    _captionsHidden = hidden;
    return _run(YoutubeWeb.captionsScript(hidden));
  }

  @override
  Future<YoutubeWebState?> probe() async {
    if (_disposed) return null;
    try {
      // O pulador também é reaplicado aqui: a página pode trocar de vídeo
      // (anúncio → conteúdo) sem disparar um novo onPageFinished.
      await controller.runJavaScript(YoutubeWeb.adSkipScript);
      // A legenda do YouTube pode entrar depois (troca de faixa/anúncio).
      if (_captionsHidden) {
        await controller.runJavaScript(YoutubeWeb.captionsScript(true));
      }
      return YoutubeWebState.parse(
        await controller.runJavaScriptReturningResult(YoutubeWeb.probeScript),
      );
    } catch (_) {
      return null;
    }
  }

  // Sem toque na página: quem controla é a barra (no desktop o player
  // também ignora o ponteiro).
  @override
  Widget view() => IgnorePointer(child: WebViewWidget(controller: controller));

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await _run(YoutubeWeb.mirrorStopScript);
    await controller.loadRequest(Uri.parse('about:blank')).catchError((_) {});
    _disposed = true;
    await _mirrorOut.close();
  }
}
