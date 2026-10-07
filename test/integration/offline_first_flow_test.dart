import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/download_queue.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';

/// Disco REAL em dir temporário — prova persistência de verdade (não fake).
class _DiskStorage implements DownloadQueueStorage {
  final String path;
  _DiskStorage(this.path);

  @override
  Future<String> read() async {
    final f = File(path);
    if (!await f.exists()) return '{}';
    return f.readAsString();
  }

  @override
  Future<void> write(String json) async {
    await File(path).writeAsString(json, flush: true);
  }
}

/// Offline port real de disco: download escreve o arquivo no diretório.
/// Falha UMA vez nos ids em [failOnceIds] simulando rede instável.
class _DiskOffline implements OfflineMusicPort {
  final Directory dir;
  final Set<int> failOnceIds;
  final Set<int> _failed = {};

  _DiskOffline(this.dir, {this.failOnceIds = const {}});

  final downloaded = <int>{};
  final removed = <int>{};

  @override
  bool get isSupported => true;

  @override
  Future<String?> localPathFor(int musicId, {bool instrumental = false}) async {
    if (File('${dir.path}/$musicId.mp3').existsSync()) {
      return '${dir.path}/$musicId.mp3';
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
    if (failOnceIds.contains(musicId) && !_failed.contains(musicId)) {
      _failed.add(musicId);
      throw Exception('rede instável (simulada, 1ª tentativa)');
    }
    final f = File('${dir.path}/$musicId.mp3');
    onReceiveProgress?.call(50, 100);
    await f.writeAsBytes(List<int>.filled(1024, musicId % 255));
    onReceiveProgress?.call(100, 100);
    downloaded.add(musicId);
    return f.path;
  }

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) async {
    removed.add(musicId);
    final f = File('${dir.path}/$musicId.mp3');
    if (f.existsSync()) f.deleteSync();
  }
}

DownloadQueueItem _item(int id) => DownloadQueueItem(
  musicId: id,
  title: 'Hino $id',
  url: 'https://cdn/$id.mp3',
);

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('apk_integration_offline');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  group('Integração offline-first — fila serial com disco REAL', () {
    test(
        'download em lote → app "reinicia" (nova queue, mesmo storage) → '
        'nada se perde, nada duplica', () async {
      final storagePath = '${tmp.path}/queue.json';
      final offline = _DiskOffline(tmp);
      final queue = DownloadQueue(
        offline: offline,
        storage: _DiskStorage(storagePath),
        interItemDelay: Duration.zero,
      );

      queue.enqueue([_item(1), _item(2)]);

      // Espera drain completo (polling na porta offline).
      for (var i = 0; i < 150; i++) {
        if (offline.downloaded.containsAll({1, 2})) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(offline.downloaded, {1, 2});
      expect(File('${tmp.path}/1.mp3').existsSync(), isTrue);
      expect(File('${tmp.path}/2.mp3').existsSync(), isTrue);

      // ===== APP "REINICIA": nova instância, MESMO storage e MESMO disco =====
      final offline2 = _DiskOffline(tmp);
      DownloadQueue(
        offline: offline2,
        storage: _DiskStorage(storagePath),
        interItemDelay: Duration.zero,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Índice local (arquivo no disco) evita re-download do que já baixou.
      expect(offline2.downloaded, isEmpty);
      expect(offline2.removed, isEmpty);
      expect(File('${tmp.path}/1.mp3').existsSync(), isTrue);
      expect(File('${tmp.path}/2.mp3').existsSync(), isTrue);
    });

    test(
        'app fecha no MEIO do lote (rede falha) → reinício retoma e completa',
        () async {
      final storagePath = '${tmp.path}/queue.json';
      final offline = _DiskOffline(tmp, failOnceIds: {2});
      final queue = DownloadQueue(
        offline: offline,
        storage: _DiskStorage(storagePath),
        interItemDelay: Duration.zero,
      );

      queue.enqueue([_item(1), _item(2), _item(3)]);
      // Tempo do item 1 concluir e o 2 falhar:
      await Future<void>.delayed(const Duration(milliseconds: 200));
      // 1º boot: 1 e 3 baixam; 2 falha (rede) e fica PERSISTIDO na fila.
      expect(offline.downloaded, {1, 3});
      expect(File('${tmp.path}/1.mp3').existsSync(), isTrue);
      expect(File('${tmp.path}/3.mp3').existsSync(), isTrue);
      final persisted = jsonDecode(
        File(storagePath).readAsStringSync(),
      )['pending'] as List<dynamic>;
      expect(
        persisted.map((e) => e['musicId']),
        contains(2),
        reason: 'item que falhou tem que sobreviver ao fechamento do app',
      );

      // Reinício: fila restaurada + porta SEM falha → completa o faltante.
      final offline2 = _DiskOffline(tmp);
      DownloadQueue(
        offline: offline2,
        storage: _DiskStorage(storagePath),
        interItemDelay: Duration.zero,
      );
      for (var i = 0; i < 200; i++) {
        if (offline2.downloaded.contains(2)) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(offline2.downloaded, contains(2));
      expect(File('${tmp.path}/2.mp3').existsSync(), isTrue);
    });

    test('remove offline apaga do disco; reinício não re-baixa removido',
        () async {
      final storagePath = '${tmp.path}/queue.json';
      final offline = _DiskOffline(tmp);
      final queue = DownloadQueue(
        offline: offline,
        storage: _DiskStorage(storagePath),
        interItemDelay: Duration.zero,
      );
      queue.enqueue([_item(7)]);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(offline.downloaded, {7});

      await offline.remove(7);
      expect(File('${tmp.path}/7.mp3').existsSync(), isFalse);

      // Reinício: item não volta (fila vazia e índice local sem o hino).
      final offline2 = _DiskOffline(tmp);
      DownloadQueue(
        offline: offline2,
        storage: _DiskStorage(storagePath),
        interItemDelay: Duration.zero,
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(offline2.downloaded, isEmpty);
    });
  });
}
