import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/settings_controller.dart';
import 'package:louvorja_piano_mobile/core/services/sync/operator_state_client.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_timestamps.dart';

/// B6b: setters de preferências enfileiram prefs::values (apk#107).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncTimestamps.init();
  });

  test('setThemeMode enfileira a pref no lote prefs::values', () async {
    final prefs = await SharedPreferences.getInstance();
    final client = OperatorStateClient(prefs, sessionToken: () async => null);
    final settings = SettingsController(
      outboxHook: (key, value) => client.enqueuePrefs({key: value}),
    );

    await settings.setThemeMode(ThemeMode.light);

    expect(client.outboxCount(), 1);
    final box = (await SharedPreferences.getInstance())
        .getString(OperatorStateClient.outboxStorageKey)!;
    final payload = jsonDecode(
      ((jsonDecode(box) as Map)['prefs::values'] as Map)['value_json'] as String,
    ) as Map<String, dynamic>;
    expect(payload['themeMode'], 'light');
  });

  test('setGlassIntensity enfileira int; sem hook não quebra', () async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsController();
    await settings.setGlassIntensity(70); // sem hook: no-op de sync
    expect(prefs.getInt('glassIntensity'), 70);
    expect(prefs.getString(OperatorStateClient.outboxStorageKey), isNull);
  });
}
