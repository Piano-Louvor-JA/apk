import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';

class _Call {
  final String method;
  final String url;
  final Map<String, dynamic>? body;
  final String? bearerToken;
  _Call(this.method, this.url, this.body, this.bearerToken);
}

void main() {
  late List<_Call> calls;
  late CustomCatalogApiImpl api;

  setUp(() {
    calls = [];
    api = CustomCatalogApiImpl(
      fetch: (method, url, {body, bearerToken}) async {
        calls.add(_Call(method, url, body, bearerToken));
        if (method == 'POST' && url.endsWith('/collections')) {
          return {'id_collection': 42};
        }
        return <String, dynamic>{};
      },
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );
  });

  group('createCollection', () {
    test('POST /collections com nome + Bearer, retorna id', () async {
      final id = await api.createCollection(
        name: 'Culto Jovem',
        description: 'Coletânea do sábado',
        bearerToken: 'tok',
      );

      expect(id, 42);
      final c = calls.single;
      expect(c.method, 'POST');
      expect(c.url, 'https://api.test/v1/custom/collections');
      expect(c.body, {
        'name': 'Culto Jovem',
        'description': 'Coletânea do sábado',
      });
      expect(c.bearerToken, 'tok');
    });

    test('description vazia não vai no body', () async {
      await api.createCollection(
        name: 'X',
        description: '',
        bearerToken: 'tok',
      );
      expect(calls.single.body, {'name': 'X'});
    });
  });

  group('addMusicToCollection', () {
    test('POST /collections/:id/musics com official_music_id', () async {
      await api.addMusicToCollection(
        collectionId: 42,
        officialMusicId: 777,
        bearerToken: 'tok',
      );

      final c = calls.single;
      expect(c.method, 'POST');
      expect(c.url, 'https://api.test/v1/custom/collections/42/musics');
      expect(c.body, {'official_music_id': 777});
      expect(c.bearerToken, 'tok');
    });
  });

  group('removeMusicFromCollection', () {
    test('DELETE /musics/:id com Bearer', () async {
      await api.removeMusicFromCollection(musicId: 999, bearerToken: 'tok');

      final c = calls.single;
      expect(c.method, 'DELETE');
      expect(c.url, 'https://api.test/v1/custom/musics/999');
      expect(c.bearerToken, 'tok');
    });
  });
}
