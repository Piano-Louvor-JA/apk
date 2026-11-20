import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_video_cache.dart';
import 'package:louvorja_piano_mobile/domain/repositories/liturgy_link_repository.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_link_info.dart';

class Remote implements LiturgyLinkRepository {
  int calls = 0;
  bool fail = false;
  @override
  Future<LiturgyLinkInfo> info(String url) async =>
      const LiturgyLinkInfo(title: 'Vídeo');
  @override
  Future<void> download(
    String url,
    String destination, {
    void Function(int, int)? onProgress,
  }) async {
    calls++;
    await File(destination).writeAsBytes([1, 2, 3]);
    if (fail) throw StateError('offline');
  }
}

/// Só o Application Support importa aqui (é onde ficam os vídeos).
class _SupportDir extends PathProviderPlatform {
  _SupportDir(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  test('pasta padrão continua liturgy-videos no Application Support e acha o '
      'vídeo baixado pela versão anterior', () async {
    final support = await Directory.systemTemp.createTemp('lit-support');
    addTearDown(() => support.delete(recursive: true));
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SupportDir(support.path);
    addTearDown(() => PathProviderPlatform.instance = previous);

    final dir = await LiturgyVideoCache.defaultDirectory();
    // Mesmo caminho que a versão anterior montava à mão.
    expect(dir.path, '${support.path}/liturgy-videos');

    // Vídeo salvo antes da atualização continua sendo encontrado.
    const url = 'https://www.youtube.com/watch?v=AAAAAAAAAAA';
    final remote = Remote();
    await LiturgyVideoCache(dir, remote).download(url);
    final reopened = LiturgyVideoCache(
      await LiturgyVideoCache.defaultDirectory(),
      remote,
    );
    expect(await reopened.find(url), isNotNull);
    expect(remote.calls, 1);
  });

  test(
    'cache é idempotente, reutiliza URL equivalente e sobrevive à reabertura',
    () async {
      final dir = await Directory.systemTemp.createTemp('lit-video');
      addTearDown(() => dir.delete(recursive: true));
      final remote = Remote();
      final cache = LiturgyVideoCache(dir, remote);
      final path = await cache.download('https://youtu.be/abcdefghijk');
      expect(
        await cache.find('https://www.youtube.com/watch?v=abcdefghijk'),
        path,
      );
      expect(
        await LiturgyVideoCache(
          dir,
          remote,
        ).download('https://youtu.be/abcdefghijk'),
        path,
      );
      expect(remote.calls, 1);
    },
  );
  test('falha nunca publica arquivo incompleto no cache', () async {
    final dir = await Directory.systemTemp.createTemp('lit-video');
    addTearDown(() => dir.delete(recursive: true));
    final remote = Remote()..fail = true;
    final cache = LiturgyVideoCache(dir, remote);
    await expectLater(
      cache.download('https://example.org/video.mp4'),
      throwsStateError,
    );
    expect(await cache.find('https://example.org/video.mp4'), isNull);
    expect(dir.listSync(), isEmpty);
  });
}
