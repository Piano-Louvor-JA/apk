library;

import 'package:louvorja_piano_mobile/core/errors/louvorja_api_exception.dart';
import 'dart:convert';

import 'package:dio/dio.dart' show ProgressCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/download_queue.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';

class _MemStorage implements DownloadQueueStorage {
  String _json = '{}';
  @override
  Future<String> read() async => _json;

  @override
  Future<void> write(String json) async => _json = json;
}

class _FakeOffline implements OfflineMusicPort {
  final Set<int> alreadyDownloaded;
  final Set<int> downloaded = {};
  Set<int> failIds;
  int concurrent = 0;
  int maxConcurrent = 0;
  final List<int> order = [];

  _FakeOffline({this.alreadyDownloaded = const {}, this.failIds = const {}});

  @override
  bool get isSupported => true;

  @override
  Future<String?> localPathFor(int musicId, {bool instrumental = false}) async {
    if (alreadyDownloaded.contains(musicId) || downloaded.contains(musicId)) {
      return '/local/$musicId.mp3';
    }
    return null;
  }

  @override
  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    ProgressCallback? onReceiveProgress,
  }) async {
    concurrent++;
    maxConcurrent = concurrent > maxConcurrent ? concurrent : maxConcurrent;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    onReceiveProgress?.call(50, 100);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    onReceiveProgress?.call(100, 100);
    concurrent--;
    if (failIds.contains(musicId)) throw Exception('falha $musicId');
    downloaded.add(musicId);
    order.add(musicId);
    return '/local/$musicId.mp3';
  }

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) async {
    downloaded.remove(musicId);
  }
}

DownloadQueueItem _item(int id) =>
    DownloadQueueItem(musicId: id, title: 'Hino $id', url: 'https://x/$id.mp3');

/// Simula API em rate limit: todo download falha com serverBusy (429).
class _RateLimitedOffline implements OfflineMusicPort {
  int calls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<String?> localPathFor(
    int musicId, {
    bool instrumental = false,
  }) async => null;

  @override
  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls++;
    throw const LouvorjaApiException('errors.serverBusy', '429');
  }

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) async {}
}

void main() {
  test('fila processa serialmente (nunca 2 simultaneos)', () async {
    final offline = _FakeOffline();
    final queue = DownloadQueue(
      offline: offline,
      storage: _MemStorage(),
      interItemDelay: Duration.zero,
    );
    queue.enqueue([_item(1), _item(2), _item(3)]);
    await queue.done;
    expect(offline.downloaded, {1, 2, 3});
    expect(offline.maxConcurrent, 1, reason: 'downloads devem ser seriais');
  });

  test('estado persiste pendencias; retoma no proximo boot', () async {
    final storage = _MemStorage();
    final offline1 = _FakeOffline(failIds: {2});
    final q1 = DownloadQueue(
      offline: offline1,
      storage: storage,
      interItemDelay: Duration.zero,
    );
    q1.enqueue([_item(1), _item(2)]);
    await q1.done;
    expect(offline1.downloaded, {1}, reason: '2 falha');

    // Novo boot com mesmo storage: item 2 pendente retenta, 3 novo.
    final offline2 = _FakeOffline();
    final q2 = DownloadQueue(
      offline: offline2,
      storage: storage,
      interItemDelay: Duration.zero,
    );
    q2.enqueue([_item(3)]);
    await q2.done;
    expect(offline2.downloaded, {
      2,
      3,
    }, reason: 'item 2 persistido retomado + item 3 novo');
  });

  test('itens ja baixados sao pulados', () async {
    final offline = _FakeOffline(alreadyDownloaded: {1});
    final queue = DownloadQueue(
      offline: offline,
      storage: _MemStorage(),
      interItemDelay: Duration.zero,
    );
    queue.enqueue([_item(1), _item(2)]);
    await queue.done;
    expect(offline.order, [2], reason: 'item 1 ja existia localmente');
  });

  test('progresso por faixa reporta bytes da faixa corrente', () async {
    final offline = _FakeOffline();
    final queue = DownloadQueue(
      offline: offline,
      storage: _MemStorage(),
      interItemDelay: Duration.zero,
    );
    final updates = <DownloadQueueProgress>[];
    queue.notifier.addListener(() {
      final p = queue.notifier.value;
      if (p != null) updates.add(p);
    });
    queue.enqueue([_item(1), _item(2)]);
    await queue.done;

    final byTrack = {for (final u in updates) u.musicId: u};
    expect(byTrack[1]?.received, 100, reason: 'faixa 1 chega a 100 bytes');
    expect(byTrack[1]?.total, 100);
    expect(byTrack[2]?.received, 100, reason: 'faixa 2 reporta progresso');
  });

  test('progresso reporta posição na fila (12/75)', () async {
    final offline = _FakeOffline();
    final queue = DownloadQueue(
      offline: offline,
      storage: _MemStorage(),
      interItemDelay: Duration.zero,
    );
    final updates = <DownloadQueueProgress>[];
    queue.notifier.addListener(() {
      final p = queue.notifier.value;
      if (p != null) updates.add(p);
    });
    queue.enqueue([_item(1), _item(2), _item(3)]);
    await queue.done;

    final byTrack = {for (final u in updates) u.musicId: u};
    expect(byTrack[1]?.queueIndex, 1, reason: 'faixa 1 = posição 1');
    expect(byTrack[1]?.queueTotal, 3, reason: 'lote de 3');
    expect(byTrack[2]?.queueIndex, 2, reason: 'faixa 2 = posição 2');
    expect(byTrack[2]?.queueTotal, 3);
    expect(byTrack[3]?.queueIndex, 3, reason: 'faixa 3 = posição 3');
  });

  test('enqueue duplicado nao reprocessa', () async {
    final offline = _FakeOffline();
    final queue = DownloadQueue(
      offline: offline,
      storage: _MemStorage(),
      interItemDelay: Duration.zero,
    );
    queue.enqueue([_item(1)]);
    queue.enqueue([_item(1)]);
    await queue.done;
    expect(offline.order, [1]);
  });

  test('estado inicial carrega pendencias do disco', () async {
    final storage = _MemStorage();
    storage.write(
      jsonEncode({
        'pending': [
          {'musicId': 7, 'title': 'H7', 'url': 'https://x/7.mp3'},
        ],
      }),
    );
    final offline = _FakeOffline();
    final queue = DownloadQueue(
      offline: offline,
      storage: storage,
      interItemDelay: Duration.zero,
    );
    await queue.done;
    expect(offline.downloaded, {7}, reason: 'pendencia do disco retomada');
  });

  test(
    'failedCount reporta falhas do drain; reseta no proximo drain',
    () async {
      final offline = _FakeOffline(failIds: {2, 3});
      final queue = DownloadQueue(
        offline: offline,
        storage: _MemStorage(),
        interItemDelay: Duration.zero,
      );
      queue.enqueue([_item(1), _item(2), _item(3)]);
      await queue.done;
      expect(queue.failedCount, 2, reason: '2 faixas falharam neste drain');
      expect(offline.order, [1], reason: 'so a faixa bem-sucedida contou');

      // Proximo drain: as mesmas pendencias sao retomadas do disco e agora
      // baixam com sucesso (failIds so afetou o primeiro drain).
      offline.failIds = {};
      queue.enqueue([_item(9)]);
      await queue.done;
      expect(queue.failedCount, 0, reason: 'novo drain zera o contador');
      expect(offline.downloaded, {1, 2, 3, 9});
    },
  );

  test(
    'circuit breaker: 429 seguidos param o drain (nao martela a API)',
    () async {
      final offline = _RateLimitedOffline();
      final queue = DownloadQueue(
        offline: offline,
        storage: _MemStorage(),
        interItemDelay: Duration.zero,
      );
      queue.enqueue(List.generate(50, _item));
      await queue.done;

      expect(
        offline.calls,
        lessThanOrEqualTo(4),
        reason: 'drain deve PARAR apos poucos 429 seguidos, nao tentar 50',
      );
      expect(
        queue.failedCount,
        50,
        reason: 'todas as 50 contam como falha (feedback ao usuario)',
      );
    },
  );
}
