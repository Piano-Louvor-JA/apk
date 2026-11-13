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
  Future<YoutubeWebState?> probe();
  Widget view();
  Future<void> dispose();
}

class WebViewLiturgyVideo implements LiturgyWebVideo {
  WebViewLiturgyVideo() {
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          // Injeta o pulador de anúncio a cada página do YouTube carregada.
          onPageFinished: (_) => _run(YoutubeWeb.adSkipScript),
        ),
      );
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      // autoplay=1 do embed: sem isso o Android exige um toque na página.
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  final controller = WebViewController();
  bool _disposed = false;

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
  Future<YoutubeWebState?> probe() async {
    if (_disposed) return null;
    try {
      // O pulador também é reaplicado aqui: a página pode trocar de vídeo
      // (anúncio → conteúdo) sem disparar um novo onPageFinished.
      await controller.runJavaScript(YoutubeWeb.adSkipScript);
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
    await controller.loadRequest(Uri.parse('about:blank')).catchError((_) {});
    _disposed = true;
  }
}
