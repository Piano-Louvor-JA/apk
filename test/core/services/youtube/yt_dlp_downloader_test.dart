import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/youtube/yt_dlp_downloader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('teste/ytdlp');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('ytdlp'));
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await dir.delete(recursive: true);
  });

  /// Lado nativo de mentira: avisa o progresso e "baixa" os arquivos.
  void fakeNative({bool separate = true, List<MethodCall>? calls}) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls?.add(call);
      if (call.method == 'cancel') return true;
      final args = (call.arguments as Map).cast<String, Object?>();
      final work = Directory(args['dir']! as String)..createSync();
      Future<void> progress(double percent, int stage) =>
          messenger.handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('progress', {
                'id': args['id'],
                'percent': percent,
                'stage': stage,
              }),
            ),
            (_) {},
          );
      await progress(50, 1);
      await progress(100, 2);
      final video = File('${work.path}/136.mp4')..writeAsBytesSync([1, 2]);
      if (!separate) return {'video': video.path, 'audio': null};
      final audio = File('${work.path}/140.m4a')..writeAsBytesSync([3]);
      return {'video': video.path, 'audio': audio.path};
    });
  }

  test(
    'baixa vídeo e áudio separados, junta e limpa a pasta de trabalho',
    () async {
      final calls = <MethodCall>[];
      fakeNative(calls: calls);
      final muxed = <String>[];
      final downloader = YtDlpDownloader(
        channel: channel,
        mux: ({required video, required audio, required output}) async {
          muxed.addAll([video.split('/').last, audio.split('/').last]);
          await File(output).writeAsBytes([9]);
        },
      );
      final progress = <(int, int)>[];
      final out = '${dir.path}/final.mp4';
      await downloader.download(
        'https://www.youtube.com/watch?v=AAAAAAAAAAA',
        out,
        onProgress: (done, total) => progress.add((done, total)),
      );
      expect(muxed, ['136.mp4', '140.m4a']);
      expect(File(out).readAsBytesSync(), [9]);
      expect(Directory('$out.ytdlp').existsSync(), isFalse);
      expect(progress, [(0, 0), (450, 1000), (1000, 1000)]);
      final args = (calls.single.arguments as Map);
      expect(args['url'], 'https://www.youtube.com/watch?v=AAAAAAAAAAA');
      expect(args['maxHeight'], 720);
    },
  );

  test('arquivo único (sem trilhas separadas) vira o mp4 final', () async {
    fakeNative(separate: false);
    final downloader = YtDlpDownloader(
      channel: channel,
      mux: ({required video, required audio, required output}) async =>
          fail('não deveria juntar'),
    );
    final out = '${dir.path}/final.mp4';
    await downloader.download('https://youtu.be/AAAAAAAAAAA', out);
    expect(File(out).readAsBytesSync(), [1, 2]);
  });

  test(
    'erro do yt-dlp chega a quem pediu; cancelar sem download não faz nada',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'FAILED', message: 'HTTP Error 403');
      });
      final downloader = YtDlpDownloader(channel: channel);
      await expectLater(
        downloader.download(
          'https://youtu.be/AAAAAAAAAAA',
          '${dir.path}/x.mp4',
        ),
        throwsA(isA<PlatformException>()),
      );
      await downloader.cancel();
    },
  );
}
