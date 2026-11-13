import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const category = LiturgyItem(
    id: 'cat',
    type: LiturgyItemType.category,
    name: 'Culto',
  );
  const child = LiturgyItem(
    id: 'child',
    type: LiturgyItemType.music,
    name: 'Hino',
    categoryId: 'cat',
    done: true,
  );
  const other = LiturgyItem(
    id: 'other',
    type: LiturgyItemType.category,
    name: 'Outra',
  );
  late LiturgyRepository repo;
  late LiturgyBloc bloc;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LiturgyRepository(await SharedPreferences.getInstance());
    await repo.saveItems(LiturgyWeekday.sunday, [category, other]);
    bloc = LiturgyBloc(repo)
      ..add(const LiturgyLoadRequested(LiturgyWeekday.sunday));
    await bloc.stream.first;
  });
  tearDown(() => bloc.close());

  test('subitem novo fica no bloco da categoria, como no desktop', () async {
    bloc.add(const LiturgyAddItem(child));
    final state = await bloc.stream.first as LiturgyLoaded;
    expect(state.items.map((e) => e.id), ['cat', 'child', 'other']);
    expect(repo.loadItems(LiturgyWeekday.sunday).map((e) => e.id), [
      'cat',
      'child',
      'other',
    ]);
  });

  test(
    'clonar gera novos IDs, remapeia categoria e limpa concluídos',
    () async {
      await repo.saveItems(LiturgyWeekday.sunday, [category, child]);
      await repo.cloneDay(LiturgyWeekday.sunday, LiturgyWeekday.monday);
      final cloned = repo.loadItems(LiturgyWeekday.monday);
      expect(cloned.first.id, isNot('cat'));
      expect(cloned.last.id, isNot('child'));
      expect(cloned.last.categoryId, cloned.first.id);
      expect(cloned.last.done, isFalse);
      expect(repo.loadItems(LiturgyWeekday.sunday).last.done, isTrue);
    },
  );

  test('reordenar categoria move também seus filhos', () async {
    await repo.saveItems(LiturgyWeekday.sunday, [category, child, other]);
    bloc.add(const LiturgyLoadRequested(LiturgyWeekday.sunday));
    await bloc.stream.first;
    bloc.add(const LiturgyReorderItems(0, 3));
    final state = await bloc.stream.first as LiturgyLoaded;
    expect(state.items.map((e) => e.id), ['other', 'cat', 'child']);
  });

  test(
    'concluir categoria conclui filhos, desfazer filho atualiza categoria',
    () async {
      await repo.saveItems(LiturgyWeekday.sunday, [
        category,
        child.copyWith(done: false),
      ]);
      bloc.add(const LiturgyLoadRequested(LiturgyWeekday.sunday));
      await bloc.stream.first;
      bloc.add(const LiturgyToggleDone('cat'));
      final completed = await bloc.stream.first as LiturgyLoaded;
      expect(completed.items.every((e) => e.done), isTrue);
      bloc.add(const LiturgyToggleDone('child'));
      final undone = await bloc.stream.first as LiturgyLoaded;
      expect(undone.items.every((e) => !e.done), isTrue);
    },
  );

  test('contrato desktop sobrevive a carregar e salvar no APK', () async {
    final wire = <String, dynamic>{
      'id': 'music',
      'type': 'music',
      'name': 'Hino',
      'subtitle': 'Álbum',
      'done': true,
      'durationMs': 183000,
      'accentColor': '#00E676',
      'complementaryTitle': 'Entrada',
      'notesHtml': '<p>Texto</p>',
      'titleColor': '#FF0000',
      'musicMode': 'instrumental',
      'scheduledRotationId': 'rotation',
      'presentationEngine': 'powerpoint',
      'playerId': 'vlc',
      'filePaths': ['a.png', 'b.png'],
    };
    await repo.saveItems(LiturgyWeekday.saturday, [LiturgyItem.fromJson(wire)]);
    final saved = repo.loadItems(LiturgyWeekday.saturday).single.toJson();
    for (final entry in wire.entries) {
      expect(saved[entry.key], entry.value, reason: entry.key);
    }
  });
}
