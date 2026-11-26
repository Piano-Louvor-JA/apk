import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/youtube/youtube_channels.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_channel.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

YoutubeVideo v(String id, String title) =>
    YoutubeVideo(videoId: id, title: title, channel: 'Casa Publicadora Brasileira');

void main() {
  group('canal padrão da CPB', () {
    test('Novo Hinário Adventista completo, em ordem, unido numa lista só', () {
      expect(defaultYoutubeChannels.map((c) => c.id), ['cpb']);
      expect(cpbChannel.name, 'Casa Publicadora Brasileira');
      expect(cpbChannel.subtitle, 'Novo Hinário Adventista');
      expect(cpbChannel.url, 'https://www.youtube.com/@casapublicadora');
      expect(cpbChannel.youtubeId, 'UCQhkLOO40bmTMeLcbspKW8A');
      expect(cpbChannel.merged, isTrue);
      expect(cpbChannel.playlists.map((p) => p.name), [
        'Novo Hinário Adventista 1 - 100',
        'Novo Hinário Adventista 101 - 200',
        'Novo Hinário Adventista 201 - 300',
        'Novo Hinário Adventista 301 - 400',
        'Novo Hinário Adventista 401 - 500',
        'Novo Hinário Adventista 501 - 600',
      ]);
      // mesmos ids do desktop
      expect(cpbChannel.playlists.first.id, 'PLAPpcKnpMfeO9Fydpl1tTKC9CRRnIMMSK');
      expect(cpbChannel.playlists.last.id, 'PLAPpcKnpMfePWEOuIu4B4F3PVljyD8DoO');
      expect(
        cpbChannel.playlists.first.cover,
        'https://i.ytimg.com/vi/FDpludwY46U/hqdefault.jpg',
      );
      expect(cpbChannel.covers, hasLength(4));
    });
  });

  group('ChannelPlaylistLoader', () {
    test('guarda o resultado, junta pedidos simultâneos e não guarda erro', () async {
      var calls = 0;
      final loader = ChannelPlaylistLoader((id) async {
        calls++;
        if (calls == 1) return const YoutubePlaylistResult(error: 'network');
        return YoutubePlaylistResult(items: [v('AAAAAAAAAAA', 'Hino 1')]);
      });
      expect((await loader.load('PL1')).error, 'network');
      expect(loader.cached('PL1'), isNull);
      final a = loader.load('PL1');
      final b = loader.load('PL1');
      expect((await a).items, hasLength(1));
      expect((await b).items, hasLength(1));
      expect(calls, 2);
      expect(loader.cached('PL1'), hasLength(1));
      await loader.load('PL1');
      expect(calls, 2);
      await loader.load('PL1', force: true);
      expect(calls, 3);
    });

    test('vazia sem erro vira "empty"; exceção vira "network"', () async {
      expect(
        (await ChannelPlaylistLoader((_) async => const YoutubePlaylistResult()).load('PL1')).error,
        'empty',
      );
      expect(
        (await ChannelPlaylistLoader((_) => throw Exception('x')).load('PL1')).error,
        'network',
      );
    });
  });

  group('loadChannelVideos (canal unido)', () {
    final channel = YoutubeChannel(
      id: 'x',
      name: 'X',
      url: '',
      merged: true,
      playlists: const [
        YoutubeChannelPlaylist(id: 'PL1', name: '1'),
        YoutubeChannelPlaylist(id: 'PL2', name: '2'),
        YoutubeChannelPlaylist(id: 'PL3', name: '3'),
      ],
    );

    test('junta as playlists em ordem, sem repetir; vazia não impede as outras', () async {
      final byId = {
        'PL1': [v('AAAAAAAAAAA', 'Hino 1'), v('BBBBBBBBBBB', 'Hino 2')],
        'PL2': <YoutubeVideo>[],
        'PL3': [v('BBBBBBBBBBB', 'Hino 2'), v('CCCCCCCCCCC', 'Hino 201')],
      };
      final loader = ChannelPlaylistLoader((id) async => YoutubePlaylistResult(items: byId[id]!));
      final result = await loadChannelVideos(channel, loader);
      expect(result.error, isNull);
      expect(result.items.map((i) => i.title), ['Hino 1', 'Hino 2', 'Hino 201']);
    });

    test('se uma falha, nada pela metade; a nova tentativa só busca a que faltou', () async {
      var calls = 0;
      final loader = ChannelPlaylistLoader((id) async {
        calls++;
        if (calls == 2) return const YoutubePlaylistResult(error: 'network');
        return YoutubePlaylistResult(items: [v(id.padRight(11, 'x'), id)]);
      });
      final failed = await loadChannelVideos(channel, loader);
      expect(failed.error, 'network');
      expect(failed.items, isEmpty);
      final retry = await loadChannelVideos(channel, loader);
      expect(retry.items, hasLength(3));
      expect(calls, 4);
    });

    test('todas vazias vira "empty"', () async {
      final loader = ChannelPlaylistLoader((_) async => const YoutubePlaylistResult());
      expect((await loadChannelVideos(channel, loader)).error, 'empty');
    });
  });

  group('filterChannelVideos', () {
    final list = [
      v('AAAAAAAAAAA', 'Novo Hinário Adventista • Hino 1  • Santo Santo Santo! • (Lyrics)'),
      v('BBBBBBBBBBB', 'Novo Hinário Adventista • Hino 15 • Castelo Forte • (Lyrics)'),
      v('CCCCCCCCCCC', 'Novo Hinário Adventista • Hino 115 • Olhar • (Lyrics)'),
      v('DDDDDDDDDDD', 'Novo Hinário Adventista • Hino 150 • Graça • (Lyrics)'),
    ];

    test('número acha exatamente o hino com esse número', () {
      expect(filterChannelVideos(list, '15').map((x) => x.videoId), ['BBBBBBBBBBB']);
      expect(filterChannelVideos(list, ' 1 ').map((x) => x.videoId), ['AAAAAAAAAAA']);
      expect(filterChannelVideos(list, '015').map((x) => x.videoId), ['BBBBBBBBBBB']);
      expect(filterChannelVideos(list, '999'), isEmpty);
    });

    test('texto filtra pelo título sem acento; vazio devolve tudo', () {
      expect(filterChannelVideos(list, 'graca').map((x) => x.videoId), ['DDDDDDDDDDD']);
      expect(filterChannelVideos(list, 'CASTELO forte').map((x) => x.videoId), ['BBBBBBBBBBB']);
      expect(filterChannelVideos(list, '  '), list);
    });
  });

  group('canais cadastrados (YoutubeLibraryStorage)', () {
    YoutubeChannelResult result({
      String id = 'UCaaaaaaaaaaaaaaaaaaaaaa',
      String name = 'Arautos do Rei',
      int playlists = 2,
    }) => YoutubeChannelResult(
      channel: YoutubeChannelInfo(
        id: id,
        name: name,
        url: 'https://www.youtube.com/@arautos',
        avatar: 'https://yt3.googleusercontent.com/a',
      ),
      playlists: [
        for (var i = 0; i < playlists; i++)
          YoutubeChannelPlaylistInfo(
            id: 'PLarautos${'$i'.padLeft(6, '0')}',
            title: 'Álbum ${i + 1}',
            thumbnail: 'https://i.ytimg.com/vi/thumb$i/hqdefault.jpg',
            videoCount: 10 + i,
          ),
      ],
    );

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('cadastra depois do padrão, com as playlists, e sobrevive a reabrir (roundtrip)', () async {
      final saved = await YoutubeLibraryStorage(clock: () => 1000).saveChannel(result());
      expect(saved.status, YoutubeChannelSaveStatus.added);
      expect(saved.channel!.userAdded, isTrue);
      expect(saved.channel!.addedAt, 1000);
      expect(saved.list.map((c) => c.id), ['cpb', 'UCaaaaaaaaaaaaaaaaaaaaaa']);

      // outra instância: tudo vem do armazenamento (mesma chave do desktop)
      final reloaded = await YoutubeLibraryStorage().channels();
      expect(reloaded.map((c) => c.id), ['cpb', 'UCaaaaaaaaaaaaaaaaaaaaaa']);
      final c = reloaded[1];
      expect(c.merged, isFalse);
      expect(c.url, 'https://www.youtube.com/@arautos');
      expect(c.avatar, 'https://yt3.googleusercontent.com/a');
      expect(c.playlists.map((p) => p.name), ['Álbum 1', 'Álbum 2']);
      expect(c.playlists.first.cover, 'https://i.ytimg.com/vi/thumb0/hqdefault.jpg');
      expect(c.playlists.first.videoCount, 10);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString(YoutubeLibraryStorage.channelsKey)!), isA<List>());
      expect(YoutubeLibraryStorage.channelsKey, 'louvorja-youtube-channels-v1');
    });

    test('cadastrar de novo atualiza sem duplicar e sem perder a data', () async {
      await YoutubeLibraryStorage(clock: () => 1000).saveChannel(result());
      final again = await YoutubeLibraryStorage(clock: () => 2000).saveChannel(result(name: 'Arautos (novo)', playlists: 3));
      expect(again.status, YoutubeChannelSaveStatus.updated);
      final list = await YoutubeLibraryStorage().channels();
      expect(list.map((c) => c.name), ['Casa Publicadora Brasileira', 'Arautos (novo)']);
      expect(list[1].addedAt, 1000);
      expect(list[1].playlists, hasLength(3));
    });

    test('a CPB já vem no app; sem canal ou sem playlists não cadastra', () async {
      final storage = YoutubeLibraryStorage();
      final cpb = await storage.saveChannel(result(id: 'UCQhkLOO40bmTMeLcbspKW8A'));
      expect(cpb.status, YoutubeChannelSaveStatus.builtIn);
      expect(cpb.channel, same(cpbChannel));
      expect((await storage.saveChannel(const YoutubeChannelResult(error: 'network'))).status, YoutubeChannelSaveStatus.invalid);
      expect((await storage.saveChannel(result(playlists: 0))).status, YoutubeChannelSaveStatus.invalid);
      expect(await storage.channels(), hasLength(1));
    });

    test('exclui o cadastrado; o padrão não sai', () async {
      final storage = YoutubeLibraryStorage();
      await storage.saveChannel(result());
      expect((await storage.removeChannel('UCaaaaaaaaaaaaaaaaaaaaaa')).map((c) => c.id), ['cpb']);
      expect((await storage.removeChannel('cpb')).map((c) => c.id), ['cpb']);
    });

    test('dado salvo inválido é descartado', () async {
      SharedPreferences.setMockInitialValues({
        YoutubeLibraryStorage.channelsKey: jsonEncode([
          {
            'id': 'UCbbbbbbbbbbbbbbbbbbbbbb',
            'name': ' Vox ',
            'avatar': 7,
            'addedAt': 'x',
            'playlists': [
              {'id': 'PLvox000000001', 'name': 'Um', 'thumbnail': 'https://i.ytimg.com/vi/x/hqdefault.jpg', 'videoCount': 3},
              {'id': 'PLvox000000001', 'name': 'Repetida'},
              {'id': 'curto', 'name': 'Inválida'},
              {'id': 'PLvox000000002', 'name': ''},
              'lixo',
            ],
          },
          {'id': 'UCbbbbbbbbbbbbbbbbbbbbbb', 'name': 'Repetido', 'playlists': []},
          {'id': 'nao-e-canal', 'name': 'X'},
          null,
        ]),
      });
      final list = await YoutubeLibraryStorage().channels();
      expect(list.map((c) => c.id), ['cpb', 'UCbbbbbbbbbbbbbbbbbbbbbb']);
      expect(list[1].name, 'Vox');
      expect(list[1].avatar, '');
      expect(list[1].addedAt, 0);
      expect(list[1].url, 'https://www.youtube.com/channel/UCbbbbbbbbbbbbbbbbbbbbbb');
      expect(list[1].playlists.map((p) => p.name), ['Um']);
      SharedPreferences.setMockInitialValues({YoutubeLibraryStorage.channelsKey: '{"x":1}'});
      expect(await YoutubeLibraryStorage().channels(), hasLength(1));
    });
  });
}
