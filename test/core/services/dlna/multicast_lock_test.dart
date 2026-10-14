import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/multicast_lock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MulticastLock', () {
    test('acquire em sandbox (MissingPluginException) não lança', () async {
      await MulticastLock.acquire();
      await MulticastLock.release();
    });

    test('acquire com PlatformException no nativo é engolido', () async {
      const channel = MethodChannel('app.louvorja/updater');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'nope');
      });

      await MulticastLock.acquire();
      await MulticastLock.release();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });
}
