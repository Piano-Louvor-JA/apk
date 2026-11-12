import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  const hymn = LiturgyItem(
    id: 'm',
    type: LiturgyItemType.music,
    name: 'Hino',
    musicId: 42,
  );

  test(
    'nova sessão limpa conclusão de dias e avulsas sem perder conteúdo',
    () async {
      final repo = LiturgyRepository(prefs);
      await repo.saveItems(LiturgyWeekday.sunday, [hymn.copyWith(done: true)]);
      final custom = await repo.createCustom('Especial');
      await repo.writeItems('custom:${custom.id}', [hymn.copyWith(done: true)]);
      await repo.writeNotes('sunday', 'Equipe');
      await repo.writeLock('sunday', true);
      final clock = prefs.getString('sync.modified.v1.liturgy.pt');
      await repo.resetCompletion();
      expect(
        prefs.getString('sync.modified.v1.liturgy.pt'),
        clock,
        reason: 'reiniciar seleção da sessão não é uma edição do roteiro',
      );
      expect(repo.loadItems(LiturgyWeekday.sunday).single.done, isFalse);
      expect(repo.loadCustomLiturgies().single.items.single.done, isFalse);
      expect(repo.readNotes('sunday'), 'Equipe');
      expect(repo.readLock('sunday'), isTrue);
      expect(repo.loadItems(LiturgyWeekday.sunday).single.id, 'm');
    },
  );
  test('migra dias e avulsas legadas sem apagar a origem', () async {
    await prefs.setString('liturgy_items_sunday', jsonEncode([hymn.toJson()]));
    await prefs.setString(
      'liturgy_avulsa_20261112',
      jsonEncode([hymn.toJson()]),
    );
    final repo = LiturgyRepository(prefs);
    expect(repo.loadState()['weekdays']['sunday'][0]['name'], 'Hino');
    expect(repo.loadCustomLiturgies().single.name, '12/11/2026');
    await repo.saveItems(LiturgyWeekday.monday, [hymn]);
    final reloaded = LiturgyRepository(prefs);
    expect(reloaded.loadCustomLiturgies().single.items.single.musicId, 42);
    expect(prefs.getString('liturgy_avulsa_20261112'), isNotNull);
  });

  test(
    'avulsas nomeadas guardam notas, horários e cadeado após reabrir',
    () async {
      final repo = LiturgyRepository(prefs);
      final custom = await repo.createCustom('Culto especial');
      await repo.writeItems('custom:${custom.id}', [hymn]);
      await repo.writeNotes('custom:${custom.id}', 'Equipe');
      await repo.writeSessionTimes(
        'custom:${custom.id}',
        startTime: '8:30',
        endTime: '10:00',
      );
      await repo.writeLock('custom:${custom.id}', true);
      final other = LiturgyRepository(prefs);
      final restored = other.loadCustomLiturgies().single;
      expect(restored.name, 'Culto especial');
      expect(restored.items.single.musicId, 42);
      expect(restored.notes, 'Equipe');
      expect(
        other.readSessionTimes('custom:${custom.id}')['startTime'],
        '08:30',
      );
      expect(other.readLock('custom:${custom.id}'), isTrue);
      await other.deleteCustom(custom.id);
      expect(other.loadCustomLiturgies(), isEmpty);
      expect(other.loadState()['deletionLocks'], isEmpty);
    },
  );

  test('liturgias de idiomas distintos não se sobrescrevem', () async {
    final pt = LiturgyRepository(prefs, locale: 'pt-BR');
    final es = LiturgyRepository(prefs, locale: 'es');
    await pt.saveItems(LiturgyWeekday.sunday, [hymn]);
    expect(es.loadItems(LiturgyWeekday.sunday), isEmpty);
    await es.saveItems(LiturgyWeekday.sunday, [hymn.copyWith(name: 'Himno')]);
    expect(pt.loadItems(LiturgyWeekday.sunday).single.name, 'Hino');
    expect(es.loadItems(LiturgyWeekday.sunday).single.name, 'Himno');
  });

  test(
    'a primeira gravação em ES não faz os dados espanhóis migrarem para PT',
    () async {
      await prefs.setString('locale', 'es');
      final es = LiturgyRepository(prefs, locale: 'es');
      await es.saveItems(LiturgyWeekday.sunday, [
        hymn.copyWith(name: 'Español'),
      ]);
      expect(
        LiturgyRepository(prefs, locale: 'pt').loadItems(LiturgyWeekday.sunday),
        isEmpty,
      );
      expect(es.loadItems(LiturgyWeekday.sunday).single.name, 'Español');
    },
  );
  test(
    'salvar culto enfileira o estado completo com a chave do desktop',
    () async {
      final repo = LiturgyRepository(prefs, locale: 'es');
      await repo.saveItems(LiturgyWeekday.saturday, [hymn]);
      final outbox =
          jsonDecode(prefs.getString('louvorja.sync.outbox.v1')!) as Map;
      final entry = outbox['liturgy::es'] as Map;
      final state = jsonDecode(entry['value_json'] as String) as Map;
      expect(
        state.keys,
        containsAll([
          'weekdays',
          'dayNotes',
          'daySessionTimes',
          'customLiturgies',
          'deletionLocks',
        ]),
      );
      expect(state['weekdays']['saturday'][0]['musicId'], 42);
    },
  );
}
