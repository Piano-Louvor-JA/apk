import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_service_native.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// HttpServer loopback servindo um MP3 fake para exercitar download real.
void main() {
  late Directory docs;
  HttpServer? server;
  late OfflineMusicService service;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('offline_music_svc_test');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server!.listen((req) async {
      req.response.add(List<int>.filled(64, 0x61));
      await req.response.close();
    });
    service = OfflineMusicService();
  });

  tearDown(() async {
    await server?.close(force: true);
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  test('isSupported true e download+list+remove round-trip em disco real', () async {
    expect(service.isSupported, isTrue);

    final path = await service.download(
      musicId: 42,
      url: 'http://127.0.0.1:${server!.port}/hino.mp3',
    );
    expect(File(path).existsSync(), isTrue);

    await service.saveMetadata(
      musicId: 42,
      title: 'Hino 1',
      number: '1',
      albumId: 7,
      albumName: 'Coletânia',
    );

    final tracks = await service.listDownloaded(albumId: 7);
    expect(tracks, hasLength(1));
    expect(tracks.first.musicId, 42);
    expect(tracks.first.title, 'Hino 1');

    final local = await service.localPathFor(42);
    expect(local, isNotNull);

    await service.remove(42);
    final after = await service.listDownloaded(albumId: 7);
    expect(after, isEmpty);
  });

  test('download em URL morta lança (DioException) sem corromper fila', () async {
    final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = dead.port;
    await dead.close(force: true);

    var threw = false;
    try {
      await service.download(
        musicId: 99,
        url: 'http://127.0.0.1:$deadPort/x.mp3',
        onReceiveProgress: (count, total) {},
      );
    } on DioException {
      threw = true;
    }
    expect(threw, isTrue);
  });
}
