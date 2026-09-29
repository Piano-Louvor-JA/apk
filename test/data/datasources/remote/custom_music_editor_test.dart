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
        if (method == 'POST' && url.endsWith('/musics')) {
          return {'id_music': 55, 'id_collection': 6, 'name': body?['name']};
        }
        if (method == 'POST' && url.endsWith('/lyrics')) {
          return {'id_lyric': 900, 'id_music': 55, 'lyric': body?['lyric']};
        }
        if (method == 'GET' && url.endsWith('/lyrics')) {
          return {
            'data': [
              {
                'id_lyric': 1,
                'lyric': 'Primeiro slide',
                'time': '00:00.000',
                'order': 0,
              },
              {
                'id_lyric': 2,
                'lyric': 'Segundo slide',
                'time': '00:04.500',
                'order': 1,
              },
            ],
          };
        }
        return <String, dynamic>{};
      },
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );
  });

  group('createMusic', () {
    test('POST /collections/:id/musics com name+lyric+audio', () async {
      final id = await api.createMusic(
        collectionId: 6,
        name: 'Minha música',
        lyric: 'estrofe 1\n\nestrofe 2',
        idFileAudio: 77,
        bearerToken: 'tok',
      );

      expect(id, 55);
      final c = calls.single;
      expect(c.method, 'POST');
      expect(c.url, 'https://api.test/v1/custom/collections/6/musics');
      expect(c.body, {
        'name': 'Minha música',
        'lyric': 'estrofe 1\n\nestrofe 2',
        'id_file_audio': 77,
      });
      expect(c.bearerToken, 'tok');
    });

    test('sem áudio → body sem id_file_audio', () async {
      await api.createMusic(
        collectionId: 6,
        name: 'X',
        lyric: 'l',
        bearerToken: 'tok',
      );
      expect(calls.single.body, {'name': 'X', 'lyric': 'l'});
    });
  });

  group('addLyric (estrofe com timing)', () {
    test('POST /musics/:id/lyrics com time e order', () async {
      final id = await api.addLyric(
        musicId: 55,
        lyric: 'Primeiro slide',
        time: '00:00.000',
        order: 0,
        bearerToken: 'tok',
      );

      expect(id, 900);
      final c = calls.single;
      expect(c.url, 'https://api.test/v1/custom/musics/55/lyrics');
      expect(c.body, {
        'lyric': 'Primeiro slide',
        'time': '00:00.000',
        'order': 0,
      });
    });
  });

  group('fetchLyrics', () {
    test('GET /musics/:id/lyrics mapeia estrofes ordenadas', () async {
      final lyrics = await api.fetchLyrics(55, bearerToken: 'tok');

      expect(lyrics, hasLength(2));
      expect(lyrics[0].id, 1);
      expect(lyrics[0].text, 'Primeiro slide');
      expect(lyrics[0].time, '00:00.000');
      expect(lyrics[1].time, '00:04.500');
      final c = calls.single;
      expect(c.url, 'https://api.test/v1/custom/musics/55/lyrics');
    });
  });

  group('deleteLyric', () {
    test('DELETE /lyrics/:id', () async {
      await api.deleteLyric(900, bearerToken: 'tok');
      expect(
        calls.single.method == 'DELETE' &&
            calls.single.url.endsWith('/lyrics/900'),
        isTrue,
      );
    });
  });
}
