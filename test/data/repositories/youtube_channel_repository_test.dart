import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/youtube/youtube_channel_parser.dart';
import 'package:louvorja_piano_mobile/data/repositories/youtube_search_repository_impl.dart';

import 'youtube_search_repository_test.dart' show FakeHttp;

/// Playlist no formato novo do YouTube (2025+), como vem na aba "Playlists" do canal.
Map<String, dynamic> lockup(String id, String title, [String count = '31 vídeos']) => {
  'lockupViewModel': {
    'contentType': 'LOCKUP_CONTENT_TYPE_PLAYLIST',
    'contentId': id,
    'contentImage': {
      'collectionThumbnailViewModel': {
        'primaryThumbnail': {
          'thumbnailViewModel': {
            'image': {
              'sources': [
                {'url': 'https://i.ytimg.com/vi/cover000001/hqdefault.jpg?sqp=-oay&rs=AOn'},
              ],
            },
            'overlays': [
              {
                'thumbnailOverlayBadgeViewModel': {
                  'thumbnailBadges': [
                    {
                      'thumbnailBadgeViewModel': {'text': count},
                    },
                  ],
                },
              },
            ],
          },
        },
      },
    },
    'metadata': {
      'lockupMetadataViewModel': {
        'title': {'content': title},
      },
    },
  },
};

Map<String, dynamic> grid(String id, String title) => {
  'gridPlaylistRenderer': {
    'playlistId': id,
    'title': {
      'runs': [
        {'text': title},
      ],
    },
    'videoCountText': {
      'runs': [
        {'text': '12'},
        {'text': ' vídeos'},
      ],
    },
    'thumbnail': {
      'thumbnails': [
        {'url': 'https://i.ytimg.com/vi/x/default.jpg'},
        {'url': 'https://i.ytimg.com/vi/GGGGGGGGGGG/hqdefault.jpg?x=1'},
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

const metadata = {
  'channelMetadataRenderer': {
    'title': 'Casa Publicadora Brasileira',
    'externalId': 'UCQhkLOO40bmTMeLcbspKW8A',
    'vanityChannelUrl': 'http://www.youtube.com/@casapublicadora',
    'avatar': {
      'thumbnails': [
        {'url': 'https://yt3.googleusercontent.com/avatar=s900'},
      ],
    },
  },
};

/// Canal no resultado da busca (`channelRenderer`): o YouTube manda o @handle em
/// `subscriberCountText` e os inscritos em `videoCountText`.
Map<String, dynamic> channelRenderer(
  String id,
  String name, {
  String handle = '@canal',
  String subscribers = '14 mil inscritos',
}) => {
  'channelRenderer': {
    'channelId': id,
    'title': {'simpleText': name},
    'thumbnail': {
      'thumbnails': [
        {'url': '//yt3.ggpht.com/a=s88-c'},
        {'url': '//yt3.ggpht.com/a=s176-c'},
      ],
    },
    'descriptionSnippet': {
      'runs': [
        {'text': 'Louvor ', 'bold': true},
        {'text': 'adventista para a família.'},
      ],
    },
    'subscriberCountText': {'simpleText': handle},
    'videoCountText': {'simpleText': subscribers},
  },
};

String page(Map<String, dynamic> data) =>
    '<script>var ytInitialData = ${jsonEncode(data)};</script>"INNERTUBE_API_KEY":"K","INNERTUBE_CLIENT_VERSION":"2.1"';

YoutubeHttpResponse ok(String body) => (status: 200, body: body);

void main() {
  group('YoutubeChannelParser.channelPath', () {
    test('aceita @handle (com acento), link do canal, /channel/UC…, /c/ e /user/', () {
      const p = YoutubeChannelParser.channelPath;
      expect(p('@casapublicadora'), '@casapublicadora');
      expect(p(' https://www.youtube.com/@casapublicadora/videos?x=1 '), '@casapublicadora');
      expect(p('m.youtube.com/@Arautos.do-Rei_1/playlists'), '@Arautos.do-Rei_1');
      expect(p('@HinárioAntigoAdventista'), '@HinárioAntigoAdventista');
      expect(p('https://www.youtube.com/@S%C3%B3Louvor-z2o'), '@SóLouvor-z2o');
      expect(p('https://www.youtube.com/channel/UCQhkLOO40bmTMeLcbspKW8A/featured'), 'channel/UCQhkLOO40bmTMeLcbspKW8A');
      expect(p('UCQhkLOO40bmTMeLcbspKW8A'), 'channel/UCQhkLOO40bmTMeLcbspKW8A');
      expect(p('https://youtube.com/c/NovoTempo'), 'c/NovoTempo');
      expect(p('https://youtube.com/user/voxmusic'), 'user/voxmusic');
    });

    test('recusa vídeo, playlist, outro site e texto qualquer', () {
      const p = YoutubeChannelParser.channelPath;
      expect(p('https://www.youtube.com/watch?v=AAAAAAAAAAA'), isNull);
      expect(p('https://www.youtube.com/playlist?list=PLabcdefghij1234'), isNull);
      expect(p('https://example.com/@casapublicadora'), isNull);
      expect(p('casa publicadora'), isNull);
      expect(p('@'), isNull);
      expect(p(''), isNull);
    });
  });

  group('links colados', () {
    test('isChannelLink', () {
      expect(YoutubeChannelParser.isChannelLink('https://www.youtube.com/@casapublicadora'), isTrue);
      expect(YoutubeChannelParser.isChannelLink('@casapublicadora'), isTrue);
      expect(YoutubeChannelParser.isChannelLink('UCQhkLOO40bmTMeLcbspKW8A'), isTrue);
      expect(YoutubeChannelParser.isChannelLink('casa publicadora'), isFalse);
      expect(YoutubeChannelParser.isChannelLink('https://www.youtube.com/watch?v=AAAAAAAAAAA'), isFalse);
    });

    test('isPlaylistLink', () {
      expect(YoutubeChannelParser.isPlaylistLink('https://www.youtube.com/playlist?list=PLVk-tYq6iIlM'), isTrue);
      expect(YoutubeChannelParser.isPlaylistLink(' PLVk-tYq6iIlM '), isTrue);
      expect(YoutubeChannelParser.isPlaylistLink('https://www.youtube.com/watch?v=AAAAAAAAAAA'), isFalse);
      expect(YoutubeChannelParser.isPlaylistLink('hinos de natal'), isFalse);
    });
  });

  group('playlists do canal', () {
    test('formato novo: id, título, capa sem parâmetros e número de vídeos', () {
      final p = YoutubeChannelParser.playlistFromLockup(
        lockup('PLAPpcKnpMfeO9Fydpl1tTKC9CRRnIMMSK', ' Novo Hinário 1-100 ', '1.234 vídeos')['lockupViewModel'],
      )!;
      expect(p.id, 'PLAPpcKnpMfeO9Fydpl1tTKC9CRRnIMMSK');
      expect(p.title, 'Novo Hinário 1-100');
      expect(p.thumbnail, 'https://i.ytimg.com/vi/cover000001/hqdefault.jpg');
      expect(p.videoCount, 1234);
      expect(YoutubeChannelParser.playlistFromLockup({'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO', 'contentId': 'AAAAAAAAAAA'}), isNull);
    });

    test('junta os dois formatos, sem repetir, e pega o token', () {
      final found = YoutubeChannelParser.collectPlaylists({
        'a': [lockup('PLaaaaaaaaaa01', 'Um'), grid('PLbbbbbbbbbb02', 'Dois'), lockup('PLaaaaaaaaaa01', 'De novo'), continuationNode('T1')],
      });
      expect(found.items.map((p) => p.title), ['Um', 'Dois']);
      expect(found.items[1].thumbnail, 'https://i.ytimg.com/vi/GGGGGGGGGGG/hqdefault.jpg');
      expect(found.items[1].videoCount, 12);
      expect(found.token, 'T1');
    });
  });

  group('YoutubeSearchRepositoryImpl.channel', () {
    final pageData = {
      'metadata': metadata,
      'contents': [lockup('PLaaaaaaaaaa01', 'Hinário 1-100'), lockup('PLaaaaaaaaaa02', 'Hinário 101-200'), continuationNode('CH-T1')],
    };

    test('lê o canal pela aba Playlists e as próximas páginas, sem repetir', () async {
      var posts = 0;
      final http = FakeHttp(
        onGet: (_) => ok(page(pageData)),
        onPost: (url, body) {
          posts++;
          return ok(jsonEncode(posts == 1
              ? {'x': [lockup('PLaaaaaaaaaa02', 'Hinário 101-200'), lockup('PLaaaaaaaaaa03', 'Hinário 201-300'), continuationNode('CH-T2')]}
              : {'x': [lockup('PLaaaaaaaaaa03', 'Hinário 201-300')]}));
        },
      );
      final result = await YoutubeSearchRepositoryImpl(http: http).channel('https://www.youtube.com/@casapublicadora/videos');
      expect(http.gets.single, 'https://www.youtube.com/@casapublicadora/playlists?hl=pt-BR');
      expect(http.posts.first.url, contains('/youtubei/v1/browse'));
      expect(http.posts.first.url, contains('key=K'));
      expect(jsonDecode(http.posts.first.body)['continuation'], 'CH-T1');
      expect(result.error, isNull);
      expect(result.channel!.id, 'UCQhkLOO40bmTMeLcbspKW8A');
      expect(result.channel!.name, 'Casa Publicadora Brasileira');
      expect(result.channel!.url, 'https://www.youtube.com/@casapublicadora');
      expect(result.channel!.avatar, 'https://yt3.googleusercontent.com/avatar=s900');
      expect(result.playlists.map((p) => p.title), ['Hinário 1-100', 'Hinário 101-200', 'Hinário 201-300']);
    });

    test('handle com acento vai codificado na URL; sem link curto usa /channel/UC…', () async {
      final http = FakeHttp(onGet: (_) => (status: 404, body: ''));
      await YoutubeSearchRepositoryImpl(http: http).channel('@SóLouvor-z2o');
      expect(http.gets.single, 'https://www.youtube.com/@S%C3%B3Louvor-z2o/playlists?hl=pt-BR');

      final data = {
        'metadata': {
          'channelMetadataRenderer': {'title': 'Arautos', 'externalId': 'UCxxxxxxxxxxxxxxxxxxxxxx'},
        },
        'c': [lockup('PLaaaaaaaaaa01', 'Um')],
      };
      final result = await YoutubeSearchRepositoryImpl(http: FakeHttp(onGet: (_) => ok(page(data)))).channel('UCxxxxxxxxxxxxxxxxxxxxxx');
      expect(result.channel!.url, 'https://www.youtube.com/channel/UCxxxxxxxxxxxxxxxxxxxxxx');
      expect(result.channel!.avatar, '');
    });

    test('para em ${YoutubeSearchRepositoryImpl.channelMaxPlaylists} playlists', () async {
      final many = [
        for (var i = 0; i < YoutubeSearchRepositoryImpl.channelMaxPlaylists + 5; i++)
          lockup('PLmany${'$i'.padLeft(8, '0')}', 'P$i'),
      ];
      final result = await YoutubeSearchRepositoryImpl(
        http: FakeHttp(onGet: (_) => ok(page({'metadata': metadata, 'c': many}))),
      ).channel('@canal');
      expect(result.playlists, hasLength(YoutubeSearchRepositoryImpl.channelMaxPlaylists));
    });

    test('inválido, HTTP ruim, sem dados, sem playlists, rede caída e página seguinte falhando', () async {
      Future<String?> err(String text, YoutubeHttpResponse Function(String) get) async =>
          (await YoutubeSearchRepositoryImpl(http: FakeHttp(onGet: get)).channel(text)).error;
      expect(await err('https://www.youtube.com/watch?v=AAAAAAAAAAA', (_) => ok('')), 'invalid');
      expect(await err('@canal', (_) => (status: 404, body: '')), 'http-404');
      expect(await err('@canal', (_) => ok('<html>')), 'parse');
      expect(await err('@canal', (_) => ok(page({'c': [lockup('PLaaaaaaaaaa01', 'Um')]}))), 'parse');
      final empty = await YoutubeSearchRepositoryImpl(http: FakeHttp(onGet: (_) => ok(page({'metadata': metadata})))).channel('@canal');
      expect(empty.error, 'empty');
      expect(empty.channel!.name, 'Casa Publicadora Brasileira');
      expect(await err('@canal', (_) => throw Exception('x')), 'network');
      final partial = await YoutubeSearchRepositoryImpl(
        http: FakeHttp(onGet: (_) => ok(page(pageData)), onPost: (_, _) => (status: 500, body: '')),
      ).channel('@canal');
      expect(partial.playlists, hasLength(2));
    });
  });

  group('pesquisa de canais adventistas', () {
    test('o tema sempre puxa para canais adventistas (sem repetir a palavra)', () {
      const q = YoutubeChannelParser.adventistQuery;
      expect(q('louvor'), 'louvor adventista');
      expect(q('  hinos   de   natal '), 'hinos de natal adventista');
      expect(q('Igreja Adventista Central'), 'Igreja Adventista Central');
      expect(q('ADVENTISTAS jovens'), 'ADVENTISTAS jovens');
      expect(q('   '), '');
      expect(q('x' * 500), hasLength(200));
    });

    test('lê o canal do resultado (os campos trocados do YouTube)', () {
      final c = YoutubeChannelParser.channelFromRenderer(
        channelRenderer('UCaaaaaaaaaaaaaaaaaaaaaa', ' Vitrola Adventista ', handle: '@vitrolAdventista', subscribers: '12,1 mil inscritos')['channelRenderer'],
      )!;
      expect(c.id, 'UCaaaaaaaaaaaaaaaaaaaaaa');
      expect(c.name, 'Vitrola Adventista');
      expect(c.handle, '@vitrolAdventista');
      expect(c.subscribers, '12,1 mil inscritos');
      expect(c.avatar, 'https://yt3.ggpht.com/a=s176-c');
      expect(c.description, 'Louvor adventista para a família.');
      expect(c.url, 'https://www.youtube.com/channel/UCaaaaaaaaaaaaaaaaaaaaaa');
      expect(YoutubeChannelParser.channelFromRenderer({'channelId': 'nao', 'title': {'simpleText': 'X'}}), isNull);
    });

    test('busca com filtro de canais e devolve sem repetir; erros', () async {
      final data = {
        'contents': [
          channelRenderer('UCaaaaaaaaaaaaaaaaaaaaaa', 'Louvor Adventista'),
          channelRenderer('UCbbbbbbbbbbbbbbbbbbbbbb', 'Hinário Adventista'),
          channelRenderer('UCaaaaaaaaaaaaaaaaaaaaaa', 'Louvor Adventista'),
        ],
      };
      final http = FakeHttp(onGet: (_) => ok(page(data)));
      final result = await YoutubeSearchRepositoryImpl(http: http).searchChannels(' louvor ');
      expect(http.gets.single, contains('search_query=louvor%20adventista'));
      expect(http.gets.single, contains('sp=EgIQAg%253D%253D'));
      expect(result.error, isNull);
      expect(result.items.map((c) => c.name), ['Louvor Adventista', 'Hinário Adventista']);

      Future<String?> err(YoutubeHttpResponse Function(String) get) async =>
          (await YoutubeSearchRepositoryImpl(http: FakeHttp(onGet: get)).searchChannels('louvor')).error;
      expect(await err((_) => (status: 429, body: '')), 'http-429');
      expect(await err((_) => ok('<html>')), 'parse');
      expect(await err((_) => ok(page({'contents': []}))), 'empty');
      expect(await err((_) => throw Exception('x')), 'network');
      final idle = FakeHttp(onGet: (_) => ok(''));
      expect((await YoutubeSearchRepositoryImpl(http: idle).searchChannels('  ')).items, isEmpty);
      expect(idle.gets, isEmpty);
    });
  });
}
