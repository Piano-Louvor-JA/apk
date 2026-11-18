import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/sync/operator_state_client.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  Map<String, dynamic> remote(String lang, String name, int at) => {
    'namespace': 'liturgy',
    'key': lang,
    'updated_at_ms': at,
    'deleted_at': null,
    'value_json': jsonEncode({
      ...LiturgyRepository.emptyState(),
      'weekdays': {
        'sunday': [
          LiturgyItem(
            id: name,
            type: LiturgyItemType.annotation,
            name: name,
          ).toJson(),
        ],
      },
    }),
  };
  test(
    'pull do desktop aplica o estado completo por idioma sem gerar outbox',
    () async {
      await applyOperatorState(prefs, [
        remote('pt', 'Português', 200),
        remote('es', 'Español', 100),
      ]);
      expect(
        LiturgyRepository(
          prefs,
          locale: 'pt',
        ).loadItems(LiturgyWeekday.sunday).single.name,
        'Português',
      );
      expect(
        LiturgyRepository(
          prefs,
          locale: 'es',
        ).loadItems(LiturgyWeekday.sunday).single.name,
        'Español',
      );
      expect(OperatorStateClient(prefs).outboxCount(), 0);
      await applyOperatorState(prefs, [
        remote('pt', 'Antigo', 199),
        remote('es', 'Empate', 100),
      ]);
      expect(
        LiturgyRepository(
          prefs,
          locale: 'pt',
        ).loadItems(LiturgyWeekday.sunday).single.name,
        'Português',
      );
      expect(
        LiturgyRepository(
          prefs,
          locale: 'es',
        ).loadItems(LiturgyWeekday.sunday).single.name,
        'Español',
      );
    },
  );
  test('edição local pendente vence uma resposta antiga', () async {
    final repo = LiturgyRepository(prefs);
    await repo.saveItems(LiturgyWeekday.sunday, [
      const LiturgyItem(
        id: 'local',
        type: LiturgyItemType.music,
        name: 'Local',
      ),
    ]);
    await applyOperatorState(prefs, [remote('pt', 'Antigo', 1)]);
    expect(repo.loadItems(LiturgyWeekday.sunday).single.name, 'Local');
    expect(OperatorStateClient(prefs).outboxCount(), 1);
  });
}
