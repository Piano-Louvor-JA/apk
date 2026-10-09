import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show ProgressCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/download_queue.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';

class _DiskStorage implements DownloadQueueStorage {
  _DiskStorage(this.file);
  final File file;

  @override
  Future<String> read() async =>
      await file.exists() ? file.readAsString() : '{}';

  @override
  Future<void> write(String json) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(json, flush: true);
  }
}

class _DiskOffline implements OfflineMusicPort {
  _DiskOffline(this.root, {Set<String>? fail, this.blockKey})
    : fail = fail ?? {};

  final Directory root;
  final Set<String> fail;
  final String? blockKey;
  final List<String> downloads = [];
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  String _key(int id, bool instrumental) =>
      '${id}_${instrumental ? 'instrumental' : 'vocal'}';

  @override
  bool get isSupported => true;

  @override
  Future<String?> localPathFor(int musicId, {bool instrumental = false}) async {
    final file = File('${root.path}/${_key(musicId, instrumental)}.mp3');
    return await file.exists() && await file.length() > 0 ? file.path : null;
  }

  @override
  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    ProgressCallback? onReceiveProgress,
  }) async {
    final key = _key(musicId, instrumental);
    final target = File('${root.path}/$key.mp3');
    final partial = File('${target.path}.part');
    await root.create(recursive: true);
    if (key == blockKey) {
      if (!started.isCompleted) started.complete();
      await release.future;
    }
    await partial.writeAsBytes(List<int>.filled(128, musicId));
    if (fail.remove(key)) throw FileSystemException('No space left on device');
    await partial.rename(target.path);
    downloads.add(key);
    onReceiveProgress?.call(128, 128);
    return target.path;
  }

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) async {
    final key = _key(musicId, instrumental);
    for (final suffix in ['.mp3', '.mp3.part']) {
      final file = File('${root.path}/$key$suffix');
      if (await file.exists()) await file.delete();
    }
  }
}

DownloadQueueItem _item(int id, {bool instrumental = false}) =>
    DownloadQueueItem(
      musicId: id,
      title: 'Hino $id',
      url: 'https://example.test/$id.mp3',
      instrumental: instrumental,
    );

void main() {
  group('offline-first v2', () {
    late Directory root;
    late _DiskStorage storage;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('louvorja-offline-');
      storage = _DiskStorage(File('${root.path}/queue.json'));
    });
    tearDown(() => root.delete(recursive: true));

    test(
      'partial MP3 is not accepted; pending item resumes after restart',
      () async {
        final first = _DiskOffline(root, fail: {'1_vocal'});
        final queue = DownloadQueue(
          offline: first,
          storage: storage,
          interItemDelay: Duration.zero,
        );
        queue.enqueue([_item(1)]);
        await queue.done;

        expect(await first.localPathFor(1), isNull);
        expect(await File('${root.path}/1_vocal.mp3.part').exists(), isTrue);
        expect(jsonDecode(await storage.read())['pending'], hasLength(1));

        final resumed = _DiskOffline(root);
        await DownloadQueue(
          offline: resumed,
          storage: storage,
          interItemDelay: Duration.zero,
        ).done;
        expect(await resumed.localPathFor(1), isNotNull);
        expect(await File('${root.path}/1_vocal.mp3').length(), 128);
      },
    );

    test(
      '35 items survive two restart boundaries without duplicates',
      () async {
        final items = List.generate(35, (i) => _item(i + 1));
        final first = _DiskOffline(root, fail: {'12_vocal', '24_vocal'});
        final q1 = DownloadQueue(
          offline: first,
          storage: storage,
          interItemDelay: Duration.zero,
        );
        q1.enqueue(items);
        await q1.done;

        final second = _DiskOffline(root, fail: {'24_vocal'});
        await DownloadQueue(
          offline: second,
          storage: storage,
          interItemDelay: Duration.zero,
        ).done;
        final third = _DiskOffline(root);
        await DownloadQueue(
          offline: third,
          storage: storage,
          interItemDelay: Duration.zero,
        ).done;

        final files = await root
            .list()
            .where((e) => e.path.endsWith('.mp3'))
            .toList();
        expect(files, hasLength(35));
        expect(
          await Future.wait(
            List.generate(35, (i) => third.localPathFor(i + 1)),
          ),
          everyElement(isNotNull),
        );
      },
    );

    test('disk-full failure stays pending and retries after restart', () async {
      final first = _DiskOffline(root, fail: {'2_vocal'});
      final q1 = DownloadQueue(
        offline: first,
        storage: storage,
        interItemDelay: Duration.zero,
      );
      q1.enqueue([_item(1), _item(2)]);
      await q1.done;
      expect(q1.failedCount, 1);
      expect(jsonDecode(await storage.read())['pending'].single['musicId'], 2);

      final second = _DiskOffline(root);
      final q2 = DownloadQueue(
        offline: second,
        storage: storage,
        interItemDelay: Duration.zero,
      );
      await q2.done;
      expect(q2.failedCount, 0);
      expect(await second.localPathFor(2), isNotNull);
    });

    test('removing queued item prevents its download', () async {
      final offline = _DiskOffline(root, blockKey: '1_vocal');
      final queue = DownloadQueue(
        offline: offline,
        storage: storage,
        interItemDelay: Duration.zero,
      );
      queue.enqueue([_item(1), _item(2), _item(3)]);
      await offline.started.future;
      await queue.cancel(3);
      offline.release.complete();
      await queue.done;

      expect(offline.downloads, ['1_vocal', '2_vocal']);
      expect(await offline.localPathFor(3), isNull);
    });

    test(
      'vocal and instrumental use isolated queue identities and paths',
      () async {
        final offline = _DiskOffline(root);
        final queue = DownloadQueue(
          offline: offline,
          storage: storage,
          interItemDelay: Duration.zero,
        );
        queue.enqueue([_item(7), _item(7, instrumental: true)]);
        await queue.done;

        expect(offline.downloads, ['7_vocal', '7_instrumental']);
        expect(await offline.localPathFor(7), isNotNull);
        expect(await offline.localPathFor(7, instrumental: true), isNotNull);
      },
    );
  });
}
