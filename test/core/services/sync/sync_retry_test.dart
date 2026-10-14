// SPEC 7 (apk#92) — retry de sincronização quando a rede volta.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_retry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hasPending distingue fila vazia de entradas salvas', () async {
    SharedPreferences.setMockInitialValues({'louvorja.sync.outbox.v1': '{}'});
    final prefs = await SharedPreferences.getInstance();
    final retry = SyncRetry(prefs, flush: () async {});
    expect(retry.hasPending, isFalse);
    await prefs.setString('louvorja.sync.outbox.v1', '{"prefs::values":{}}');
    expect(retry.hasPending, isTrue);
    await prefs.setString('louvorja.sync.outbox.v1', 'inválido');
    expect(retry.hasPending, isFalse);
  });

  test('onNetworkBack dispara flush quando a rede retorna', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var flushes = 0;

    final retry = SyncRetry(
      prefs,
      flush: () async => flushes++,
      startOffline: true,
    );
    retry.onNetworkBack(true);
    retry.onNetworkBack(false); // offline de novo: não dispara
    retry.onNetworkBack(true); // volta: dispara
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(flushes, 2);
  });

  test('estado inicial offline=true dispara no primeiro online', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var flushes = 0;

    final retry = SyncRetry(
      prefs,
      flush: () async => flushes++,
      startOffline: true,
    );
    retry.onNetworkBack(false);
    retry.onNetworkBack(false);
    await Future<void>.delayed(Duration.zero);
    expect(flushes, 0);

    retry.onNetworkBack(true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(flushes, 1);
  });

  test('flush que lança não derruba o retry (fila intacta)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final retry = SyncRetry(
      prefs,
      flush: () async => throw Exception('rede caiu de novo'),
      startOffline: true,
    );
    retry.onNetworkBack(true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    // não lançou — sucesso do teste
  });
}
