import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_link_info.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_video_cache.dart';
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
}
