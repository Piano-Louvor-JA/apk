import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/core/utils/reorder.dart';

/// Visual da linha enquanto é arrastada (paridade com o desktop): fundo
/// laranja forte, borda e sombra, só na linha que se move. O espaço onde
/// ela vai entrar o próprio `ReorderableListView` abre na lista.
Widget youtubeDragDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) => AnimatedBuilder(
  animation: animation,
  child: child,
  builder: (context, child) {
    final scheme = Theme.of(context).colorScheme;
    final t = Curves.easeInOut.transform(animation.value);
    return Material(
      key: const Key('youtube-dragging'),
      elevation: lerpDouble(0, 10, t)!,
      color: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.32 * t),
        scheme.surface,
      ),
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.primary, width: 2 * t),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  },
);

/// Lista do módulo YouTube que se reordena arrastando (toque e segure no
/// celular). Trabalha com IDs, então funciona também com a lista filtrada.
Widget youtubeReorderableList<T>({
  Key? key,
  required List<T> items,
  required String Function(T item) idOf,
  required Widget Function(BuildContext context, T item) itemBuilder,
  required void Function(String fromId, String toId) onMove,
  ScrollController? controller,
  Widget? footer,
}) => ReorderableListView.builder(
  key: key,
  scrollController: controller,
  padding: const EdgeInsets.only(bottom: 32),
  itemCount: items.length,
  proxyDecorator: youtubeDragDecorator,
  footer: footer,
  onReorderItem: (oldIndex, newIndex) {
    final ids = reorderIds(items, idOf, oldIndex, newIndex);
    if (ids != null) onMove(ids.from, ids.to);
  },
  itemBuilder: (context, i) => KeyedSubtree(
    key: ValueKey('youtube-row-${idOf(items[i])}'),
    child: itemBuilder(context, items[i]),
  ),
);

/// Alça visual de arrastar (o arraste é tocar e segurar a linha).
class YoutubeGrip extends StatelessWidget {
  const YoutubeGrip({super.key, required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: hint,
    child: Padding(
      padding: const EdgeInsets.only(right: 6, top: 18),
      child: Icon(
        TablerIcons.gripVertical,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
