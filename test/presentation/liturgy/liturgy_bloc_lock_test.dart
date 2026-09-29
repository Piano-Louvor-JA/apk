// Testes de lock, delete do dia e reorder de itens da liturgia.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';

void main() {
  late SharedPreferences prefs;
  late LiturgyRepository repo;
  late LiturgyBloc bloc;

  LiturgyItem item(String name, {String? categoryId}) => LiturgyItem(
    id: 'id-$name',
    type: categoryId == null ? LiturgyItemType.category : LiturgyItemType.music,
    name: name,
    categoryId: categoryId,
  );

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = LiturgyRepository(prefs);
    bloc = LiturgyBloc(repo);
    bloc.add(LiturgyLoadRequested(LiturgyWeekday.monday));
    await bloc.stream.firstWhere((s) => s is LiturgyLoaded);
  });

  test('lock persiste no repository e bloqueia mutações', () async {
    bloc.add(LiturgyAddItem(item('Categoria')));
    await bloc.stream.firstWhere(
      (s) => s is LiturgyLoaded && s.items.isNotEmpty,
    );

    // lock
    bloc.add(LiturgyLockToggled());
    final locked = await bloc.stream.firstWhere(
      (s) => s is LiturgyLoaded && s.locked,
    );
    expect((locked as LiturgyLoaded).locked, isTrue);
    expect(repo.isLocked(LiturgyWeekday.monday), isTrue);

    // mutações bloqueadas
    final itemsBefore = locked.items.length;
    bloc.add(LiturgyAddItem(item('Outra')));
    bloc.add(LiturgyDeleteItem('id-Categoria'));
    bloc.add(LiturgyReorderItems(0, 1));
    bloc.add(LiturgyClearDay());
    await Future.delayed(const Duration(milliseconds: 100));
    expect((bloc.state as LiturgyLoaded).items.length, itemsBefore);

    // unlock
    bloc.add(LiturgyLockToggled());
    await bloc.stream.firstWhere((s) => s is LiturgyLoaded && !s.locked);
    expect(repo.isLocked(LiturgyWeekday.monday), isFalse);
  });

  test('clearDay limpa itens do dia', () async {
    bloc.add(LiturgyAddItem(item('A')));
    await bloc.stream.firstWhere(
      (s) => s is LiturgyLoaded && s.items.isNotEmpty,
    );
    bloc.add(LiturgyClearDay());
    await bloc.stream.firstWhere((s) => s is LiturgyLoaded && s.items.isEmpty);
    expect(repo.loadItems(LiturgyWeekday.monday), isEmpty);
  });

  test('reorder por lista completa persiste nova ordem', () async {
    bloc.add(LiturgyAddItem(item('A')));
    await bloc.stream.firstWhere(
      (s) => s is LiturgyLoaded && s.items.length == 1,
    );
    bloc.add(LiturgyAddItem(item('B')));
    await bloc.stream.firstWhere(
      (s) => s is LiturgyLoaded && s.items.length == 2,
    );

    final current = (bloc.state as LiturgyLoaded).items;
    final reordered = current.reversed.toList();
    bloc.add(LiturgyItemsReordered(reordered));
    await bloc.stream.firstWhere(
      (s) => s is LiturgyLoaded && s.items.first.name == 'B',
    );
    expect(repo.loadItems(LiturgyWeekday.monday).first.name, 'B');
  });

  test('reorder bloqueado quando lockado', () async {
    bloc.add(LiturgyAddItem(item('A')));
    await bloc.stream.firstWhere(
      (s) => s is LiturgyLoaded && s.items.length == 1,
    );
    bloc.add(LiturgyAddItem(item('B')));
    await bloc.stream.firstWhere(
      (s) => s is LiturgyLoaded && s.items.length == 2,
    );

    bloc.add(LiturgyLockToggled());
    await bloc.stream.firstWhere((s) => s is LiturgyLoaded && s.locked);

    final current = (bloc.state as LiturgyLoaded).items;
    bloc.add(LiturgyItemsReordered(current.reversed.toList()));
    await Future.delayed(const Duration(milliseconds: 100));
    expect((bloc.state as LiturgyLoaded).items.first.name, 'A');
  });
}
