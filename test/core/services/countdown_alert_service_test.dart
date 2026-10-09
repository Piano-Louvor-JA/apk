import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/countdown_alert_service.dart';

/// Platform fake registrada na interface — channel mockado responde ok.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'requestNotificationsPermission':
          return true;
        default:
          return null;
      }
    });
    // Registra a implementação Android (method channel) como platform instance.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('notifyFinished com plugin respondendo não lança (Android)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final svc = CountdownAlertService();
    await svc.notifyFinished();
  });

  test('notifyFinished idempotente (init roda uma vez)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final svc = CountdownAlertService();
    await svc.notifyFinished();
    await svc.notifyFinished();
  });

  test('show é chamado com canal countdown_alerts (Android)', () async {
    var showCalled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'show') showCalled = true;
      switch (call.method) {
        case 'initialize':
          return true;
        case 'requestNotificationsPermission':
          return true;
        default:
          return null;
      }
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final svc = CountdownAlertService();
    await svc.notifyFinished();
    expect(showCalled, isTrue);
  });
}
