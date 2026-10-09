import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

void main() {
  test('ScheduledCategory serializa e restaura', () {
    const category = ScheduledCategory(id: 'culto', name: 'Culto Divino');
    expect(
      ScheduledCategory.fromJson(category.toJson()).name,
      'Culto Divino',
    );
  });

  test('ScheduledItem JSON preserva os campos opcionais', () {
    final item = ScheduledItem(
      id: '1',
      categoryId: 'culto',
      date: DateTime.utc(2026, 10, 8, 12),
      name: 'Roteiro',
      filePath: 'C:/roteiro.pdf',
      isRelativePath: true,
      notes: 'Leitura',
    );

    final restored = ScheduledItem.fromJson(item.toJson());
    expect(restored.filePath, 'C:/roteiro.pdf');
    expect(restored.isRelativePath, isTrue);
    expect(restored.notes, 'Leitura');
    expect(restored.date, item.date);
  });

  test('ScheduledItem legado usa defaults e copyWith altera somente pedido', () {
    final legacy = ScheduledItem.fromJson({
      'id': '2',
      'categoryId': 'outros',
      'date': '2026-10-08T00:00:00.000',
      'name': 'Avisos',
    });
    final changed = legacy.copyWith(notes: 'Novo');

    expect(legacy.filePath, isEmpty);
    expect(legacy.isRelativePath, isFalse);
    expect(legacy.notes, isEmpty);
    expect(changed.notes, 'Novo');
    expect(changed.filePath, isEmpty);
  });
}
