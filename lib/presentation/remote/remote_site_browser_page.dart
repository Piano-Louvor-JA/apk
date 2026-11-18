import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:louvorja_piano_mobile/presentation/remote/site_mirror_sync.dart';

/// Navegador embutido para o item de site da liturgia espelhada.
///
/// O site já abriu no desktop (sem projetar) junto com este navegador: cada
/// página e a rolagem daqui vão para lá, e a seta liga/desliga as telas.
class RemoteSiteBrowserPage extends StatefulWidget {
  const RemoteSiteBrowserPage({
    super.key,
    required this.url,
    required this.title,
    required this.onToggleScreens,
    required this.onNavigate,
    required this.onScroll,
  });

  final String url;
  final String title;

  /// Liga/desliga as telas do site aberto no desktop.
  final Future<void> Function() onToggleScreens;

  /// Página aberta no celular.
  final void Function(String url) onNavigate;

  /// Rolagem do celular em proporção da página (0..1).
  final void Function(double ratio) onScroll;

  static Future<void> open(BuildContext context, RemoteSiteBrowserPage page) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  /// Link do desktop como o navegador aceita: sem esquema vira https.
  static Uri? normalize(String url) {
    final text = url.trim();
    if (text.isEmpty) return null;
    final withScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(text)
        ? text
        : 'https://$text';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }
    return uri.host.isEmpty ? null : uri;
  }

  @override
  State<RemoteSiteBrowserPage> createState() => _RemoteSiteBrowserPageState();
}

const _scrollChannel = 'PianoScroll';

/// Avisa a rolagem da página em proporção (0..1): no desktop a altura é outra.
const _scrollListenerScript = '''
(() => {
  if (window.__pianoScroll) return;
  window.__pianoScroll = true;
  const send = () => {
    const el = document.scrollingElement || document.documentElement;
    const max = el.scrollHeight - window.innerHeight;
    const ratio = max > 0 ? window.scrollY / max : 0;
    PianoScroll.postMessage(String(Math.min(1, Math.max(0, ratio))));
  };
  window.addEventListener('scroll', send, { passive: true });
})();
''';

class _RemoteSiteBrowserPageState extends State<RemoteSiteBrowserPage> {
  late final WebViewController _controller;
  late final SiteMirrorSync _sync;
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _projecting = false;
  String? _pageTitle;

  @override
  void initState() {
    super.initState();
    _sync = SiteMirrorSync(navigate: widget.onNavigate, scroll: widget.onScroll)
      ..markOpened();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        _scrollChannel,
        onMessageReceived: (message) {
          final ratio = double.tryParse(message.message);
          if (ratio != null && ratio.isFinite) {
            _sync.scrollChanged(ratio.clamp(0.0, 1.0));
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onPageFinished: (_) {
            _controller.runJavaScript(_scrollListenerScript);
            _refreshNavigation();
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _sync.urlChanged(url);
            _refreshNavigation();
          },
        ),
      );
    final uri = RemoteSiteBrowserPage.normalize(widget.url);
    if (uri != null) {
      _sync.urlChanged(uri.toString());
      _controller.loadRequest(uri);
    }
  }

  @override
  void dispose() {
    _sync.dispose();
    super.dispose();
  }

  Future<void> _refreshNavigation() async {
    final back = await _controller.canGoBack();
    final forward = await _controller.canGoForward();
    final title = await _controller.getTitle();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
      if (title != null && title.trim().isNotEmpty) _pageTitle = title.trim();
    });
  }

  Future<void> _toggleProjection() async {
    setState(() => _projecting = !_projecting);
    await widget.onToggleScreens();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return PopScope(
      // Voltar do sistema navega no site antes de fechar o navegador.
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _controller.goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('remote-site-close'),
            tooltip: 'remote.site.close'.tr(),
            icon: const Icon(TablerIcons.x),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _pageTitle ?? widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              key: const Key('remote-site-project'),
              tooltip: _projecting
                  ? 'remote.stopProjection'.tr()
                  : 'remote.site.project'.tr(),
              isSelected: _projecting,
              style: _projecting
                  ? IconButton.styleFrom(
                      backgroundColor: primary.withValues(alpha: 0.22),
                    )
                  : null,
              icon: Icon(
                _projecting ? TablerIcons.arrowDown : TablerIcons.arrowUpRight,
                color: primary,
              ),
              onPressed: _toggleProjection,
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: _progress / 100),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
        bottomNavigationBar: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                key: const Key('remote-site-back'),
                tooltip: 'remote.site.back'.tr(),
                icon: const Icon(TablerIcons.chevronLeft),
                onPressed: _canGoBack ? _controller.goBack : null,
              ),
              IconButton(
                key: const Key('remote-site-forward'),
                tooltip: 'remote.site.forward'.tr(),
                icon: const Icon(TablerIcons.chevronRight),
                onPressed: _canGoForward ? _controller.goForward : null,
              ),
              IconButton(
                key: const Key('remote-site-reload'),
                tooltip: 'remote.site.reload'.tr(),
                icon: const Icon(TablerIcons.refresh),
                onPressed: _controller.reload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
