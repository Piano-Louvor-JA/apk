import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';

/// Captura chamadas e devolve respostas fixas (sem mockar Dio).
class _FakeNet {
  final Map<String, dynamic> responses;
  final List<String> calls = [];

  _FakeNet(this.responses);

  Future<dynamic> fetch(
    String method,
    String url, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    calls.add('$method $url');
    return responses[url];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomCatalogApiImpl', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('fetchCollections mapeia data[] e resolve is_owner', () async {
      final net = _FakeNet({
        'https://api.test/v1/custom/collections': {
          'data': [
            {
              'id_collection': 2,
              'name': 'E2E Teste Rafael',
              'description': null,
              'author_name': 'Rafael Z.',
              'owner_id': 1,
              'is_owner': 0,
              'musics_count': 3,
            },
          ],
          'meta': {'total': 1},
        },
      });
      final api = CustomCatalogApiImpl(
        fetch: net.fetch,
        apiBaseUrl: 'https://api.test',
        filesBaseUrl: 'https://api.test/file',
      );

      final collections = await api.fetchCollections();

      expect(collections, hasLength(1));
      final c = collections.first;
      expect(c.id, 2);
      expect(c.name, 'E2E Teste Rafael');
      expect(c.authorName, 'Rafael Z.');
      expect(c.musicsCount, 3);
      expect(c.isOwner, isFalse);
      expect(net.calls.single, 'GET https://api.test/v1/custom/collections');
    });

    test(
      'fetchMusicDetail mapeia música + lyrics ordenadas por order',
      () async {
        final net = _FakeNet({
          'https://api.test/v1/custom/musics/7': {
            'id_music': 7,
            'name': 'Missão Para Todos',
            'duration': 210,
            'audio_url': '/custom/audio/xyz.mp3',
            'lyrics': [
              {
                'id_lyric': 2,
                'lyric': 'Estrofe 2',
                'time': '00:15.000',
                'order': 2,
              },
              {
                'id_lyric': 1,
                'lyric': 'Estrofe 1',
                'time': '00:00.500',
                'order': 1,
              },
            ],
          },
        });
        final api = CustomCatalogApiImpl(
          fetch: net.fetch,
          apiBaseUrl: 'https://api.test',
          filesBaseUrl: 'https://api.test/file',
        );

        final music = await api.fetchMusicDetail(7);

        expect(music.id, 7);
        expect(music.name, 'Missão Para Todos');
        expect(music.audioUrl, 'https://api.test/file/custom/audio/xyz.mp3');
        expect(music.lyrics, hasLength(2));
        expect(music.lyrics.first.text, 'Estrofe 1');
        expect(music.lyrics.last.text, 'Estrofe 2');
      },
    );

    test('joinCollection registra e fetchJoinedCollectionIds lê', () async {
      final api = CustomCatalogApiImpl(
        fetch: _FakeNet(const {}).fetch,
        apiBaseUrl: 'https://api.test',
        filesBaseUrl: 'https://api.test/file',
      );

      await api.joinCollection(
        const CustomCollection(id: 2, name: 'Teste', isOwner: false),
      );
      await api.joinCollection(
        const CustomCollection(id: 5, name: 'Outra', isOwner: false),
      );

      final joined = await api.fetchJoinedCollectionIds();
      expect(joined, containsAll(<int>[2, 5]));
    });
  });
}
