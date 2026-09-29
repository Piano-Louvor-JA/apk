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
        if (method == 'GET' && url.contains('/collections/6/musics')) {
          return {
            'data': [
              {
                'id_music': 10,
                'id_collection': 6,
                'name': 'Nosso Sol é Jesus',
                'duration': '00:02:17',
                'official_music_id': 1,
              },
              {
                'id_music': 11,
                'id_collection': 6,
                'name': 'Letra própria',
                'duration': null,
                'official_music_id': null,
              },
            ],
          };
        }
        if (method == 'PUT' && url.endsWith('/collections/6')) {
          return {'id_collection': 6, 'name': body?['name']};
        }
        return <String, dynamic>{};
      },
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );
  });

  group('fetchCollectionMusics', () {
    test('GET /collections/:id/musics com Bearer, mapeia lista', () async {
      final musics = await api.fetchCollectionMusics(6, bearerToken: 'tok');

      expect(musics, hasLength(2));
      expect(musics[0].id, 10);
      expect(musics[0].name, 'Nosso Sol é Jesus');
      expect(musics[0].officialMusicId, 1);
      expect(musics[1].name, 'Letra própria');
      expect(musics[1].officialMusicId, isNull);
      final c = calls.single;
      expect(c.method, 'GET');
      expect(c.url, 'https://api.test/v1/custom/collections/6/musics');
      expect(c.bearerToken, 'tok');
    });
  });

  group('updateCollection', () {
    test('PUT /collections/:id com novo nome', () async {
      await api.updateCollection(6, name: 'Novo nome', bearerToken: 'tok');

      final c = calls.single;
      expect(c.method, 'PUT');
      expect(c.url, 'https://api.test/v1/custom/collections/6');
      expect(c.body, {'name': 'Novo nome'});
      expect(c.bearerToken, 'tok');
    });
  });

  group('deleteCollection', () {
    test('DELETE /collections/:id com Bearer', () async {
      await api.deleteCollection(6, bearerToken: 'tok');

      final c = calls.single;
      expect(c.method, 'DELETE');
      expect(c.url, 'https://api.test/v1/custom/collections/6');
      expect(c.bearerToken, 'tok');
    });
  });

  group('removeMusicFromCollection (regressão C4)', () {
    test('DELETE /musics/:id', () async {
      await api.removeMusicFromCollection(musicId: 10, bearerToken: 'tok');
      expect(calls.single.url, 'https://api.test/v1/custom/musics/10');
    });
  });
}
