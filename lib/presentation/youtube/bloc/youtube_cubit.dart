import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:louvorja_piano_mobile/core/services/youtube/youtube_channels.dart';
import 'package:louvorja_piano_mobile/core/utils/reorder.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_channel.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/domain/repositories/youtube_search_repository.dart';

class YoutubeState {
  const YoutubeState({
    this.query = '',
    this.results = const [],
    this.continuation,
    this.searching = false,
    this.loadingMore = false,
    this.searchError = false,
    this.searched = false,
    this.recentQueries = const [],
    this.history = const [],
    this.favorites = const [],
    this.collections = const [],
    this.channels = defaultYoutubeChannels,
    this.channelQuery = '',
    this.channelResults = const [],
    this.channelSearching = false,
    this.channelSearchError,
    this.loaded = false,
  });

  /// Última busca feita (o texto que gerou [results]).
  final String query;
  final List<YoutubeVideo> results;
  final YoutubeContinuation? continuation;
  final bool searching, loadingMore, searchError, searched, loaded;
  final List<String> recentQueries;
  final List<YoutubeSavedVideo> history, favorites;
  final List<YoutubeCollection> collections;

  /// Canais: os padrão (CPB) e os cadastrados.
  final List<YoutubeChannel> channels;

  /// Pesquisa de canais adventistas: o texto pesquisado (vazio = fechada),
  /// os canais achados e o erro (`empty`, `network`…).
  final String channelQuery;
  final List<YoutubeChannelSearchItem> channelResults;
  final bool channelSearching;
  final String? channelSearchError;

  YoutubeChannel? channel(String? id) =>
      channels.where((c) => c.id == id).firstOrNull;

  /// Canal achado na pesquisa que já está na lista (cadastrado ou padrão).
  YoutubeChannel? knownChannel(String youtubeId) => channels
      .where((c) => c.id == youtubeId || c.youtubeId == youtubeId)
      .firstOrNull;

  bool get canLoadMore => continuation != null && !searching && !loadingMore;

  bool isFavorite(String videoId) =>
      favorites.any((entry) => entry.videoId == videoId);

  YoutubeCollection? collection(String id) =>
      collections.where((c) => c.id == id).firstOrNull;

  YoutubeState copyWith({
    String? query,
    List<YoutubeVideo>? results,
    YoutubeContinuation? Function()? continuation,
    bool? searching,
    bool? loadingMore,
    bool? searchError,
    bool? searched,
    List<String>? recentQueries,
    List<YoutubeSavedVideo>? history,
    List<YoutubeSavedVideo>? favorites,
    List<YoutubeCollection>? collections,
    List<YoutubeChannel>? channels,
    String? channelQuery,
    List<YoutubeChannelSearchItem>? channelResults,
    bool? channelSearching,
    String? Function()? channelSearchError,
    bool? loaded,
  }) => YoutubeState(
    query: query ?? this.query,
    results: results ?? this.results,
    continuation: continuation != null ? continuation() : this.continuation,
    searching: searching ?? this.searching,
    loadingMore: loadingMore ?? this.loadingMore,
    searchError: searchError ?? this.searchError,
    searched: searched ?? this.searched,
    recentQueries: recentQueries ?? this.recentQueries,
    history: history ?? this.history,
    favorites: favorites ?? this.favorites,
    collections: collections ?? this.collections,
    channels: channels ?? this.channels,
    channelQuery: channelQuery ?? this.channelQuery,
    channelResults: channelResults ?? this.channelResults,
    channelSearching: channelSearching ?? this.channelSearching,
    channelSearchError: channelSearchError != null
        ? channelSearchError()
        : this.channelSearchError,
    loaded: loaded ?? this.loaded,
  );
}

/// Estado do módulo YouTube: busca (com rolagem infinita), histórico,
/// favoritos, buscas recentes e coletâneas online.
class YoutubeCubit extends Cubit<YoutubeState> {
  YoutubeCubit({
    required YoutubeSearchRepository search,
    YoutubeLibraryStorage? storage,
  }) : _search = search,
       _storage = storage ?? YoutubeLibraryStorage(),
       super(const YoutubeState()) {
    channelLoader = ChannelPlaylistLoader(_search.playlist);
  }

  final YoutubeSearchRepository _search;
  final YoutubeLibraryStorage _storage;

  /// Vídeos das playlists dos canais (cache enquanto o módulo está aberto).
  late final ChannelPlaylistLoader channelLoader;
  int _channelSearchSeq = 0;

  /// Quantos vídeos a primeira busca já traz (como no desktop).
  static const initialTarget = 60;
  int _searchSeq = 0;

  Future<void> load() async {
    final recent = await _storage.recentQueries();
    final history = await _storage.history();
    final favorites = await _storage.favorites();
    final collections = await _storage.collections();
    final channels = await _storage.channels();
    if (isClosed) return;
    emit(
      state.copyWith(
        recentQueries: recent,
        history: history,
        favorites: favorites,
        collections: collections,
        channels: channels,
        loaded: true,
      ),
    );
  }

  /// Só histórico e favoritos (no controle remoto, quando o desktop manda).
  Future<void> reloadLibrary() async {
    final history = await _storage.history();
    final favorites = await _storage.favorites();
    if (isClosed) return;
    emit(state.copyWith(history: history, favorites: favorites));
  }

  /* ---------- Busca ---------- */

  Future<void> search(String text) async {
    final q = text.trim();
    if (q.isEmpty) return;
    final seq = ++_searchSeq;
    emit(
      state.copyWith(
        query: q,
        results: const [],
        continuation: () => null,
        searching: true,
        searchError: false,
        searched: true,
      ),
    );
    final recent = await _storage.rememberQuery(q);
    final result = await _search.search(q);
    if (isClosed || seq != _searchSeq) return;
    var items = result.items;
    var continuation = result.continuation;
    // Primeira página traz ~20: busca mais até chegar na meta.
    while (items.length < initialTarget && continuation != null) {
      final more = await _search.more(continuation);
      if (isClosed || seq != _searchSeq) return;
      final seen = items.map((i) => i.videoId).toSet();
      final added = more.items.where((i) => seen.add(i.videoId)).toList();
      if (added.isEmpty) {
        continuation = null;
        break;
      }
      items = [...items, ...added];
      continuation = more.continuation;
    }
    emit(
      state.copyWith(
        results: items,
        continuation: () => continuation,
        searching: false,
        searchError: result.error != null && items.isEmpty,
        recentQueries: recent,
      ),
    );
  }

  Future<void> loadMore() async {
    final continuation = state.continuation;
    if (continuation == null || !state.canLoadMore) return;
    final seq = _searchSeq;
    emit(state.copyWith(loadingMore: true));
    final more = await _search.more(continuation);
    if (isClosed || seq != _searchSeq) return;
    final seen = state.results.map((i) => i.videoId).toSet();
    final added = more.items.where((i) => seen.add(i.videoId)).toList();
    emit(
      state.copyWith(
        results: [...state.results, ...added],
        continuation: () => added.isEmpty ? null : more.continuation,
        loadingMore: false,
      ),
    );
  }

  /// Volta para as buscas recentes (limpa o campo).
  void clearSearch() {
    _searchSeq++;
    emit(
      state.copyWith(
        query: '',
        results: const [],
        continuation: () => null,
        searching: false,
        loadingMore: false,
        searchError: false,
        searched: false,
      ),
    );
  }

  Future<void> forgetQuery(String query) async {
    final list = await _storage.forgetQuery(query);
    if (!isClosed) emit(state.copyWith(recentQueries: list));
  }

  Future<YoutubePlaylistResult> fetchPlaylist(String text) =>
      _search.playlist(text);

  /* ---------- Histórico e favoritos ---------- */

  Future<void> recordPlay(YoutubeVideo video) async {
    final list = await _storage.recordPlay(video);
    if (!isClosed) emit(state.copyWith(history: list));
  }

  Future<void> removeFromHistory(String videoId) async {
    final list = await _storage.removeFromHistory(videoId);
    if (!isClosed) emit(state.copyWith(history: list));
  }

  Future<void> clearHistory() async {
    final list = await _storage.clearHistory();
    if (!isClosed) emit(state.copyWith(history: list));
  }

  /// Arrastar e soltar nos resultados da busca: vale só para esta busca.
  void reorderResults(String fromId, String toId) => emit(
    state.copyWith(
      results: moveById(state.results, (v) => v.videoId, fromId, toId),
    ),
  );

  Future<void> reorderHistory(String fromId, String toId) async {
    final list = await _storage.reorderHistory(fromId, toId);
    if (!isClosed) emit(state.copyWith(history: list));
  }

  Future<void> reorderFavorites(String fromId, String toId) async {
    final list = await _storage.reorderFavorites(fromId, toId);
    if (!isClosed) emit(state.copyWith(favorites: list));
  }

  Future<void> toggleFavorite(YoutubeVideo video) async {
    final list = await _storage.toggleFavorite(video);
    if (!isClosed) emit(state.copyWith(favorites: list));
  }

  /* ---------- Coletâneas ---------- */

  Future<YoutubeCollection?> createCollection(String name) async {
    final result = await _storage.createCollection(name);
    if (!isClosed) emit(state.copyWith(collections: result.list));
    return result.created;
  }

  Future<void> renameCollection(String id, String name) async =>
      _setCollections(await _storage.renameCollection(id, name));

  Future<void> deleteCollection(String id) async =>
      _setCollections(await _storage.deleteCollection(id));

  Future<void> addToCollection(String id, YoutubeVideo video) async =>
      _setCollections(await _storage.addVideo(id, video));

  Future<void> removeFromCollection(String id, String videoId) async =>
      _setCollections(await _storage.removeVideo(id, videoId));

  Future<void> reorderCollections(String fromId, String toId) async =>
      _setCollections(await _storage.reorderCollections(fromId, toId));

  Future<void> reorderInCollection(
    String id,
    String fromId,
    String toId,
  ) async => _setCollections(await _storage.reorderVideos(id, fromId, toId));

  Future<void> moveInCollection(String id, String videoId, int delta) async =>
      _setCollections(await _storage.moveVideo(id, videoId, delta));

  /// Cria a coletânea a partir de uma playlist colada.
  Future<YoutubeCollection?> createFromPlaylist(
    String name,
    List<YoutubeVideo> videos,
  ) async {
    final created = await createCollection(name);
    if (created == null) return null;
    _setCollections(await _storage.addVideos(created.id, videos));
    return state.collection(created.id);
  }

  void _setCollections(List<YoutubeCollection> list) {
    if (!isClosed) emit(state.copyWith(collections: list));
  }

  /* ---------- Canais ---------- */

  /// Cadastra pelo link, @handle ou id. `error` vem do YouTube quando não deu.
  Future<({YoutubeChannelSaveStatus status, YoutubeChannel? channel, String? error})>
  addChannel(String text) async {
    final q = text.trim();
    if (q.isEmpty) {
      return (status: YoutubeChannelSaveStatus.invalid, channel: null, error: 'invalid');
    }
    final result = await _search.channel(q);
    final saved = await _storage.saveChannel(result);
    if (!isClosed && saved.status != YoutubeChannelSaveStatus.invalid) {
      emit(state.copyWith(channels: saved.list));
    }
    return (
      status: saved.status,
      channel: saved.channel,
      error: saved.status == YoutubeChannelSaveStatus.invalid
          ? (result.error ?? 'empty')
          : null,
    );
  }

  Future<void> removeChannel(String id) async {
    final list = await _storage.removeChannel(id);
    if (!isClosed) emit(state.copyWith(channels: list));
  }

  /// Canal cadastrado: relê as playlists ao abrir (falha mantém as salvas).
  Future<void> refreshChannel(YoutubeChannel channel) async {
    final result = await _search.channel(channel.url);
    if (result.channel?.id != channel.id) return;
    final saved = await _storage.saveChannel(result);
    if (!isClosed && saved.status == YoutubeChannelSaveStatus.updated) {
      emit(state.copyWith(channels: saved.list));
    }
  }

  /// Pesquisa canais adventistas sobre o tema (a mais nova vale).
  Future<void> searchChannels(String text) async {
    final q = text.trim();
    if (q.isEmpty) return clearChannelSearch();
    final seq = ++_channelSearchSeq;
    emit(
      state.copyWith(
        channelQuery: q,
        channelResults: const [],
        channelSearching: true,
        channelSearchError: () => null,
      ),
    );
    final result = await _search.searchChannels(q);
    if (isClosed || seq != _channelSearchSeq) return;
    emit(
      state.copyWith(
        channelResults: result.items,
        channelSearching: false,
        channelSearchError: () =>
            result.items.isNotEmpty ? null : (result.error ?? 'empty'),
      ),
    );
  }

  void clearChannelSearch() {
    _channelSearchSeq++;
    emit(
      state.copyWith(
        channelQuery: '',
        channelResults: const [],
        channelSearching: false,
        channelSearchError: () => null,
      ),
    );
  }
}
