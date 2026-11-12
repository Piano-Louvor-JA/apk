import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/media_duration_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'áudio sem container MP4 obtém duração pelo leitor nativo Android',
    () async {
      final directory = await Directory.systemTemp.createTemp('lit-audio');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/audio.mp3');
      await file.writeAsBytes([73, 68, 51]);
      const channel = MethodChannel('app.louvorja/liturgy-media');
      MethodCall? call;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (value) async {
            call = value;
            return 187500;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      expect(await MediaDurationReader.readMs(file.path), 187500);
      expect(call!.method, 'mediaDuration');
      expect(call!.arguments, {'path': file.path});
    },
  );
}
