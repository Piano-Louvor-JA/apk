import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_link_info.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_video_cache.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_download_index.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_downloads.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/domain/repositories/liturgy_link_repository.dart';

/// Baixa em pedaços; cada pedaço espera o `gate` liberar (para testar parar).
class ChunkRemote implements LiturgyLinkRepository {
  final started = <String>[];
  final failIds = <String>{};
  Completer<void>? gate;

  /// Nunca manda bytes (como o YouTube travado).
  bool hang = false;

  @override
  Future<LiturgyLinkInfo> info(String url) async =>
      const LiturgyLinkInfo(title: 'x');

  @override
  Future<void> download(
    String url,
    String destination, {
    void Function(int, int)? onProgress,
  }) async {
    started.add(url);
    if (failIds.any(url.contains)) throw StateError('offline');
    if (hang) return Completer<void>().future;
    final sink = File(destination).openWrite();
    try {
      for (var i = 1; i <= 2; i++) {
        if (gate != null) await gate!.future;
        sink.add([1, 2, 3, 4, 5]);
        onProgress?.call(i * 5, 10);
      }
    } finally {
      await sink.close();
    }
  }
}

const v1 = YoutubeVideo(videoId: 'AAAAAAAAAAA', title: 'Um');
const v2 = YoutubeVideo(videoId: 'BBBBBBBBBBB', title: 'Dois');

Future<void> settle(YoutubeDownloads d) async {
  for (var i = 0; i < 50 && d.hasPending; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory dir;
  late ChunkRemote remote;
  late YoutubeDownloads downloads;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('yt-downloads');
    remote = ChunkRemote();
    downloads = YoutubeDownloads(
      cache: () async => LiturgyVideoCache(dir, remote),
    );
  });
  tearDown(() => dir.delete(recursive: true));

  test('baixa em fila, um por vez, e mede o espaço usado', () async {
    downloads.download([v1, v2, v1]);
    expect(downloads.statusOf(v2.videoId).phase, YoutubeDownloadPhase.queued);
    await settle(downloads);
    expect(remote.started, hasLength(2));
    expect(downloads.statusOf(v1.videoId).phase, YoutubeDownloadPhase.done);
    expect(downloads.statusOf(v1.videoId).bytes, 10);
    expect(downloads.totalVideos, 2);
    expect(downloads.totalBytes, 20);
    // Já baixado não baixa de novo.
    downloads.download([v1]);
    await settle(downloads);
    expect(remote.started, hasLength(2));
  });

  test(
    'outra instância enxerga o que já foi baixado (sobrevive a reabrir)',
    () async {
      downloads.download([v1]);
      await settle(downloads);
      final reopened = YoutubeDownloads(
        cache: () async => LiturgyVideoCache(dir, remote),
      );
      await reopened.refresh([v1.videoId, v2.videoId]);
      expect(reopened.statusOf(v1.videoId).phase, YoutubeDownloadPhase.done);
      expect(reopened.statusOf(v2.videoId).phase, YoutubeDownloadPhase.none);
      expect(reopened.totalVideos, 1);
    },
  );

  test('falha fica marcada e pode tentar de novo', () async {
    remote.failIds.add(v1.videoId);
    downloads.download([v1]);
    await settle(downloads);
    expect(downloads.statusOf(v1.videoId).phase, YoutubeDownloadPhase.failed);
    remote.failIds.clear();
    downloads.download([v1]);
    await settle(downloads);
    expect(downloads.statusOf(v1.videoId).phase, YoutubeDownloadPhase.done);
  });

  test(
    'parar interrompe o atual, esvazia a fila e não deixa arquivo',
    () async {
      remote.gate = Completer<void>();
      downloads.download([v1, v2]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        downloads.statusOf(v1.videoId).phase,
        YoutubeDownloadPhase.downloading,
      );
      downloads.cancelAll([v1.videoId, v2.videoId]);
      remote.gate!.complete();
      await settle(downloads);
      expect(downloads.statusOf(v1.videoId).phase, YoutubeDownloadPhase.none);
      expect(downloads.statusOf(v2.videoId).phase, YoutubeDownloadPhase.none);
      expect(remote.started, hasLength(1));
      expect(dir.listSync(), isEmpty);
    },
  );

  test(
    'travado sem dados: desiste e marca falha; cancelar não espera',
    () async {
      YoutubeDownloads.stallTimeout = const Duration(milliseconds: 50);
      addTearDown(
        () => YoutubeDownloads.stallTimeout = const Duration(seconds: 90),
      );
      remote.hang = true;
      downloads.download([v1]);
      await settle(downloads);
      expect(downloads.statusOf(v1.videoId).phase, YoutubeDownloadPhase.failed);

      YoutubeDownloads.stallTimeout = const Duration(minutes: 5);
      downloads.download([v2]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        downloads.statusOf(v2.videoId).phase,
        YoutubeDownloadPhase.downloading,
      );
      downloads.cancel(v2.videoId);
      await settle(downloads);
      expect(downloads.statusOf(v2.videoId).phase, YoutubeDownloadPhase.none);
      expect(downloads.hasPending, isFalse);
    },
  );

  test('apagar remove a cópia do disco', () async {
    downloads.download([v1]);
    await settle(downloads);
    expect(await downloads.remove(v1.videoId), isTrue);
    expect(downloads.statusOf(v1.videoId).phase, YoutubeDownloadPhase.none);
    expect(downloads.totalVideos, 0);
    expect(await downloads.remove(v1.videoId), isFalse);
  });

  test('formata o tamanho', () {
    expect(formatYoutubeBytes(512), '512 B');
    expect(formatYoutubeBytes(1536), '1.5 KB');
    expect(formatYoutubeBytes((1.6 * 1024 * 1024 * 1024).round()), '1.6 GB');
    expect(formatYoutubeBytes(350 * 1024 * 1024), '350 MB');
  });

  group('aba Baixados, nome do arquivo e ordem', () {
    test('baixar registra com o nome automático; apagar tira do registro', () async {
      downloads.download([v1, v2]);
      await settle(downloads);
      expect(downloads.downloaded.map((e) => e.videoId), [v2.videoId, v1.videoId]);
      expect(downloads.fileNameOf(v1), 'Um_${v1.videoId}.mp4');
      expect((await YoutubeDownloadIndex().entries()), hasLength(2));
      expect(await downloads.remove(v1.videoId), isTrue);
      expect(downloads.downloaded.map((e) => e.videoId), [v2.videoId]);
      expect((await YoutubeDownloadIndex().entries()).single.videoId, v2.videoId);
    });

    test('renomear guarda o nome; baixando ou não baixado recusa', () async {
      expect(await downloads.rename(v1, 'X'), isNull);
      downloads.download([v1]);
      expect(await downloads.rename(v1, 'X'), isNull);
      await settle(downloads);
      expect(await downloads.rename(v1, 'Culto de sábado'), 'Culto de sabado_${v1.videoId}.mp4');
      expect(downloads.downloaded.single.renamed, isTrue);
      final reopened = YoutubeDownloads(cache: () async => LiturgyVideoCache(dir, remote));
      await reopened.refresh([v1.videoId]);
      await reopened.loadIndex();
      await reopened.loadIndex();
      expect(reopened.fileNameOf(v1), 'Culto de sabado_${v1.videoId}.mp4');
      expect(reopened.downloaded.single.renamed, isTrue);
    });

    test('baixado antes do registro: adotar com os dados conhecidos e renomear', () async {
      downloads.download([v1, v2]);
      await settle(downloads);
      SharedPreferences.setMockInitialValues({});
      final reopened = YoutubeDownloads(cache: () async => LiturgyVideoCache(dir, remote));
      await reopened.refresh([v1.videoId, v2.videoId]);
      await reopened.adopt([v1, const YoutubeVideo(videoId: 'CCCCCCCCCCC', title: 'Não baixado')]);
      expect(reopened.downloaded.map((e) => e.videoId), [v1.videoId]);
      expect(await reopened.rename(v2, 'Dois novo'), 'Dois novo_${v2.videoId}.mp4');
      expect(reopened.downloaded.map((e) => e.videoId), [v2.videoId, v1.videoId]);
      await reopened.adopt([v1]);
      expect(reopened.downloaded, hasLength(2));
    });

    test('arrastar reordena e a ordem sobrevive a reabrir; novo entra no topo', () async {
      downloads.download([v1, v2]);
      await settle(downloads);
      await downloads.reorder(v2.videoId, v1.videoId);
      expect(downloads.downloaded.map((e) => e.videoId), [v1.videoId, v2.videoId]);
      final reopened = YoutubeDownloads(cache: () async => LiturgyVideoCache(dir, remote));
      await reopened.refresh([v1.videoId, v2.videoId]);
      await reopened.loadIndex();
      expect(reopened.downloaded.map((e) => e.videoId), [v1.videoId, v2.videoId]);
      const v3 = YoutubeVideo(videoId: 'CCCCCCCCCCC', title: 'Três');
      reopened.download([v3]);
      await settle(reopened);
      expect(reopened.downloaded.map((e) => e.videoId), [v3.videoId, v1.videoId, v2.videoId]);
    });

    test('sem armazenamento não quebra', () async {
      final broken = YoutubeDownloads(
        cache: () async => LiturgyVideoCache(dir, remote),
        index: YoutubeDownloadIndex(prefs: () async => throw StateError('sem prefs')),
      );
      await broken.reloadIndex();
      broken.download([v1]);
      await settle(broken);
      expect(broken.statusOf(v1.videoId).phase, YoutubeDownloadPhase.done);
      expect(broken.downloaded, isEmpty);
      expect(await broken.rename(v1, 'x'), isNull);
      await broken.adopt([v1]);
      await broken.reorder(v1.videoId, v2.videoId);
      expect(await broken.remove(v1.videoId), isTrue);
    });
  });
}
