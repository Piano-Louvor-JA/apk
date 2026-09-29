// ignore_for_file: unused_element
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';

void main() {
  late LiturgyRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = LiturgyRepository(prefs);
  });

  group('LiturgyRepository', () {
    test('loadItems retorna vazio quando nao salvo', () {
      expect(repo.loadItems(LiturgyWeekday.monday), isEmpty);
    });

    test('saveItems + loadItems roundtrip', () async {
      const items = [
        LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'Hino'),
      ];
      await repo.saveItems(LiturgyWeekday.monday, items);
      final loaded = repo.loadItems(LiturgyWeekday.monday);
      expect(loaded.length, 1);
      expect(loaded[0].name, 'Hino');
    });

    test('loadNotes retorna vazio quando nao salvo', () {
      expect(repo.loadNotes(LiturgyWeekday.monday), '');
    });

    test('saveNotes + loadNotes', () async {
      await repo.saveNotes(LiturgyWeekday.tuesday, 'Notas do culto');
      expect(repo.loadNotes(LiturgyWeekday.tuesday), 'Notas do culto');
    });

    test('cloneDay copia itens e notas', () async {
      const items = [
        LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'A'),
      ];
      await repo.saveItems(LiturgyWeekday.monday, items);
      await repo.saveNotes(LiturgyWeekday.monday, 'Notas seg');
      await repo.cloneDay(LiturgyWeekday.monday, LiturgyWeekday.wednesday);
      expect(repo.loadItems(LiturgyWeekday.wednesday).length, 1);
      expect(repo.loadNotes(LiturgyWeekday.wednesday), 'Notas seg');
    });

    test('clearDay remove itens e notas', () async {
      await repo.saveItems(LiturgyWeekday.monday, const [
        LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'A'),
      ]);
      await repo.saveNotes(LiturgyWeekday.monday, 'Notas');
      await repo.clearDay(LiturgyWeekday.monday);
      expect(repo.loadItems(LiturgyWeekday.monday), isEmpty);
      expect(repo.loadNotes(LiturgyWeekday.monday), '');
    });
  });

  group('LiturgyBloc', () {
    late LiturgyBloc bloc;

    setUp(() {
      bloc = LiturgyBloc(repo);
    });

    tearDown(() => bloc.close());

    test('load emite Loaded', () async {
      bloc.add(const LiturgyLoadRequested(LiturgyWeekday.monday));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<LiturgyLoaded>());
    });

    test('addItem adiciona item', () async {
      bloc.add(const LiturgyLoadRequested(LiturgyWeekday.monday));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(
        const LiturgyAddItem(
          LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'Hino'),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      final state = bloc.state as LiturgyLoaded;
      expect(state.items.length, 1);
    });

    test('deleteItem remove item e seus filhos', () async {
      bloc.add(const LiturgyLoadRequested(LiturgyWeekday.monday));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(
        const LiturgyAddItem(
          LiturgyItem(id: 'cat1', type: LiturgyItemType.category, name: 'Cat'),
        ),
      );
      bloc.add(
        const LiturgyAddItem(
          LiturgyItem(
            id: 'item1',
            type: LiturgyItemType.music,
            name: 'Sub',
            categoryId: 'cat1',
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const LiturgyDeleteItem('cat1'));
      await Future.delayed(const Duration(milliseconds: 50));
      final state = bloc.state as LiturgyLoaded;
      expect(state.items, isEmpty);
    });

    test('toggleDone inverte done', () async {
      bloc.add(const LiturgyLoadRequested(LiturgyWeekday.monday));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(
        const LiturgyAddItem(
          LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'A'),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const LiturgyToggleDone('1'));
      await Future.delayed(const Duration(milliseconds: 50));
      final state = bloc.state as LiturgyLoaded;
      expect(state.items.first.done, true);
    });

    test('updateItem altera campos', () async {
      bloc.add(const LiturgyLoadRequested(LiturgyWeekday.monday));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(
        const LiturgyAddItem(
          LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'Original'),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(
        const LiturgyUpdateItem(
          LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'Editado'),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      final state = bloc.state as LiturgyLoaded;
      expect(state.items.first.name, 'Editado');
    });

    test('reorderItems move item', () async {
      bloc.add(const LiturgyLoadRequested(LiturgyWeekday.monday));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(
        const LiturgyAddItem(
          LiturgyItem(id: '1', type: LiturgyItemType.category, name: 'A'),
        ),
      );
      bloc.add(
        const LiturgyAddItem(
          LiturgyItem(id: '2', type: LiturgyItemType.category, name: 'B'),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const LiturgyReorderItems(0, 2));
      await Future.delayed(const Duration(milliseconds: 50));
      final state = bloc.state as LiturgyLoaded;
      expect(state.items.first.id, '2');
    });

    test('clearDay limpa tudo', () async {
      bloc.add(const LiturgyLoadRequested(LiturgyWeekday.monday));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(
        const LiturgyAddItem(
          LiturgyItem(id: '1', type: LiturgyItemType.category, name: 'A'),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(LiturgyClearDay());
      await Future.delayed(const Duration(milliseconds: 50));
      final state = bloc.state as LiturgyLoaded;
      expect(state.items, isEmpty);
      expect(state.notes, '');
    });

    test('updateNotes salva notas', () async {
      bloc.add(const LiturgyLoadRequested(LiturgyWeekday.monday));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const LiturgyUpdateNotes('Notas do culto'));
      await Future.delayed(const Duration(milliseconds: 50));
      final state = bloc.state as LiturgyLoaded;
      expect(state.notes, 'Notas do culto');
    });

    test('cloneDay copia de outro dia', () async {
      // Salva itens em tuesday primeiro
      await repo.saveItems(LiturgyWeekday.tuesday, const [
        LiturgyItem(id: 'x', type: LiturgyItemType.music, name: 'Clonado'),
      ]);
      bloc.add(const LiturgyLoadRequested(LiturgyWeekday.monday));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const LiturgyCloneDay(LiturgyWeekday.tuesday));
      await Future.delayed(const Duration(milliseconds: 50));
      final state = bloc.state as LiturgyLoaded;
      expect(state.items.length, 1);
      expect(state.items.first.name, 'Clonado');
    });

    test('dayChanged carrega outro dia', () async {
      await repo.saveItems(LiturgyWeekday.wednesday, const [
        LiturgyItem(id: 'w', type: LiturgyItemType.prayer, name: 'Oracao'),
      ]);
      bloc.add(const LiturgyLoadRequested(LiturgyWeekday.monday));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const LiturgyDayChanged(LiturgyWeekday.wednesday));
      await Future.delayed(const Duration(milliseconds: 50));
      final state = bloc.state as LiturgyLoaded;
      expect(state.selectedDay, LiturgyWeekday.wednesday);
      expect(state.items.first.name, 'Oracao');
    });

    test('repository getter', () {
      expect(bloc.repository, same(repo));
    });
  });
}
