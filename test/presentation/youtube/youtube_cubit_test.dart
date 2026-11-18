import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
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
  Future<YoutubePlaylistResult> playlist(String text) async =>
      YoutubePlaylistResult(title: 'Natal', items: [video(1), video(2)]);
}

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
}
