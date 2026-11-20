import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/utils/reorder.dart';

String id(String s) => s;

void main() {
  test('soltar sobre outro item: desce para depois dele, sobe para antes', () {
    expect(moveById(['a', 'b', 'c', 'd'], id, 'a', 'c'), ['b', 'c', 'a', 'd']);
    expect(moveById(['a', 'b', 'c', 'd'], id, 'd', 'b'), ['a', 'd', 'b', 'c']);
  });

  test('mesmo item ou ID desconhecido: cópia igual', () {
    final list = ['a', 'b'];
    expect(moveById(list, id, 'a', 'a'), list);
    expect(moveById(list, id, 'x', 'a'), list);
    expect(identical(moveById(list, id, 'a', 'x'), list), isFalse);
  });

  test('ordem salva: novos no topo, salvos na ordem, sumidos ignorados', () {
    expect(applyOrder(['n1', 'a', 'b', 'n2', 'c'], id, ['c', 'x', 'a', 'b']), [
      'n1',
      'n2',
      'c',
      'a',
      'b',
    ]);
    expect(applyOrder(['a', 'b'], id, const []), ['a', 'b']);
  });

  test(
    'índices do ReorderableListView viram IDs (inclusive lista filtrada)',
    () {
      final visible = ['a', 'b', 'c'];
      // onReorderItem já entrega a posição final.
      expect(reorderIds(visible, id, 0, 2), (from: 'a', to: 'c'));
      expect(reorderIds(visible, id, 2, 0), (from: 'c', to: 'a'));
      expect(reorderIds(visible, id, 1, 1), isNull);
      expect(reorderIds(visible, id, 1, 3), isNull);
      expect(reorderIds(visible, id, 5, 0), isNull);
      expect(reorderIds(visible, id, 0, 9), isNull);
    },
  );
}
