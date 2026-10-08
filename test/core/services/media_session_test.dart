import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/media_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.louvorja/media');

  setUp(() {
    MediaSession.onPlayPause = null;
    MediaSession.onPrev = null;
    MediaSession.onNext = null;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    MediaSession.onPlayPause = null;
    MediaSession.onPrev = null;
    MediaSession.onNext = null;
  });

  test('init sem plugin nativo → _active=false e chamadas são no-op', () async {
    await MediaSession.init();

    // Não lança mesmo com plugin ausente:
    await MediaSession.setMetadata(title: 'Hino', album: 'Coletânia');
    await MediaSession.setPlaybackState(isPlaying: true, positionMs: 1000);
    await MediaSession.show();
    await MediaSession.hide();
    await MediaSession.release();
  });

  test('init com plugin OK ativa e callbacks disparam via handler', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'init') return null;
      return null;
    });

    bool? playArg;
    var prev = 0;
    var next = 0;
    MediaSession.onPlayPause = (p) => playArg = p;
    MediaSession.onPrev = () => prev++;
    MediaSession.onNext = () => next++;

    await MediaSession.init();

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        const MethodCall('onPlayPause', false),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('onPrev')),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('onNext')),
      (_) {},
    );

    expect(playArg, isFalse);
    expect(prev, 1);
    expect(next, 1);
  });

  test('setMetadata/setPlaybackState com plugin ativo não lançam', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    await MediaSession.init();
    await MediaSession.setMetadata(
      title: 'Hino 1',
      album: 'Album',
      artUrl: 'https://x/y.png',
      durationMs: 120000,
    );
    await MediaSession.setPlaybackState(isPlaying: false, positionMs: 0);
    await MediaSession.show();
    await MediaSession.hide();
  });

  test('release limpa handler e desativa', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    await MediaSession.init();

    await MediaSession.release();
    // Pós-release, chamadas são no-op silenciosas.
    await MediaSession.show();
    await MediaSession.setMetadata(title: 'x', album: 'y');
  });
}
