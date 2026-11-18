import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_media_muxer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('combina faixas locais sem enviar arquivos à rede', () async {
    MethodCall? recorded;
    const channel = MethodChannel('app.louvorja/liturgy-media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          recorded = call;
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await LiturgyMediaMuxer.combine(
      video: '/video.mp4',
      audio: '/audio.m4a',
      output: '/final.mp4',
    );
    expect(recorded!.method, 'mux');
    expect(recorded!.arguments, {
      'video': '/video.mp4',
      'audio': '/audio.m4a',
      'output': '/final.mp4',
    });
  });
}
