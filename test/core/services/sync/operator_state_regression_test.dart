import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/sync/operator_state_client.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_timestamps.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await SyncTimestamps.init(prefs);
  });

  Map<String, dynamic> remotePrefs(int at, String theme) => {
    'namespace': 'prefs',
    'key': 'values',
    'updated_at_ms': at,
    'value_json': jsonEncode({'themeMode': theme}),
  };

  test('dispositivo sem outbox também recebe o estado da conta', () async {
    Map<String, dynamic>? captured;
    final client = OperatorStateClient(
      prefs,
      apiBaseUrl: 'https://api.test',
      sessionToken: () async => 'sessao',
      fetch: (method, url, {body, bearerToken}) async {
        captured = body;
        return {
          'operator_state': [remotePrefs(1000, 'dark')],
        };
      },
    );
    await client.flush();
    expect(captured?['operator_state'], isEmpty);
    expect(prefs.getString('themeMode'), 'dark');
    expect(client.outboxCount(), 0);
  });

  test('resposta não apaga alteração feita durante o envio', () async {
    final started = Completer<void>();
    final response = Completer<Map<String, dynamic>?>();
    final client = OperatorStateClient(
      prefs,
      apiBaseUrl: 'https://api.test',
      sessionToken: () async => 'sessao',
      fetch: (method, url, {body, bearerToken}) {
        started.complete();
        return response.future;
      },
    );
    await client.enqueuePrefs({'themeMode': 'light'});
    final sending = client.flush();
    await started.future;
    await client.enqueuePrefs({'themeMode': 'dark'});
    response.complete({'operator_state': <Object>[]});
    await sending;
    expect(client.outboxCount(), 1);
    final box = jsonDecode(
      prefs.getString(OperatorStateClient.outboxStorageKey)!,
    );
    expect(jsonDecode(box['prefs::values']['value_json']), {
      'themeMode': 'dark',
    });
  });

  test('LWW compara o instante da escrita, não o fim da requisição', () async {
    final client = OperatorStateClient(
      prefs,
      apiBaseUrl: 'https://api.test',
      sessionToken: () async => 'sessao',
      fetch: (method, url, {body, bearerToken}) async => {
        'operator_state': [remotePrefs(2000, 'dark')],
      },
    );
    await client.enqueuePrefs({'themeMode': 'light'});
    final box = jsonDecode(
      prefs.getString(OperatorStateClient.outboxStorageKey)!,
    );
    box['prefs::values']['updated_at'] = 1000;
    await prefs.setString(
      OperatorStateClient.outboxStorageKey,
      jsonEncode(box),
    );
    await client.flush();
    expect(prefs.getString('themeMode'), 'dark');
    expect(prefs.getInt('louvorja.sync.operator.updatedAt.prefs'), 2000);
  });

  test(
    'payload de agendados inválido não altera parcialmente o local',
    () async {
      final repo = ScheduledRepository(prefs);
      await repo.saveCategories([
        const ScheduledCategory(id: 'local', name: 'Local'),
      ]);
      await applyOperatorState(prefs, [
        {
          'namespace': 'scheduled',
          'key': 'items',
          'updated_at_ms': 1000,
          'value_json': jsonEncode({
            'categories': [
              {'id': 'remoto', 'name': 'Remoto'},
            ],
            'items': [
              {'id': 'invalido'},
            ],
          }),
        },
      ]);
      expect(repo.loadCategories().single.id, 'local');
      expect(
        prefs.getInt('louvorja.sync.operator.updatedAt.scheduled'),
        isNull,
      );
    },
  );

  test('enqueue ignora tokens e preferências fora da whitelist', () async {
    final client = OperatorStateClient(prefs);
    await client.enqueuePrefs({'token': 'nao-persistir'});
    expect(client.outboxCount(), 0);
    await client.enqueuePrefs({'themeMode': 'dark', 'token': 'nao-persistir'});
    expect(
      prefs.getString(OperatorStateClient.outboxStorageKey),
      isNot(contains('nao-persistir')),
    );
  });

  test('sessão vazia não envia nem apaga a fila', () async {
    var calls = 0;
    final client = OperatorStateClient(
      prefs,
      apiBaseUrl: 'https://api.test',
      sessionToken: () async => '',
      fetch: (method, url, {body, bearerToken}) async {
        calls++;
        return <String, dynamic>{};
      },
    );
    await client.enqueuePrefs({'themeMode': 'dark'});
    await client.flush();
    expect(calls, 0);
    expect(client.outboxCount(), 1);
  });

  test(
    'push converte aparência para as chaves compartilhadas do app/web',
    () async {
      Map<String, dynamic>? captured;
      final client = OperatorStateClient(
        prefs,
        apiBaseUrl: 'https://api.test',
        sessionToken: () async => 'sessao',
        fetch: (method, url, {body, bearerToken}) async {
          captured = body;
          return <String, dynamic>{};
        },
      );
      await client.enqueuePrefs({
        'glassIntensity': 80,
        'interaction': 'dynamic_',
        'themeMode': 'system',
      });
      await client.flush();
      final ops = captured!['operator_state'] as List;
      final payload = jsonDecode(ops.single['value_json']);
      expect(payload, {
        'blur': 80,
        'interaction': 'dynamic',
        'themeMode': 'system',
      });
    },
  );

  test('pull converte aparência compartilhada para as chaves do APK', () async {
    await prefs.setString('themeMode', 'system');
    await applyOperatorState(prefs, [
      {
        'namespace': 'prefs',
        'key': 'values',
        'updated_at_ms': 1000,
        'value_json': jsonEncode({
          'blur': 85,
          'interaction': 'dynamic',
          'theme': 'luminousClarity',
        }),
      },
    ]);
    expect(prefs.getInt('glassIntensity'), 85);
    expect(prefs.getString('interaction'), 'dynamic_');
    expect(prefs.getString('themeMode'), 'system');
    expect(prefs.getString('theme'), isNull);
  });

  test('payload usa a data de calendário esperada pelo app/web', () {
    final state = ScheduledStatePayload(
      categories: const [],
      items: [
        ScheduledItem(
          id: 'a',
          categoryId: 'c',
          date: DateTime(2026, 10, 5),
          name: 'Culto',
        ),
      ],
    );
    expect((state.toJson()['items'] as List).single['date'], '2026-10-05');
  });

  test('conteúdo de agendado do app/web sobrevive ao pull e nova edição', () {
    final source = <String, dynamic>{
      'id': 'a',
      'categoryId': 'c',
      'date': '2026-10-05',
      'name': 'Versículo',
      'content': {
        'kind': 'verse',
        'verseBookId': 43,
        'verseChapter': 3,
        'verseNumbers': '16',
      },
    };
    final item = ScheduledItem.fromJson(source).copyWith(notes: 'Anotação');
    final state = ScheduledStatePayload(categories: const [], items: [item]);
    expect(
      (state.toJson()['items'] as List).single['content'],
      source['content'],
    );
  });
}
