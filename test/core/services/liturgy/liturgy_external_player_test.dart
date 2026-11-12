import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_external_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'encaminha preferência explícita e não substitui falha por player interno',
    () async {
      const channel = MethodChannel('app.louvorja/liturgy-media');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            throw PlatformException(code: 'PLAYER_MISSING');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await expectLater(
        LiturgyExternalPlayer.open('/video.mp4', 'vlc'),
        throwsA(isA<PlatformException>()),
      );
      expect(calls.single.method, 'openPlayer');
      expect(calls.single.arguments, {'path': '/video.mp4', 'playerId': 'vlc'});
    },
  );
}
