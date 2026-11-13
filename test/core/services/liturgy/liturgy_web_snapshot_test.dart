import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'captura somente a página web nativa sem exigir que o site permita iframe',
    () async {
      const channel = MethodChannel('app.louvorja/liturgy-media');
      MethodCall? requested;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            requested = call;
            return Uint8List.fromList([137, 80, 78, 71]);
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      expect(await LiturgyWebSnapshot.capture(), [137, 80, 78, 71]);
      expect(requested!.method, 'webSnapshot');
    },
  );
}
