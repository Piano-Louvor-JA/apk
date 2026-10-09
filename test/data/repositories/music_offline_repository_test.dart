library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/repositories/music_offline_repository.dart';

void main() {
  late Directory directory;
  late HttpServer server;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('piano-offline-test');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..add([1, 2, 3, 4]);
      request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  test('baixa faixa e retorna arquivo local existente', () async {
    final repository = MusicOfflineRepository(Dio(), directory.path);
    final url = 'http://${server.address.address}:${server.port}/vocal.mp3';

    final path = await repository.download(musicId: 42, url: url);

    expect(File(path).existsSync(), isTrue);
    expect(File(path).readAsBytesSync(), [1, 2, 3, 4]);
    expect(await repository.localPathFor(42), path);
  });

  test('MP3 vazio indexado não é aceito como baixado', () async {
    final partial = File('${directory.path}/42_vocal.mp3');
    await partial.create();
    await File('${directory.path}/music_offline_index.json').writeAsString(
      jsonEncode({
        '42_vocal': {'path': partial.path},
      }),
    );

    final repository = MusicOfflineRepository(Dio(), directory.path);
    expect(await repository.localPathFor(42), isNull);
  });

  test('remove arquivo e indice da faixa', () async {
    final repository = MusicOfflineRepository(Dio(), directory.path);
    final url = 'http://${server.address.address}:${server.port}/vocal.mp3';
    await repository.download(musicId: 42, url: url);

    await repository.remove(42);

    expect(await repository.localPathFor(42), isNull);
  });

  test('falha remove arquivo parcial e nao indexa', () async {
    final repository = MusicOfflineRepository(Dio(), directory.path);

    expect(
      () =>
          repository.download(musicId: 42, url: 'http://127.0.0.1:1/fail.mp3'),
      throwsA(isA<DioException>()),
    );
    expect(await repository.localPathFor(42), isNull);
  });
}
