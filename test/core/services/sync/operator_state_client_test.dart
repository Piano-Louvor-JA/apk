import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/sync/operator_state_client.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_timestamps.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

/// Fetch fake: grava os corpos e devolve respostas programáveis.
class FakeFetch {
  final bodies = <Map<String, dynamic>>[];
  Object? nextResponse; // Map = ok; String = exception (rede)
  int status = 200;

  Future<Map<String, dynamic>?> call(
    String method,
    String url, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    if (nextResponse is String) throw Exception(nextResponse);
    bodies.add(Map<String, dynamic>.from(body!));
    expect(method, 'POST');
    expect(url, contains('/v1/custom/sync'));
    return nextResponse as Map<String, dynamic>?;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncTimestamps.init();
    OperatorStateClient.resetForTest();
  });

  ScheduledItem item(String id) => ScheduledItem(
    id: id,
    categoryId: 'c1',
    date: DateTime(2026, 10, 5),
    name: 'Culto',
  );

  group('enqueue (outbox local, nunca toca rede)', () {
    test('B1: enfileira e persiste; coalescing por namespace::key', () async {
      final prefs = await SharedPreferences.getInstance();
      final client = OperatorStateClient(prefs);
      await client.enqueueScheduled(
        ScheduledStatePayload(
          categories: [ScheduledCategory(id: 'c1', name: 'Cultos')],
          items: [item('a')],
        ),
      );
      await client.enqueueScheduled(
        ScheduledStatePayload(categories: const [], items: [item('b')]),
      );

      expect(client.outboxCount(), 1);
      // persistido
      final raw = prefs.getString(OperatorStateClient.outboxStorageKey);
      expect(raw, isNotNull);
      final box = jsonDecode(raw!) as Map<String, dynamic>;
      expect(box.keys.single, 'scheduled::items');
      final entry = box['scheduled::items'] as Map<String, dynamic>;
      expect(entry['client_uuid'], isNotEmpty);
      expect(entry['namespace'], 'scheduled');
      expect(entry['key'], 'items');
      final payload = jsonDecode(entry['value_json'] as String)
          as Map<String, dynamic>;
      expect((payload['items'] as List).length, 1);
    });

    test('B1b: prefs enfileiram como lote prefs::values', () async {
      final prefs = await SharedPreferences.getInstance();
      final client = OperatorStateClient(prefs);
      await client.enqueuePrefs({'themeMode': 'light'});
      await client.enqueuePrefs({'accent': 'azure'});
      expect(client.outboxCount(), 1);
      final box = jsonDecode(
        prefs.getString(OperatorStateClient.outboxStorageKey)!,
      ) as Map<String, dynamic>;
      final entry = box['prefs::values'] as Map<String, dynamic>;
      final payload =
          jsonDecode(entry['value_json'] as String) as Map<String, dynamic>;
      expect(payload, {'themeMode': 'light', 'accent': 'azure'});
    });
  });

  group('flush', () {
    test('B2: sem sessão real não envia e mantém a fila', () async {
      final prefs = await SharedPreferences.getInstance();
      final fetch = FakeFetch();
      final client = OperatorStateClient(
        prefs,
        fetch: fetch.call, apiBaseUrl: "https://api.test",
        sessionToken: () async => null,
      );
      await client.enqueuePrefs({'themeMode': 'light'});
      final sent = await client.flush();
      expect(sent, isNull);
      expect(fetch.bodies, isEmpty);
      expect(client.outboxCount(), 1);
    });

    test('B2b: flush envia batch e limpa só o que foi enviado', () async {
      final prefs = await SharedPreferences.getInstance();
      final fetch = FakeFetch()..nextResponse = <String, dynamic>{};
      final client = OperatorStateClient(
        prefs,
        fetch: fetch.call, apiBaseUrl: "https://api.test",
        sessionToken: () async => 'tok123456',
      );
      await client.enqueueScheduled(
        ScheduledStatePayload(categories: const [], items: [item('a')]),
      );
      final sent = await client.flush();
      expect(sent, isNotNull);
      expect(client.outboxCount(), 0);
      expect(fetch.bodies.single['collections'], isEmpty);
      final ops = fetch.bodies.single['operator_state'] as List<dynamic>;
      expect((ops.single as Map)['namespace'], 'scheduled');
      expect(fetch.bodies.single, contains('operator_state'));
    });

    test('B5: rede falha → fila intacta; retry coalescido sai num batch', () async {
      final prefs = await SharedPreferences.getInstance();
      final fetch = FakeFetch()..nextResponse = 'boom';
      final client = OperatorStateClient(
        prefs,
        fetch: fetch.call, apiBaseUrl: "https://api.test",
        sessionToken: () async => 'tok123456',
      );
      await client.enqueueScheduled(
        ScheduledStatePayload(categories: const [], items: [item('a')]),
      );
      final failed = await client.flush();
      expect(failed, isNull);
      expect(client.outboxCount(), 1);

      // mutation nova coalesce no MESMO item
      await client.enqueueScheduled(
        ScheduledStatePayload(categories: const [], items: [item('a2')]),
      );
      expect(client.outboxCount(), 1);

      fetch.nextResponse = <String, dynamic>{};
      final sent = await client.flush();
      expect(sent, isNotNull);
      final ops = fetch.bodies.single['operator_state'] as List<dynamic>;
      expect(ops.length, 1);
      expect(client.outboxCount(), 0);
    });

    test('B2c: flush registra push (meta LWW) do namespace enviado', () async {
      final prefs = await SharedPreferences.getInstance();
      final fetch = FakeFetch()..nextResponse = <String, dynamic>{};
      final client = OperatorStateClient(
        prefs,
        fetch: fetch.call, apiBaseUrl: "https://api.test",
        sessionToken: () async => 'tok123456',
      );
      await client.enqueuePrefs({'themeMode': 'light'});
      await client.flush();
      expect(
        prefs.getInt('louvorja.sync.operator.updatedAt.prefs'),
        greaterThan(0),
      );
    });
  });

  group('applyOperatorState (pull LWW)', () {
    OperatorStateClient makeClient(SharedPreferences prefs, FakeFetch f) =>
        OperatorStateClient(
          prefs,
          fetch: f.call,
          apiBaseUrl: 'https://api.test',
          sessionToken: () async => 'tok123456',
        );

    Map<String, dynamic> respItem({
      required String namespace,
      required String key,
      required Map<String, dynamic> value,
      required int updatedAtMs,
    }) => {
      'client_uuid': 'srv-${namespace}-${key}',
      'namespace': namespace,
      'key': key,
      'value_json': jsonEncode(value),
      'updated_at_ms': updatedAtMs,
      'deleted_at': null,
    };

    test('B3: servidor mais novo aplica agendados no repositório', () async {
      final prefs = await SharedPreferences.getInstance();
      final fetch = FakeFetch()
        ..nextResponse = {
          'operator_state': [
            respItem(
              namespace: 'scheduled',
              key: 'items',
              value: {
                'categories': [
                  {'id': 'c1', 'name': 'Cultos'},
                ],
                'items': [item('srv1').toJson()],
              },
              updatedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch + 2000,
            ),
          ],
        };
      final client = makeClient(prefs, fetch);
      // local antigo: registra meta 1000
      await prefs.setInt(
        'louvorja.sync.operator.updatedAt.scheduled',
        1000,
      );
      // outbox com mutação local: dispara o batch (o pull vem na resposta)
      await client.enqueueScheduled(
        ScheduledStatePayload(categories: const [], items: [item('local')]),
      );

      final applied = await client.flush();
      expect(applied, isNotNull);
      final repo = ScheduledRepository(prefs);
      expect(repo.loadItems().map((e) => e.id), ['srv1']);
      expect(repo.loadCategories().single.id, 'c1');
      // meta atualizada pro instante do servidor
      expect(prefs.getInt('louvorja.sync.operator.updatedAt.scheduled'), greaterThan(DateTime.now().toUtc().millisecondsSinceEpoch));
    });

    test('B3b: servidor mais VELHO — local vence, nada muda', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ScheduledRepository(prefs);
      await repo.saveItems([item('local')]);
      final fetch = FakeFetch()
        ..nextResponse = {
          'operator_state': [
            respItem(
              namespace: 'scheduled',
              key: 'items',
              value: {'categories': [], 'items': []},
              updatedAtMs: 1,
            ),
          ],
        };
      final client = makeClient(prefs, fetch);
      await prefs.setInt(
        'louvorja.sync.operator.updatedAt.scheduled',
        9999,
      );
      await client.enqueueScheduled(
        ScheduledStatePayload(categories: const [], items: [item('local')]),
      );
      await client.flush();
      expect(repo.loadItems().single.id, 'local');
    });

    test('B3c: tombstone e payload inválido são ignorados', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ScheduledRepository(prefs);
      await repo.saveItems([item('local')]);
      final fetch = FakeFetch()
        ..nextResponse = {
          'operator_state': [
            {
              ...respItem(
                namespace: 'scheduled',
                key: 'items',
                value: {'categories': [], 'items': []},
                updatedAtMs: 9000,
              ),
              'deleted_at': 123,
            },
            respItem(
              namespace: 'scheduled',
              key: 'items',
              value: {'foo': 'bar'}, // sem categories/items → inválido
              updatedAtMs: 9001,
            ),
            respItem(
              namespace: 'desconhecida', // namespace futura → ignorada
              key: 'x',
              value: {'a': 1},
              updatedAtMs: 9002,
            ),
          ],
        };
      final client = makeClient(prefs, fetch);
      await client.enqueuePrefs({'themeMode': 'light'});
      await client.flush();
      expect(repo.loadItems().single.id, 'local');
      expect(repo.loadCategories(), isEmpty);
    });

    test('B4: prefs aplicadas SOMENTE da whitelist', () async {
      final prefs = await SharedPreferences.getInstance();
      final fetch = FakeFetch()
        ..nextResponse = {
          'operator_state': [
            respItem(
              namespace: 'prefs',
              key: 'values',
              value: {
                'themeMode': 'dark',
                'accent': 'azure',
                'louvorja.custom.session': '{"token":"roubado"}', // fora
                'glassIntensity': 80,
              },
              updatedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch + 5000,
            ),
          ],
        };
      final client = makeClient(prefs, fetch);
      await client.enqueuePrefs({'themeMode': 'light'});
      await client.flush();
      expect(prefs.getString('themeMode'), 'dark');
      expect(prefs.getString('accent'), 'azure');
      expect(prefs.getInt('glassIntensity'), 80);
      // fora da whitelist nunca chega ao storage
      expect(prefs.getString('louvorja.custom.session'), isNull);
      expect(
        prefs.getInt('louvorja.sync.operator.updatedAt.prefs'),
        greaterThan(DateTime.now().toUtc().millisecondsSinceEpoch),
      );
    });

    test('B4b: pull NUNCA grava no outbox (sem loop)', () async {
      final prefs = await SharedPreferences.getInstance();
      final fetch = FakeFetch()
        ..nextResponse = {
          'operator_state': [
            respItem(
              namespace: 'prefs',
              key: 'values',
              value: {'themeMode': 'dark'},
              updatedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch + 5000,
            ),
          ],
        };
      final client = makeClient(prefs, fetch);
      await client.enqueuePrefs({'themeMode': 'light'});
      await client.flush();
      expect(client.outboxCount(), 0);
    });
  });

  test('uuid de outbox é único por entrada nova', () async {
    final prefs = await SharedPreferences.getInstance();
    final c1 = OperatorStateClient(prefs, sessionToken: () async => null);
    await c1.enqueuePrefs({'a': 1});
    final box1 = jsonDecode(
      prefs.getString(OperatorStateClient.outboxStorageKey)!,
    ) as Map<String, dynamic>;
    final uuid1 = (box1['prefs::values'] as Map)['client_uuid'] as String;
    await c1.enqueuePrefs({'a': 2});
    final box2 = jsonDecode(
      prefs.getString(OperatorStateClient.outboxStorageKey)!,
    ) as Map<String, dynamic>;
    final uuid2 = (box2['prefs::values'] as Map)['client_uuid'] as String;
    expect(uuid1, uuid2); // coalescing preserva a identidade do item
  });
}
