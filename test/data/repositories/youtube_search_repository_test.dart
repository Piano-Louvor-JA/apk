import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/youtube/youtube_search_parser.dart';
import 'package:louvorja_piano_mobile/data/repositories/youtube_search_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

Map<String, dynamic> renderer(String id, String title) => {
  'videoRenderer': {
    'videoId': id,
    'title': {
      'runs': [
        {'text': title},
      ],
    },
    'ownerText': {
      'runs': [
        {'text': 'Arautos do Rei'},
      ],
    },
    'lengthText': {'simpleText': '4:12'},
    'shortViewCountText': {'simpleText': '1,2 mi de visualizações'},
    'publishedTimeText': {'simpleText': 'há 3 anos'},
    'thumbnail': {
      'thumbnails': [
        {'url': 'https://i.ytimg.com/vi/x/default.jpg'},
        {'url': 'https://i.ytimg.com/vi/$id/hq720.jpg?sqp=abc'},
      ],
    },
  },
};

Map<String, dynamic> continuationNode(String token) => {
  'continuationItemRenderer': {
    'continuationEndpoint': {
      'continuationCommand': {'token': token},
    },
  },
};

Map<String, dynamic> lockup(String id, String title) => {
  'lockupViewModel': {
    'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
    'contentId': id,
    'metadata': {
      'lockupMetadataViewModel': {
        'title': {'content': title},
        'metadata': {
          'contentMetadataViewModel': {
            'metadataRows': [
              {
                'metadataParts': [
                  {
                    'text': {'content': 'Adoradores Novo Tempo'},
                  },
                ],
              },
              {
                'metadataParts': [
                  {
                    'text': {'content': '2,1 mi de visualizações'},
                  },
                  {
                    'text': {'content': 'há 3 anos'},
                  },
                ],
              },
            ],
          },
        },
      },
    },
    'contentImage': {
      'thumbnailViewModel': {
        'image': {
          'sources': [
            {'url': 'https://i.ytimg.com/vi/x/small.jpg'},
            {'url': 'https://i.ytimg.com/vi/$id/hq.jpg?sqp=1'},
          ],
        },
        'overlays': [
          {
            'thumbnailOverlayBadgeViewModel': {
              'thumbnailBadges': [
                {
                  'thumbnailBadgeViewModel': {'text': '4:05'},
                },
              ],
            },
          },
        ],
      },
    },
  },
};

String page(Object data) =>
    '<script>var ytInitialData = ${jsonEncode(data)};</script><script>ytcfg.set({"INNERTUBE_API_KEY":"KEY123","INNERTUBE_CLIENT_VERSION":"2.20990101.00.00"});</script>';

class FakeHttp implements YoutubeHttp {
  FakeHttp({this.onGet, this.onPost});
  YoutubeHttpResponse Function(String url)? onGet;
  YoutubeHttpResponse Function(String url, String body)? onPost;
  final gets = <String>[];
  final posts = <({String url, String body})>[];

  @override
  Future<YoutubeHttpResponse> get(String url, Map<String, String> headers) async {
    gets.add(url);
    return onGet!(url);
  }

  @override
  Future<YoutubeHttpResponse> post(
    String url,
    Map<String, String> headers,
    String body,
  ) async {
    posts.add((url: url, body: body));
    return onPost!(url, body);
  }
}

void main() {
  group('YoutubeSearchParser', () {
    test('lê o JSON depois do marcador respeitando strings', () {
      expect(
        YoutubeSearchParser.extractJsonAfter(r'x = {"a":"}{\""};', 'x = '),
        {'a': '}{"'},
      );
      expect(YoutubeSearchParser.extractJsonAfter('nada', 'x = '), isNull);
      expect(
        YoutubeSearchParser.extractJsonAfter('x = sem objeto', 'x = '),
        isNull,
      );
      expect(
        YoutubeSearchParser.extractJsonAfter('x = {"a": quebrado}', 'x = '),
        isNull,
      );
      expect(
        YoutubeSearchParser.extractJsonAfter('x = {"a": "sem fim', 'x = '),
        isNull,
      );
    });

    test('converte o videoRenderer; sem id válido ou título não entra', () {
      final r = renderer('AAAAAAAAAAA', ' Hino ')['videoRenderer'];
      expect(
        YoutubeSearchParser.videoFromRenderer(r),
        const YoutubeVideo(
          videoId: 'AAAAAAAAAAA',
          title: 'Hino',
          channel: 'Arautos do Rei',
          durationText: '4:12',
          viewsText: '1,2 mi de visualizações',
          publishedText: 'há 3 anos',
          thumbnail: 'https://i.ytimg.com/vi/AAAAAAAAAAA/hq720.jpg',
        ),
      );
      expect(
        YoutubeSearchParser.videoFromRenderer({
          'videoId': 'curto',
          'title': {'simpleText': 'x'},
        }),
        isNull,
      );
      expect(
        YoutubeSearchParser.videoFromRenderer({'videoId': 'AAAAAAAAAAA'}),
        isNull,
      );
      final live = YoutubeSearchParser.videoFromRenderer({
        'videoId': 'CCCCCCCCCCC',
        'title': {'simpleText': 'Culto ao vivo'},
        'longBylineText': {
          'runs': [
            {'text': 'Igreja'},
          ],
        },
        'badges': [
          {
            'metadataBadgeRenderer': {'style': 'BADGE_STYLE_TYPE_LIVE_NOW'},
          },
        ],
      })!;
      expect(live.channel, 'Igreja');
      expect(live.durationText, '');
      expect(live.live, isTrue);
      expect(live.thumbnail, 'https://i.ytimg.com/vi/CCCCCCCCCCC/hqdefault.jpg');
    });

    test('formato novo (lockupViewModel)', () {
      expect(
        YoutubeSearchParser.videoFromLockup(
          lockup('ax-25gXlmBk', ' Meu Pastor ')['lockupViewModel'],
        ),
        const YoutubeVideo(
          videoId: 'ax-25gXlmBk',
          title: 'Meu Pastor',
          channel: 'Adoradores Novo Tempo',
          durationText: '4:05',
          viewsText: '2,1 mi de visualizações',
          publishedText: 'há 3 anos',
          thumbnail: 'https://i.ytimg.com/vi/ax-25gXlmBk/hq.jpg',
        ),
      );
      expect(
        YoutubeSearchParser.videoFromLockup({
          'contentType': 'LOCKUP_CONTENT_TYPE_PLAYLIST',
          'contentId': 'PLx',
        }),
        isNull,
      );
      expect(
        YoutubeSearchParser.videoFromLockup({
          'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
          'contentId': 'curto',
        }),
        isNull,
      );
      final bare = YoutubeSearchParser.videoFromLockup({
        'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
        'contentId': 'AAAAAAAAAAA',
        'metadata': {
          'lockupMetadataViewModel': {
            'title': {'content': 'Só título'},
          },
        },
      })!;
      expect(bare.channel, '');
      expect(bare.durationText, '');
      expect(bare.thumbnail, 'https://i.ytimg.com/vi/AAAAAAAAAAA/hqdefault.jpg');
    });

    test('junta os vídeos em ordem, sem repetir, e acha a continuação', () {
      final found = YoutubeSearchParser.collect({
        'a': [
          renderer('AAAAAAAAAAA', 'Um'),
          renderer('AAAAAAAAAAA', 'Repetido'),
          lockup('BBBBBBBBBBB', 'Dois'),
        ],
        'b': continuationNode('T'),
      });
      expect(found.items.map((i) => i.title), ['Um', 'Dois']);
      expect(found.token, 'T');
      final empty = YoutubeSearchParser.collect(null);
      expect(empty.items, isEmpty);
      expect(empty.token, isNull);
    });

    test('reconhece o id da playlist no link ou colado direto', () {
      String? id(String t) => YoutubeSearchParser.playlistIdFromText(t);
      expect(
        id('https://www.youtube.com/playlist?list=PLabcdefghij1234'),
        'PLabcdefghij1234',
      );
      expect(
        id('youtube.com/watch?v=AAAAAAAAAAA&list=PLabcdefghij1234&index=2'),
        'PLabcdefghij1234',
      );
      expect(
        id('https://music.youtube.com/playlist?list=OLAK5uy_abcdefghijk'),
        'OLAK5uy_abcdefghijk',
      );
      expect(id('PLabcdefghij1234'), 'PLabcdefghij1234');
      expect(id('https://www.youtube.com/watch?v=AAAAAAAAAAA'), isNull);
      expect(
        id(
          'https://www.youtube.com/watch?v=ax-25gXlmBk&list=PLyTP3IYISkzAKBIqgfseYGmhBwZxd0h2V',
        ),
        'PLyTP3IYISkzAKBIqgfseYGmhBwZxd0h2V',
      );
      expect(
        id(
          'olha: https://youtu.be/ax-25gXlmBk?si=x&list=PLyTP3IYISkzAKBIqgfseYGmhBwZxd0h2V&t=3',
        ),
        'PLyTP3IYISkzAKBIqgfseYGmhBwZxd0h2V',
      );
      expect(id('https://www.youtube.com/watch?v=ax-25gXlmBk&list=curto'), isNull);
      expect(id(''), isNull);
    });
  });

  group('YoutubeSearchRepositoryImpl', () {
    final initialData = {
      'contents': {
        'sectionListRenderer': {
          'contents': [
            {
              'itemSectionRenderer': {
                'contents': [
                  renderer('AAAAAAAAAAA', 'Arautos do Rei - Hino 1'),
                  {'adSlotRenderer': {}},
                  renderer('BBBBBBBBBBB', 'Vox - Hino 2'),
                ],
              },
            },
            continuationNode('TOKEN-1'),
          ],
        },
      },
    };

    test('busca: URL só de vídeos, itens e continuação', () async {
      final http = FakeHttp(onGet: (_) => (status: 200, body: page(initialData)));
      final result = await YoutubeSearchRepositoryImpl(
        http: http,
      ).search('  arautos do rei  ');
      expect(http.gets.single, contains('search_query=arautos%20do%20rei'));
      expect(http.gets.single, contains('sp=EgIQAQ%253D%253D'));
      expect(result.items.map((i) => i.videoId), ['AAAAAAAAAAA', 'BBBBBBBBBBB']);
      expect(
        result.continuation,
        const YoutubeContinuation(
          token: 'TOKEN-1',
          apiKey: 'KEY123',
          clientVersion: '2.20990101.00.00',
        ),
      );
    });

    test('busca: vazio, HTTP ruim, sem dados e rede caída não lançam', () async {
      final http = FakeHttp(onGet: (_) => throw StateError('não devia buscar'));
      expect(
        (await YoutubeSearchRepositoryImpl(http: http).search('   ')).items,
        isEmpty,
      );
      expect(http.gets, isEmpty);
      Future<String?> errorFor(YoutubeHttpResponse Function(String) onGet) async =>
          (await YoutubeSearchRepositoryImpl(
            http: FakeHttp(onGet: onGet),
          ).search('x')).error;
      expect(await errorFor((_) => (status: 429, body: '')), 'http-429');
      expect(
        await errorFor((_) => (status: 200, body: '<html></html>')),
        'parse',
      );
      expect(await errorFor((_) => throw StateError('offline')), 'network');
      final noToken = await YoutubeSearchRepositoryImpl(
        http: FakeHttp(
          onGet: (_) => (
            status: 200,
            body: '<script>ytInitialData = {"a":[]};</script>',
          ),
        ),
      ).search('x');
      expect(noToken.items, isEmpty);
      expect(noToken.continuation, isNull);
      expect(noToken.error, isNull);
    });

    test('carregar mais: POST com o token e a próxima continuação', () async {
      final http = FakeHttp(
        onPost: (_, _) => (
          status: 200,
          body: jsonEncode({
            'onResponseReceivedCommands': [
              {
                'appendContinuationItemsAction': {
                  'continuationItems': [
                    renderer('DDDDDDDDDDD', 'Três'),
                    continuationNode('TOKEN-2'),
                  ],
                },
              },
            ],
          }),
        ),
      );
      final result = await YoutubeSearchRepositoryImpl(http: http).more(
        const YoutubeContinuation(
          token: 'TOKEN-1',
          apiKey: 'KEY123',
          clientVersion: '2.1',
        ),
      );
      expect(http.posts.single.url, contains('key=KEY123'));
      final body = jsonDecode(http.posts.single.body) as Map;
      expect(body['continuation'], 'TOKEN-1');
      expect(body['context']['client']['clientVersion'], '2.1');
      expect(result.items.map((i) => i.videoId), ['DDDDDDDDDDD']);
      expect(result.continuation!.token, 'TOKEN-2');
    });

    test('carregar mais: sem chave, HTTP ruim e rede caída', () async {
      final http = FakeHttp(onPost: (_, _) => (status: 200, body: '{}'));
      final repo = YoutubeSearchRepositoryImpl(http: http);
      final none = await repo.more(
        const YoutubeContinuation(token: 'T', clientVersion: ''),
      );
      expect(none.items, isEmpty);
      expect(none.continuation, isNull);
      expect(http.posts.single.url, isNot(contains('key=')));
      expect(
        (await repo.more(const YoutubeContinuation(token: '', clientVersion: '')))
            .items,
        isEmpty,
      );
      expect(
        (await YoutubeSearchRepositoryImpl(
          http: FakeHttp(onPost: (_, _) => (status: 500, body: '')),
        ).more(const YoutubeContinuation(token: 'T', clientVersion: '1'))).error,
        'http-500',
      );
      expect(
        (await YoutubeSearchRepositoryImpl(
          http: FakeHttp(onPost: (_, _) => throw StateError('x')),
        ).more(const YoutubeContinuation(token: 'T', clientVersion: '1'))).error,
        'network',
      );
    });

    test('playlist: lê as páginas até acabar, sem repetir', () async {
      final data = {
        'metadata': {
          'playlistMetadataRenderer': {'title': 'Adoradores 4'},
        },
        'contents': [
          lockup('ax-25gXlmBk', 'Meu Pastor'),
          {
            'lockupViewModel': {
              'contentType': 'LOCKUP_CONTENT_TYPE_PLAYLIST',
              'contentId': 'PLz',
            },
          },
          lockup('BBBBBBBBBBB', 'Dois'),
          continuationNode('PL-T1'),
        ],
      };
      var pages = 0;
      final http = FakeHttp(
        onGet: (_) => (status: 200, body: page(data)),
        onPost: (_, _) {
          pages++;
          return (
            status: 200,
            body: jsonEncode({
              'items': pages == 1
                  ? [
                      lockup('BBBBBBBBBBB', 'Dois'),
                      lockup('CCCCCCCCCCC', 'Três'),
                      continuationNode('PL-T2'),
                    ]
                  : [lockup('CCCCCCCCCCC', 'Três'), continuationNode('PL-T3')],
            }),
          );
        },
      );
      final result = await YoutubeSearchRepositoryImpl(http: http).playlist(
        'https://www.youtube.com/watch?v=ax-25gXlmBk&list=PLyTP3IYISkzAKBIqgfseYGmhBwZxd0h2V',
      );
      expect(http.gets.single, contains('list=PLyTP3IYISkzAKBIqgfseYGmhBwZxd0h2V'));
      expect(result.title, 'Adoradores 4');
      expect(result.items.map((i) => i.videoId), [
        'ax-25gXlmBk',
        'BBBBBBBBBBB',
        'CCCCCCCCCCC',
      ]);
      // Segunda página sem vídeo novo: para.
      expect(http.posts, hasLength(2));
    });

    test('playlist: inválida, vazia, HTTP ruim e rede caída', () async {
      expect(
        (await YoutubeSearchRepositoryImpl(
          http: FakeHttp(),
        ).playlist('https://www.youtube.com/watch?v=AAAAAAAAAAA')).error,
        'invalid',
      );
      Future<String?> errorFor(YoutubeHttpResponse Function(String) onGet) async =>
          (await YoutubeSearchRepositoryImpl(
            http: FakeHttp(onGet: onGet),
          ).playlist('PLabcdefghij1234')).error;
      expect(
        await errorFor(
          (_) => (
            status: 200,
            body: page({
              'metadata': {
                'playlistMetadataRenderer': {'title': 'Vazia'},
              },
            }),
          ),
        ),
        'empty',
      );
      expect(await errorFor((_) => (status: 404, body: '')), 'http-404');
      expect(await errorFor((_) => (status: 200, body: 'x')), 'parse');
      expect(await errorFor((_) => throw StateError('x')), 'network');
    });
  });
}
