library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/apk_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.louvorja/updater');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void mock(Future<Object?> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  test('delivered quando o nativo confirma a sessão', () async {
    mock((call) async => 'delivered');
    expect(await ApkInstaller.install('/x.apk'), ApkInstallOutcome.delivered);
  });

  test('needsPermission quando falta fonte desconhecida', () async {
    mock((call) async => 'needs_permission');
    expect(
      await ApkInstaller.install('/x.apk'),
      ApkInstallOutcome.needsPermission,
    );
  });

  test('failed em PlatformException', () async {
    mock((call) async => throw PlatformException(code: 'E'));
    expect(await ApkInstaller.install('/x.apk'), ApkInstallOutcome.failed);
  });

  test('failed em MissingPluginException (fallback legado)', () async {
    mock((call) async => throw MissingPluginException());
    expect(await ApkInstaller.install('/x.apk'), ApkInstallOutcome.failed);
  });
}
