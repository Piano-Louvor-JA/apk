library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:louvorja_piano_mobile/core/services/stream_cache_service.dart';

class _Port implements OfflineMusicPort, OfflineLibraryPort {
  final Set<int> downloaded = {};
  final Map<int, OfflineListedTrack> tracks = {};
  bool failDownload = false;

  @override
  bool get isSupported => true;

  @override
  Future<String?> localPathFor(
    int musicId, {
    bool instrumental = false,
  }) async => downloaded.contains(musicId) ? '/local/$musicId.mp3' : null;

  @override
  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (failDownload) throw Exception('network');
    downloaded.add(musicId);
    return '/local/$musicId.mp3';
  }

  @override
  Future<void> saveMetadata({
    required int musicId,
    required String title,
    String? number,
    int? albumId,
    String? albumName,
    bool instrumental = false,
  }) async {
    tracks[musicId] = OfflineListedTrack(
      musicId: musicId,
      path: '/local/$musicId.mp3',
      title: title,
      number: number,
      albumId: albumId,
      albumName: albumName,
    );
  }

  @override
  Future<List<OfflineListedTrack>> listDownloaded({int? albumId}) async =>
      tracks.values
          .where((t) => albumId == null || t.albumId == albumId)
          .toList();

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) async {}
}

void main() {
  test('play remoto em Wi-Fi baixa a faixa com metadados', () async {
    final port = _Port();
    final svc = StreamCacheService(offline: port, wifiCheck: () async => true);

    final disparou = await svc.onRemotePlay(
      musicId: 10,
      url: 'https://api.louvorja.com.br/file/x.mp3',
      title: 'Nosso Sol é Jesus',
      number: '001',
      albumId: 100,
      albumName: 'Hinário',
    );

    expect(disparou, isTrue);
    expect(port.downloaded, contains(10));
    expect(port.tracks[10]!.title, 'Nosso Sol é Jesus');
    expect(port.tracks[10]!.albumId, 100);
  });

  test('fora do Wi-Fi NÃO baixa (dados móveis preservados)', () async {
    final port = _Port();
    final svc = StreamCacheService(offline: port, wifiCheck: () async => false);

    expect(await svc.onRemotePlay(musicId: 10, url: 'u', title: 'T'), isFalse);
    expect(port.downloaded, isEmpty);
  });

  test('faixa já baixada não baixa de novo', () async {
    final port = _Port()..downloaded.add(10);
    final svc = StreamCacheService(offline: port, wifiCheck: () async => true);

    expect(await svc.onRemotePlay(musicId: 10, url: 'u', title: 'T'), isFalse);
  });

  test('falha no download não propaga (reprodução segue)', () async {
    final port = _Port()..failDownload = true;
    final svc = StreamCacheService(offline: port, wifiCheck: () async => true);

    expect(await svc.onRemotePlay(musicId: 10, url: 'u', title: 'T'), isFalse);
  });
}
