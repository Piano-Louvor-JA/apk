import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'CRUD de rotação e conteúdo persiste, enfileira e exclui em cascata',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ScheduledRepository(prefs);
      final category = await repo.upsertCategory(name: 'Inicial');
      await repo.upsertItem(
        ScheduledItem(
          id: 'e',
          categoryId: category.id,
          date: DateTime(2026, 11, 14),
          name: 'Hino',
          content: {'kind': 'music', 'musicId': 42},
        ),
      );
      expect(
        ScheduledRepository(
          prefs,
        ).findOn(category.id, DateTime(2026, 11, 14))?.content?['musicId'],
        42,
      );
      expect(
        prefs.getString('louvorja.sync.outbox.v1'),
        contains('scheduled::items'),
      );
      await repo.upsertCategory(id: category.id, name: 'Hino de abertura');
      expect(repo.loadCategories().single.name, 'Hino de abertura');
      await repo.deleteCategory(category.id);
      expect(repo.loadCategories(), isEmpty);
      expect(repo.loadItems(), isEmpty);
    },
  );
}
