/// Arrastar e soltar: move o item `fromId` para a posição de `toId`.
/// Descendo, ele fica logo depois do alvo; subindo, logo antes (como no
/// desktop). Sem o que mover, devolve uma cópia igual.
List<T> moveById<T>(
  List<T> list,
  String Function(T item) idOf,
  String fromId,
  String toId,
) {
  final from = list.indexWhere((item) => idOf(item) == fromId);
  final to = list.indexWhere((item) => idOf(item) == toId);
  final next = [...list];
  if (from < 0 || to < 0 || from == to) return next;
  final moved = next.removeAt(from);
  next.insert(to, moved);
  return next;
}

/// Aplica uma ordem salva (IDs): o que não está nela (novo) vai para o
/// topo, na ordem em que veio; IDs que não existem mais são ignorados.
List<T> applyOrder<T>(
  List<T> list,
  String Function(T item) idOf,
  List<String> order,
) {
  final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
  final fresh = list.where((item) => !rank.containsKey(idOf(item))).toList();
  final ranked = list.where((item) => rank.containsKey(idOf(item))).toList()
    ..sort((a, b) => rank[idOf(a)]!.compareTo(rank[idOf(b)]!));
  return [...fresh, ...ranked];
}

/// Índices do `ReorderableListView.onReorderItem` (lista visível, talvez
/// filtrada; `newIndex` já é a posição final) para IDs.
({String from, String to})? reorderIds<T>(
  List<T> visible,
  String Function(T item) idOf,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex < 0 || oldIndex >= visible.length) return null;
  if (newIndex == oldIndex || newIndex < 0 || newIndex >= visible.length) {
    return null;
  }
  return (from: idOf(visible[oldIndex]), to: idOf(visible[newIndex]));
}
