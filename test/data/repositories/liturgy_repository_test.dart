library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('LiturgyRepository', () {
    test('loadItems retorna vazio quando nao ha dados', () {
      final repo = LiturgyRepository(prefs);
      expect(repo.loadItems(LiturgyWeekday.sunday), isEmpty);
    });

    test('saveItems e loadItems roundtrip', () async {
      final repo = LiturgyRepository(prefs);
      await repo.saveItems(LiturgyWeekday.sunday, [
        const LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'Hino'),
      ]);
      final items = repo.loadItems(LiturgyWeekday.sunday);
      expect(items.length, 1);
      expect(items.first.name, 'Hino');
    });

    test('loadItems com JSON invalido retorna vazio (catch)', () async {
      await prefs.setString('liturgy_items_sunday', 'not_a_json_list');
      final repo = LiturgyRepository(prefs);
      expect(repo.loadItems(LiturgyWeekday.sunday), isEmpty);
    });

    test('loadNotes retorna vazio quando nao ha notas', () {
      final repo = LiturgyRepository(prefs);
      expect(repo.loadNotes(LiturgyWeekday.monday), '');
    });

    test('saveNotes e loadNotes roundtrip', () async {
      final repo = LiturgyRepository(prefs);
      await repo.saveNotes(LiturgyWeekday.friday, 'Anotacoes do culto');
      expect(repo.loadNotes(LiturgyWeekday.friday), 'Anotacoes do culto');
    });

    test('cloneDay copia itens e notas', () async {
      final repo = LiturgyRepository(prefs);
      await repo.saveItems(LiturgyWeekday.sunday, [
        const LiturgyItem(
          id: '1',
          type: LiturgyItemType.annotation,
          name: 'Nota',
        ),
      ]);
      await repo.saveNotes(LiturgyWeekday.sunday, 'Notas dom');

      await repo.cloneDay(LiturgyWeekday.sunday, LiturgyWeekday.wednesday);

      expect(repo.loadItems(LiturgyWeekday.wednesday).length, 1);
      expect(repo.loadNotes(LiturgyWeekday.wednesday), 'Notas dom');
    });

    test('clearDay remove itens e notas', () async {
      final repo = LiturgyRepository(prefs);
      await repo.saveItems(LiturgyWeekday.saturday, [
        const LiturgyItem(
          id: '1',
          type: LiturgyItemType.prayer,
          name: 'Oracao',
        ),
      ]);
      await repo.saveNotes(LiturgyWeekday.saturday, 'Notas sab');

      await repo.clearDay(LiturgyWeekday.saturday);

      expect(repo.loadItems(LiturgyWeekday.saturday), isEmpty);
      expect(repo.loadNotes(LiturgyWeekday.saturday), '');
    });
  });
}
