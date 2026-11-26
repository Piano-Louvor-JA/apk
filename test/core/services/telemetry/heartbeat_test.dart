library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/home_location_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/telemetry/heartbeat.dart';
import 'package:louvorja_piano_mobile/domain/repositories/telemetry_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Telemetria de dispositivos (Fase 5): sinal de "online" do APK.
/// Paridade com app/src/modules/telemetry (desktop).
class _FakeApi implements TelemetryApiClient {
  final List<Map<String, Object?>> sent = [];
  bool fail = false;

  @override
  Future<bool> sendHeartbeat(Map<String, Object?> body) async {
    if (fail) throw StateError('rede');
    sent.add(body);
    return true;
  }
}

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

HeartbeatBodyBuilder _builder() => HeartbeatBodyBuilder(
  platform: () => 'apk-android',
  version: () async => '0.1.90',
  os: () async =>
      const DeviceOs(name: 'Android', release: '14 · samsung SM-A546E'),
  locale: () => 'pt-BR',
  timezone: () => '-03',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('install id', () {
    test(
      'UUID v4 criado uma vez e reaproveitado (sobrevive a reabrir)',
      () async {
        final first = await TelemetryInstallId.getOrCreate();
        expect(first, matches(_uuidV4));
        expect(await TelemetryInstallId.getOrCreate(), first);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('telemetry.installId'), first);
      },
    );

    test('id gravado invalido e trocado', () async {
      SharedPreferences.setMockInitialValues({'telemetry.installId': 'lixo'});
      expect(await TelemetryInstallId.getOrCreate(), matches(_uuidV4));
    });
  });

  group('corpo do sinal', () {
    test(
      'mesmo contrato do desktop; campo apagado usa o ultimo valor',
      () async {
        await HomeLocationPreferences.save(
          const HomeLocation(district: 'Bertioga', church: 'Rio da Praia'),
        );
        await HomeLocationPreferences.save(
          const HomeLocation(church: 'Rio da Praia'),
        );
        final body = await _builder().build();
        expect(body['install_id'], matches(_uuidV4));
        expect(body['platform'], 'apk-android');
        expect(body['app_version'], '0.1.90');
        expect(body['os'], {
          'name': 'Android',
          'release': '14 · samsung SM-A546E',
          'arch': '',
        });
        expect(body['locale'], 'pt-BR');
        expect(body['timezone'], '-03');
        expect(body['district'], 'Bertioga');
        expect(body['church'], 'Rio da Praia');
      },
    );

    test('sem SO, versao vazia e sem distrito/igreja viram null', () async {
      final body = await HeartbeatBodyBuilder(
        platform: () => 'apk-ios',
        version: () async => '',
        os: () async => null,
        locale: () => 'pt-BR',
        timezone: () => '-03',
      ).build();
      expect(body['os'], isNull);
      expect(body['app_version'], isNull);
      expect(body['district'], isNull);
      expect(body['church'], isNull);
    });

    test('falha ao ler o SO nao derruba o corpo', () async {
      final body = await HeartbeatBodyBuilder(
        platform: () => 'apk-android',
        version: () async => '1.0.0',
        os: () async => throw StateError('device_info'),
        locale: () => 'pt-BR',
        timezone: () => '-03',
      ).build();
      expect(body['os'], isNull);
    });
  });

  group('URLs do heartbeat', () {
    test('so hosts da API Piano, na ordem, sem repetir', () {
      expect(
        heartbeatUrlsFrom([
          'https://api-stg.pianolouvorja.com.br/json_db',
          'https://api-stg.pianolouvorja.com.br/file',
          'https://api.louvorja.com.br/json_db',
          'https://api.pianolouvorja.com.br/json_db',
          'http://localhost:3100/json_db',
          'nao e url',
        ]),
        [
          'https://api-stg.pianolouvorja.com.br/v1/telemetry/heartbeat',
          'https://api.pianolouvorja.com.br/v1/telemetry/heartbeat',
          'http://localhost:3100/v1/telemetry/heartbeat',
        ],
      );
    });
  });

  group('loop (so com o app em primeiro plano)', () {
    testWidgets('envia ao iniciar e a cada 5 min', (tester) async {
      final api = _FakeApi();
      final loop = HeartbeatLoop(api: api, builder: _builder());
      loop.start();
      await tester.pump();
      expect(api.sent, hasLength(1));
      await tester.pump(HeartbeatLoop.interval);
      expect(api.sent, hasLength(2));
      loop.stop();
    });

    testWidgets('em segundo plano para; ao voltar envia na hora', (
      tester,
    ) async {
      final api = _FakeApi();
      final loop = HeartbeatLoop(api: api, builder: _builder());
      loop.start();
      await tester.pump();
      loop.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(HeartbeatLoop.interval * 3);
      expect(api.sent, hasLength(1));
      loop.didChangeAppLifecycleState(AppLifecycleState.paused);
      loop.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(api.sent, hasLength(2));
      // inactive (cortina de notificacoes) nao interrompe
      loop.didChangeAppLifecycleState(AppLifecycleState.inactive);
      loop.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(api.sent, hasLength(2));
      await tester.pump(HeartbeatLoop.interval);
      expect(api.sent, hasLength(3));
      loop.stop();
    });

    testWidgets('salvar distrito/igreja envia apos o debounce', (tester) async {
      final api = _FakeApi();
      final loop = HeartbeatLoop(api: api, builder: _builder());
      loop.start();
      await tester.pump();
      api.sent.clear();
      HomeLocationPreferences.savedChanges.value++;
      HomeLocationPreferences.savedChanges.value++;
      await tester.pump(
        HeartbeatLoop.locationDebounce - const Duration(milliseconds: 1),
      );
      expect(api.sent, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(api.sent, hasLength(1));
      loop.stop();
    });

    testWidgets('pausar cancela envio pendente de localizacao', (tester) async {
      final api = _FakeApi();
      final loop = HeartbeatLoop(api: api, builder: _builder());
      loop.start();
      await tester.pump();
      HomeLocationPreferences.savedChanges.value++;
      loop.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(HeartbeatLoop.locationDebounce * 2);
      expect(api.sent, hasLength(1));
      // Alteracoes recebidas enquanto pausado tambem nao enviam.
      HomeLocationPreferences.savedChanges.value++;
      await tester.pump(HeartbeatLoop.locationDebounce * 2);
      expect(api.sent, hasLength(1));
      loop.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(api.sent, hasLength(2));
      loop.stop();
    });

    testWidgets('pausar durante montagem do corpo impede envio', (tester) async {
      final ready = Completer<String>();
      final api = _FakeApi();
      final loop = HeartbeatLoop(
        api: api,
        builder: HeartbeatBodyBuilder(version: () => ready.future),
      );
      loop.start();
      await tester.pump();
      loop.didChangeAppLifecycleState(AppLifecycleState.paused);
      ready.complete('1.0.0');
      await tester.pump();
      expect(api.sent, isEmpty);
      loop.stop();
    });

    testWidgets('iniciar duas vezes nao duplica; falha nao quebra; stop para', (
      tester,
    ) async {
      final api = _FakeApi()..fail = true;
      final loop = HeartbeatLoop(api: api, builder: _builder());
      loop.start();
      loop.start();
      await tester.pump();
      expect(loop.isRunning, isTrue);
      api.fail = false;
      await tester.pump(HeartbeatLoop.interval);
      expect(api.sent, hasLength(1));
      loop.stop();
      expect(loop.isRunning, isFalse);
      await tester.pump(HeartbeatLoop.interval * 2);
      HomeLocationPreferences.savedChanges.value++;
      await tester.pump(HeartbeatLoop.locationDebounce * 2);
      expect(api.sent, hasLength(1));
    });
  });
}
