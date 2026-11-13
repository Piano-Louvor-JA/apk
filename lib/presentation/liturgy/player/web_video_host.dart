import 'package:flutter/material.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_video.dart';

/// Um único player web (YouTube) para a barra, o painel minimizado e o
/// player expandido. Cada um mostra só um [WebVideoSlot]; a WebView fica
/// montada sempre no mesmo lugar da árvore ([WebVideoLayer]) e apenas se
/// move até o espaço visível. Remontar a WebView a tirava da tela, o
/// YouTube parava e voltava como outro player.
class WebVideoSlots extends ChangeNotifier {
  final List<_WebVideoSlotState> _slots = [];
  Rect? _rect;

  /// Espaço visível onde o vídeo aparece; null = nenhum (vídeo estacionado).
  Rect? get rect => _rect;

  void _add(_WebVideoSlotState slot) {
    _slots.add(slot);
    _refresh();
  }

  // Sai durante a desmontagem (árvore travada): recalcula no próximo quadro.
  void _remove(_WebVideoSlotState slot) {
    _slots.remove(slot);
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _refresh())
      ..scheduleFrame();
  }

  void _refresh() {
    Rect? next;
    for (final slot in _slots.reversed) {
      final rect = slot._visibleRect;
      if (rect != null) {
        next = rect;
        break;
      }
    }
    if (next == _rect) return;
    _rect = next;
    notifyListeners();
  }
}

final webVideoSlots = WebVideoSlots();

/// Rota do topo do navigator raiz. A barra da Liturgia vive no navigator da
/// aba, onde continua "atual" com um diálogo aberto no raiz; sem isto o
/// vídeo ficava por cima da janela de fechar mídia.
class TopRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _stack = [];
  Route<dynamic>? get top => _stack.lastOrNull;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (newRoute == null) return;
    if (index < 0) {
      _stack.add(newRoute);
    } else {
      _stack[index] = newRoute;
    }
  }
}

final webVideoRoutes = TopRouteObserver();

/// Espaço do vídeo na barra; a WebView é desenhada por cima dele.
class WebVideoSlot extends StatefulWidget {
  const WebVideoSlot({super.key, this.slots, this.routes});
  final WebVideoSlots? slots;
  final TopRouteObserver? routes;
  @override
  State<WebVideoSlot> createState() => _WebVideoSlotState();
}

class _WebVideoSlotState extends State<WebVideoSlot> {
  WebVideoSlots get _slots => widget.slots ?? webVideoSlots;
  Rect? _visibleRect;

  @override
  void initState() {
    super.initState();
    _slots._add(this);
    _track();
  }

  // Confere a posição a cada quadro desenhado (rolagem, animação do sheet),
  // sem pedir quadros extras: parado, nada roda.
  void _track() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = _measure();
      if (next != _visibleRect) {
        _visibleRect = next;
        _slots._refresh();
      }
      _track();
    });
  }

  Rect? _measure() {
    if (!TickerMode.valuesOf(context).enabled) return null;
    if (ModalRoute.isCurrentOf(context) == false) return null;
    // Diálogo/sheet no topo do app: só aparece se o vídeo estiver nele.
    final top = (widget.routes ?? webVideoRoutes).top;
    if (top is PopupRoute && ModalRoute.of(context) != top) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.isEmpty) return null;
    // Parcialmente fora da área rolável: não desenha por cima de outra coisa.
    final scrollable = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (scrollable is RenderBox && scrollable.hasSize) {
      final viewport = scrollable.localToGlobal(Offset.zero) & scrollable.size;
      if (viewport.intersect(rect) != rect) return null;
    }
    return rect;
  }

  @override
  void dispose() {
    _slots._remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Colors.black, child: SizedBox.expand());
}

/// Camada fixa no topo do app que mantém a WebView montada.
class WebVideoLayer extends StatelessWidget {
  const WebVideoLayer({super.key, required this.video, this.slots});
  final LiturgyWebVideo? video;
  final WebVideoSlots? slots;

  @override
  Widget build(BuildContext context) {
    final page = video;
    if (page == null) return const SizedBox.shrink();
    final host = slots ?? webVideoSlots;
    return ListenableBuilder(
      listenable: host,
      builder: (context, child) {
        final rect = host.rect;
        // Sem espaço visível: 1 px no canto, ainda na tela (não pausa).
        final place = rect ?? const Rect.fromLTWH(0, 0, 1, 1);
        return Positioned.fromRect(
          key: const Key('web-video-layer'),
          rect: place,
          child: child!,
        );
      },
      child: KeyedSubtree(key: ObjectKey(page), child: page.view()),
    );
  }
}
