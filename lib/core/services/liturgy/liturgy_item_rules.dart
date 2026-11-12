import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

/// Regras de domínio de liturgy-item-helpers.ts do desktop.
abstract final class LiturgyItemRules {
  static const withoutDuration = {
    LiturgyItemType.category,
    LiturgyItemType.annotation,
    LiturgyItemType.images,
    LiturgyItemType.pdf,
    LiturgyItemType.presentation,
    LiturgyItemType.site,
  };

  static int durationMs(LiturgyItem item) => withoutDuration.contains(item.type)
      ? 0
      : item.durationMs.clamp(0, 5940000);

  static int categoryEnd(List<LiturgyItem> items, String categoryId) {
    final index = items.indexWhere(
      (e) => e.type == LiturgyItemType.category && e.id == categoryId,
    );
    if (index < 0) return items.length;
    var end = index + 1;
    while (end < items.length &&
        items[end].type != LiturgyItemType.category &&
        items[end].categoryId == categoryId) {
      end++;
    }
    return end;
  }

  static List<LiturgyItem> insert(List<LiturgyItem> items, LiturgyItem item) {
    final next = [...items];
    final at = item.type != LiturgyItemType.category && item.categoryId != null
        ? categoryEnd(items, item.categoryId!)
        : items.length;
    next.insert(at, item);
    return next;
  }

  /// Índices de destino no contrato ReorderableListView (antes da remoção).
  static List<LiturgyItem> reorder(List<LiturgyItem> items, int from, int to) {
    if (from < 0 || from >= items.length || to < 0 || to > items.length) {
      return items;
    }
    final moved = items[from];
    var end = from + 1;
    if (moved.type == LiturgyItemType.category) {
      end = categoryEnd(items, moved.id);
      if (to >= from && to <= end) return items;
      if (to < items.length) {
        final target = items[to];
        final parent = target.type == LiturgyItemType.category
            ? to
            : items.indexWhere((e) => e.id == target.categoryId);
        if (parent >= 0) {
          to = from < parent ? categoryEnd(items, items[parent].id) : parent;
        }
      }
    }
    final block = items.sublist(from, end);
    final next = [...items]..removeRange(from, end);
    final destination = (to > from ? to - block.length : to).clamp(
      0,
      next.length,
    );
    next.insertAll(destination, block);
    return next;
  }
}
