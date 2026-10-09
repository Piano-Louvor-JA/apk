import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/connectivity_service.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityService — canal connectivity_plus mockado', () {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('isConnected true com wifi', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => ['wifi']);
      final svc = ConnectivityService();
      expect(await svc.isConnected, isTrue);
      expect(await svc.isWifi, isTrue);
    });

    test('isConnected false com none', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => ['none']);
      final svc = ConnectivityService();
      expect(await svc.isConnected, isFalse);
      expect(await svc.isWifi, isFalse);
    });

    test('isConnected true com mobile (não wifi)', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => ['mobile']);
      final svc = ConnectivityService();
      expect(await svc.isConnected, isTrue);
      expect(await svc.isWifi, isFalse);
    });

    test('onConnectionChanged emite distinto', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => ['wifi']);
      final svc = ConnectivityService();
      final events = <bool>[];
      final sub = svc.onConnectionChanged.listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(events, everyElement(isTrue));
    });
  });

  group('ConnectivityController — estado observável', () {
    test('start adiciona estado inicial; dispose fecha stream', () async {
      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => ['none']);

      final controller = ConnectivityController();
      final states = <bool>[];
      final sub = controller.state.listen(states.add);
      await controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(states, contains(false));
      await sub.cancel();
      await controller.dispose();
    });
  });

  group('SyncFileService — lógica pura', () {
    test('fileNameFor formata louvorja-AAAA-MM-DD.louvorja', () {
      expect(
        SyncFileService.fileNameFor(DateTime(2026, 10, 8)),
        'louvorja-2026-10-08.louvorja',
      );
    });

    test('isValidContent rejeita lixo e aceita pacote real', () {
      expect(SyncFileService.isValidContent('lixo{{{'), isFalse);
      expect(SyncFileService.isValidContent('{}'), isFalse);
    });
  });
}
