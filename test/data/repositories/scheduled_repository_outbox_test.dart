import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/sync/operator_state_client.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_timestamps.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

/// B6: hooks de outbox nos caminhos de escrita — toda mutação sincronizável
/// grava na fila antes de qualquer rede (RF-01), sem bloquear o fluxo local.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncTimestamps.init();
  });

  test('saveItems enfileira scheduled::items (helper OperatorOutboxHook)',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ScheduledRepository(prefs);
    final client = OperatorStateClient(prefs, sessionToken: () async => null);

    await repo.saveItems(
      [
        ScheduledItem(
          id: 'a',
          categoryId: 'c1',
          date: DateTime(2026, 10, 5),
          name: 'Culto',
        ),
      ],
      outbox: (categories, items) => client.enqueueScheduled(
        ScheduledStatePayload(categories: categories, items: items),
      ),
    );

    expect(client.outboxCount(), 1);
    final box = jsonDecode(
      prefs.getString(OperatorStateClient.outboxStorageKey)!,
    ) as Map<String, dynamic>;
    expect(box.keys.single, 'scheduled::items');
  });

  test('sem hook injetado: save segue funcionando (outbox é opcional)',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ScheduledRepository(prefs);
    await repo.saveItems(const []);
    expect(
      prefs.getString(OperatorStateClient.outboxStorageKey),
      isNull,
    );
  });

  test('saveCategories enfileira o estado completo (categories+items)',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ScheduledRepository(prefs);
    final client = OperatorStateClient(prefs, sessionToken: () async => null);

    await repo.saveCategories(
      [ScheduledCategory(id: 'c1', name: 'Cultos')],
      outbox: (categories, items) => client.enqueueScheduled(
        ScheduledStatePayload(categories: categories, items: items),
      ),
    );

    final box = jsonDecode(
      prefs.getString(OperatorStateClient.outboxStorageKey)!,
    ) as Map<String, dynamic>;
    final payload =
        jsonDecode((box['scheduled::items'] as Map)['value_json'] as String)
            as Map<String, dynamic>;
    expect((payload['categories'] as List).single['id'], 'c1');
  });
}
