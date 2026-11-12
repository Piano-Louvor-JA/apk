import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LiturgyRepository repo;
  late LiturgyBloc bloc;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LiturgyRepository(await SharedPreferences.getInstance());
    bloc = LiturgyBloc(repo)
      ..add(const LiturgyLoadRequested(LiturgyWeekday.sunday));
    await bloc.stream.first;
  });
  tearDown(() => bloc.close());
  Future<LiturgyLoaded> dispatch(LiturgyEvent event) {
    final next = bloc.stream.first;
    bloc.add(event);
    return next.then((s) => s as LiturgyLoaded);
  }

  test(
    'mídia concluída mantém relógio até o operador parar a sessão',
    () async {
      await dispatch(
        const LiturgyAddItem(
          LiturgyItem(id: 'm', type: LiturgyItemType.music, name: 'Hino'),
        ),
      );
      await dispatch(const LiturgySelectItem('m'));
      final done = await dispatch(const LiturgyMarkDone('m'));
      expect(done.sessionStartedAt, isNotNull);
      final stopped = await dispatch(LiturgySessionClockStopped());
      expect(stopped.sessionStartedAt, isNull);
    },
  );
  test(
    'primeiro momento registra início real e texto/site permanecem selecionados após abrir',
    () async {
      for (final type in [LiturgyItemType.annotation, LiturgyItemType.site]) {
        await dispatch(
          LiturgyAddItem(
            LiturgyItem(id: type.name, type: type, name: 'Conteúdo'),
          ),
        );
        var selected = await dispatch(LiturgySelectItem(type.name));
        expect(selected.startTime, isNotNull);
        expect(selected.sessionStartedAt, isNotNull);
        selected = await dispatch(LiturgyMarkDone(type.name));
        expect(selected.items.last.done, isTrue);
        expect(selected.selectedItemId, type.name);
        selected = await dispatch(LiturgyReloadRequested());
        expect(selected.selectedItemId, type.name);
        selected = await dispatch(LiturgySelectItem(type.name));
        expect(selected.selectedItemId, type.name);
      }
    },
  );
  test('ordenação recebida também grava a avulsa selecionada', () async {
    await dispatch(const LiturgyCustomCreated('Especial'));
    final items = [
      const LiturgyItem(
        id: 'x',
        type: LiturgyItemType.annotation,
        name: 'Texto',
      ),
    ];
    final state = await dispatch(LiturgyItemsReordered(items));
    expect(repo.loadCustomLiturgies().single.items.single.id, 'x');
    expect(repo.loadItems(state.selectedDay), isEmpty);
  });
  test('recarregar mantém seleção enquanto o item existir', () async {
    await dispatch(
      const LiturgyAddItem(
        LiturgyItem(id: 'm', type: LiturgyItemType.annotation, name: 'Texto'),
      ),
    );
    await dispatch(const LiturgySelectItem('m'));
    expect((await dispatch(LiturgyReloadRequested())).selectedItemId, 'm');
  });
  test(
    'avulsa usa a mesma timeline e preserva semana, notas e horários',
    () async {
      var state = await dispatch(const LiturgyCustomCreated('Casamento'));
      expect(state.customId, isNotNull);
      final key = state.contextKey;
      state = await dispatch(
        const LiturgyAddItem(
          LiturgyItem(id: 'm', type: LiturgyItemType.music, name: 'Hino'),
        ),
      );
      expect(repo.readItems(key).single.name, 'Hino');
      expect(repo.loadItems(LiturgyWeekday.sunday), isEmpty);
      state = await dispatch(
        const LiturgySessionTimesChanged(startTime: '08:00', endTime: '09:30'),
      );
      expect(state.endTime, '09:30');
      await dispatch(const LiturgyDayChanged(LiturgyWeekday.monday));
      state = await dispatch(LiturgyCustomSelected(key.substring(7)));
      expect(state.items.single.name, 'Hino');
      expect(state.startTime, '08:00');
    },
  );
  test(
    'clona da avulsa para dia vazio com novos IDs e sem alterar notas',
    () async {
      final custom = await repo.createCustom('Especial');
      await repo.writeItems('custom:${custom.id}', [
        const LiturgyItem(
          id: 'x',
          type: LiturgyItemType.annotation,
          name: 'Texto',
          done: true,
        ),
      ]);
      await dispatch(const LiturgyUpdateNotes('Nota do destino'));
      final state = await dispatch(LiturgyCloneSource('custom:${custom.id}'));
      expect(state.items.single.id, isNot('x'));
      expect(state.items.single.done, isFalse);
      expect(state.notes, 'Nota do destino');
    },
  );
  test(
    'iniciar mídia marca concluído uma vez e limpa seleção transitória',
    () async {
      await dispatch(
        const LiturgyAddItem(
          LiturgyItem(id: 'm', type: LiturgyItemType.music, name: 'Hino'),
        ),
      );
      await dispatch(const LiturgySelectItem('m'));
      var state = await dispatch(const LiturgyMarkDone('m'));
      expect(state.items.single.done, isTrue);
      expect(state.selectedItemId, isNull);
      bloc.add(const LiturgyMarkDone('m'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((bloc.state as LiturgyLoaded).items.single.done, isTrue);
    },
  );
  test(
    'cadeado impede edição e exclusão mas permite acrescentar, ordenar e anotar',
    () async {
      await dispatch(LiturgyLockToggled());
      await dispatch(
        const LiturgyAddItem(
          LiturgyItem(id: 'a', type: LiturgyItemType.annotation, name: 'A'),
        ),
      );
      await dispatch(const LiturgyUpdateNotes('Equipe'));
      bloc.add(const LiturgyDeleteItem('a'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final state = bloc.state as LiturgyLoaded;
      expect(state.items.single.name, 'A');
      expect(state.notes, 'Equipe');
      expect(state.locked, isTrue);
    },
  );
}
