import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_channel.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/domain/repositories/youtube_search_repository.dart';
import 'package:louvorja_piano_mobile/presentation/youtube/bloc/youtube_cubit.dart';

YoutubeVideo video(int i) => YoutubeVideo(
  videoId: 'V${i.toString().padLeft(10, '0')}',
  title: 'Hino $i',
);

/// Páginas de 20 vídeos; a quinta não tem continuação.
class PagedSearch implements YoutubeSearchRepository {
  int moreCalls = 0;
  String? error;
  final queries = <String>[];

  @override
  Future<YoutubeSearchResult> search(String query) async {
    queries.add(query);
    if (error != null) return YoutubeSearchResult(error: error);
    return YoutubeSearchResult(
      items: [for (var i = 0; i < 20; i++) video(i)],
      continuation: const YoutubeContinuation(token: 'p1', clientVersion: '1'),
    );
  }

  @override
  Future<YoutubeSearchResult> more(YoutubeContinuation continuation) async {
    moreCalls++;
    final page = int.parse(continuation.token.substring(1));
    return YoutubeSearchResult(
      items: [for (var i = page * 20; i < page * 20 + 20; i++) video(i)],
      continuation: page < 4
          ? YoutubeContinuation(token: 'p${page + 1}', clientVersion: '1')
          : null,
    );
  }

  @override
  Future<YoutubePlaylistResult> playlist(String text) async {
    playlistCalls.add(text);
    return YoutubePlaylistResult(title: 'Natal', items: [video(1), video(2)]);
  }

  final playlistCalls = <String>[];
  final channelCalls = <String>[];
  YoutubeChannelResult Function(String text) onChannel = (_) =>
      const YoutubeChannelResult(error: 'invalid');
  Future<YoutubeChannelSearchResult> Function(String query) onSearchChannels =
      (_) async => const YoutubeChannelSearchResult(error: 'empty');

  @override
  Future<YoutubeChannelResult> channel(String text) async {
    channelCalls.add(text);
    return onChannel(text);
  }

  @override
  Future<YoutubeChannelSearchResult> searchChannels(String query) =>
      onSearchChannels(query);
}

YoutubeChannelResult arautos({String name = 'Arautos do Rei', int playlists = 2}) =>
    YoutubeChannelResult(
      channel: YoutubeChannelInfo(
        id: 'UCaaaaaaaaaaaaaaaaaaaaaa',
        name: name,
        url: 'https://www.youtube.com/@arautos',
      ),
      playlists: [
        for (var i = 0; i < playlists; i++)
          YoutubeChannelPlaylistInfo(id: 'PLarautos00000$i', title: 'Álbum $i'),
      ],
    );

void main() {
  late PagedSearch search;
  late YoutubeCubit cubit;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    search = PagedSearch();
    cubit = YoutubeCubit(search: search, storage: YoutubeLibraryStorage());
  });
  tearDown(() => cubit.close());

  test('a busca já traz 60 vídeos e guarda a busca recente', () async {
    await cubit.search('  arautos do rei ');
    expect(search.queries.single, 'arautos do rei');
    expect(cubit.state.results, hasLength(60));
    expect(cubit.state.continuation, isNotNull);
    expect(cubit.state.recentQueries, ['arautos do rei']);
    expect(cubit.state.searching, isFalse);
  });

  test('rolagem infinita carrega até acabar', () async {
    await cubit.search('x');
    await cubit.loadMore();
    await cubit.loadMore();
    expect(cubit.state.results, hasLength(100));
    expect(cubit.state.continuation, isNull);
    final calls = search.moreCalls;
    await cubit.loadMore();
    expect(search.moreCalls, calls);
  });

  test('erro sem resultados mostra o aviso; limpar volta ao início', () async {
    search.error = 'network';
    await cubit.search('x');
    expect(cubit.state.searchError, isTrue);
    cubit.clearSearch();
    expect(cubit.state.searched, isFalse);
    expect(cubit.state.results, isEmpty);
  });

  test('histórico, favoritos e coletâneas atualizam o estado', () async {
    await cubit.load();
    await cubit.recordPlay(video(1));
    await cubit.toggleFavorite(video(1));
    expect(cubit.state.history.single.videoId, video(1).videoId);
    expect(cubit.state.isFavorite(video(1).videoId), isTrue);
    final created = await cubit.createCollection('Culto');
    await cubit.addToCollection(created!.id, video(3));
    expect(
      cubit.state.collection(created.id)!.videos.single.videoId,
      video(3).videoId,
    );
    final fromPlaylist = await cubit.createFromPlaylist(
      'Natal',
      (await cubit.fetchPlaylist('PLabcdefghij1234')).items,
    );
    expect(fromPlaylist!.videos, hasLength(2));
    await cubit.deleteCollection(created.id);
    expect(cubit.state.collections.single.name, 'Natal');
    await cubit.clearHistory();
    expect(cubit.state.history, isEmpty);
  });

  group('canais', () {
    test('load traz o canal padrão da CPB', () async {
      await cubit.load();
      expect(cubit.state.channels.map((c) => c.id), ['cpb']);
    });

    test('cadastrar: lê o canal, salva e atualiza a lista; erro não cadastra', () async {
      await cubit.load();
      final failed = await cubit.addChannel('nada');
      expect(failed.status, YoutubeChannelSaveStatus.invalid);
      expect(failed.error, 'invalid');
      expect(cubit.state.channels, hasLength(1));

      search.onChannel = (_) => arautos();
      final added = await cubit.addChannel(' @arautos ');
      expect(search.channelCalls.last, '@arautos');
      expect(added.status, YoutubeChannelSaveStatus.added);
      expect(added.channel!.name, 'Arautos do Rei');
      expect(cubit.state.channels.map((c) => c.id), ['cpb', 'UCaaaaaaaaaaaaaaaaaaaaaa']);
      // salvo de verdade
      expect(await YoutubeLibraryStorage().channels(), hasLength(2));

      await cubit.removeChannel('UCaaaaaaaaaaaaaaaaaaaaaa');
      expect(cubit.state.channels, hasLength(1));
    });

    test('texto vazio não vai à rede', () async {
      final result = await cubit.addChannel('   ');
      expect(result.status, YoutubeChannelSaveStatus.invalid);
      expect(search.channelCalls, isEmpty);
    });

    test('ao abrir, relê o canal cadastrado e atualiza; falha ou outro canal mantém', () async {
      search.onChannel = (_) => arautos();
      final added = (await cubit.addChannel('@arautos')).channel!;
      search.onChannel = (_) => arautos(name: 'Arautos (novo)', playlists: 3);
      await cubit.refreshChannel(added);
      expect(search.channelCalls.last, 'https://www.youtube.com/@arautos');
      expect(cubit.state.channels[1].playlists, hasLength(3));

      search.onChannel = (_) => const YoutubeChannelResult(error: 'network');
      await cubit.refreshChannel(cubit.state.channels[1]);
      expect(cubit.state.channels[1].playlists, hasLength(3));
    });

    test('pesquisa de canais: resultado, vazio, erro, fechar e resposta atrasada', () async {
      const item = YoutubeChannelSearchItem(id: 'UCaaaaaaaaaaaaaaaaaaaaaa', name: 'Louvor', url: 'u');
      search.onSearchChannels = (_) async => const YoutubeChannelSearchResult(items: [item]);
      await cubit.searchChannels(' louvor ');
      expect(cubit.state.channelQuery, 'louvor');
      expect(cubit.state.channelResults.single.name, 'Louvor');
      expect(cubit.state.channelSearching, isFalse);
      expect(cubit.state.channelSearchError, isNull);

      search.onSearchChannels = (_) async => const YoutubeChannelSearchResult(error: 'empty');
      await cubit.searchChannels('xyz');
      expect(cubit.state.channelSearchError, 'empty');
      search.onSearchChannels = (_) async => const YoutubeChannelSearchResult(error: 'network');
      await cubit.searchChannels('xyz');
      expect(cubit.state.channelSearchError, 'network');

      cubit.clearChannelSearch();
      expect(cubit.state.channelQuery, '');
      expect(cubit.state.channelResults, isEmpty);

      // a resposta da pesquisa anterior não sobrescreve a nova
      final slow = Completer<YoutubeChannelSearchResult>();
      search.onSearchChannels = (_) => slow.future;
      final first = cubit.searchChannels('louvor');
      expect(cubit.state.channelSearching, isTrue);
      search.onSearchChannels = (_) async => const YoutubeChannelSearchResult(items: [item]);
      await cubit.searchChannels('jovens');
      slow.complete(const YoutubeChannelSearchResult(error: 'network'));
      await first;
      expect(cubit.state.channelQuery, 'jovens');
      expect(cubit.state.channelResults, hasLength(1));
      await cubit.searchChannels('  ');
      expect(cubit.state.channelQuery, '');
    });

    test('o loader de playlists usa a leitura de playlist do repositório', () async {
      final result = await cubit.channelLoader.load('PLAPpcKnpMfeO9Fydpl1tTKC9CRRnIMMSK');
      expect(result.items, hasLength(2));
      expect(search.playlistCalls.single, 'PLAPpcKnpMfeO9Fydpl1tTKC9CRRnIMMSK');
    });
  });
}
