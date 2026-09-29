library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/repositories/music_offline_repository_native.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late Directory tmp;
  late File indexFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('offline_idx');
    indexFile = File('${tmp.path}/music_offline_index.json');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  group('indice offline v2 (metadados)', () {
    test('download persiste metadados e listByAlbum recupera', () async {
      final repo = MusicOfflineRepository(_dio(), tmp.path);
      await repo.download(
        musicId: 12,
        url: 'https://example.com/12.mp3',
        metadata: const OfflineTrackMeta(
          musicId: 12,
          title: 'Nosso Sol é Jesus',
          number: '001',
          albumId: 1,
          albumName: 'Hinário Adventista',
        ),
      );

      final albums = await repo.listDownloaded(albumId: 1);
      expect(albums, hasLength(1));
      expect(albums.first.title, 'Nosso Sol é Jesus');
      expect(albums.first.number, '001');
      expect(albums.first.albumName, 'Hinário Adventista');

      // Todos (sem filtro de album)
      final all = await repo.listDownloaded();
      expect(all, hasLength(1));
    });

    test(
      ' indice v1 (path puro) continua legivel: play funciona, titulo fallback',
      () async {
        // Formato antigo: {"12_vocal": "/caminho/12.mp3"}
        final oldFile = File('${tmp.path}/12_vocal.mp3');
        oldFile.createSync(recursive: true);
        indexFile.writeAsStringSync(jsonEncode({'12_vocal': oldFile.path}));

        final repo = MusicOfflineRepository(_dio(), tmp.path);

        final path = await repo.localPathFor(12);
        expect(path, oldFile.path); // play continua funcionando

        final all = await repo.listDownloaded();
        expect(all, hasLength(1));
        expect(all.first.title, 'Hino #12'); // fallback sem metadados
        expect(all.first.albumId, isNull);
      },
    );

    test('remove apaga do indice v2', () async {
      final repo = MusicOfflineRepository(_dio(), tmp.path);
      await repo.download(
        musicId: 12,
        url: 'https://example.com/12.mp3',
        metadata: const OfflineTrackMeta(musicId: 12, title: 'X', albumId: 1),
      );
      expect(await repo.listDownloaded(), hasLength(1));
      await repo.remove(12);
      expect(await repo.listDownloaded(), isEmpty);
    });
  });
}

Dio _dio() {
  final dio = _MockDio();
  when(
    () => dio.download(
      any(),
      any(),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenAnswer((inv) async {
    final String path = inv.positionalArguments[1];
    File(path).writeAsBytesSync([1, 2, 3]);
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  });
  return dio;
}
