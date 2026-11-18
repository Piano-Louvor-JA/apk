import 'dart:async';

/// Espelha a navegação e a rolagem do navegador do celular no site aberto no
/// desktop.
///
/// O desktop ainda está abrindo o site quando o navegador abre: a página
/// atual vai com novas tentativas (o desktop ignora endereço repetido, então
/// repetir não recarrega). A rolagem vai no máximo a cada [scrollInterval],
/// sempre terminando na última posição.
class SiteMirrorSync {
  SiteMirrorSync({
    required this.navigate,
    required this.scroll,
    this.retryDelays = const [
      Duration(milliseconds: 1500),
      Duration(milliseconds: 3500),
    ],
    this.scrollInterval = const Duration(milliseconds: 150),
  });

  final void Function(String url) navigate;
  final void Function(double ratio) scroll;
  final List<Duration> retryDelays;
  final Duration scrollInterval;

  bool _opened = false;
  String? _current;
  String? _sent;
  final List<Timer> _timers = [];
  Timer? _scrollTimer;
  double? _pendingScroll;

  void urlChanged(String url) {
    _current = url;
    if (_opened && url != _sent) _send(url);
  }

  void markOpened() {
    if (_opened) return;
    _opened = true;
    for (final delay in retryDelays) {
      _timers.add(
        Timer(delay, () {
          final current = _current;
          if (current != null) _send(current);
        }),
      );
    }
  }

  void scrollChanged(double ratio) {
    if (!_opened) return;
    if (_scrollTimer != null) {
      _pendingScroll = ratio;
      return;
    }
    scroll(ratio);
    _scrollTimer = Timer(scrollInterval, _flushScroll);
  }

  void _flushScroll() {
    _scrollTimer = null;
    final pending = _pendingScroll;
    _pendingScroll = null;
    if (pending != null) scrollChanged(pending);
  }

  void _send(String url) {
    _sent = url;
    navigate(url);
  }

  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }
}
