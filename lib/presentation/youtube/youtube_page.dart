import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_radius.dart';
import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_target.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_downloads.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_link_repository_impl.dart';
import 'package:louvorja_piano_mobile/data/repositories/youtube_search_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/domain/repositories/youtube_search_repository.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/player/local_liturgy_player.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/player/local_liturgy_player_bar.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/player/local_liturgy_session.dart';
import 'package:louvorja_piano_mobile/presentation/shared/phone_projection.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/empty_state.dart';

import 'bloc/youtube_cubit.dart';
import 'widgets/youtube_collections_tab.dart';
import 'widgets/youtube_sheets.dart';
import 'widgets/youtube_video_tile.dart';

/// Abre o vídeo no player local (o mesmo visual do controle remoto, usado
/// pela Liturgia): o vídeo vem direto do YouTube (ou da cópia baixada).
/// Projetar é pela seta do próprio player (segue as conexões de Telas).
typedef YoutubePlayerOpener =
    Future<void> Function(BuildContext context, YoutubeVideo video);

Future<void> openYoutubePlayer(BuildContext context, YoutubeVideo video) async {
  final player = localLiturgyPlayer;
  final messenger = ScaffoldMessenger.of(context);
  final language = context.locale.languageCode;
  // Um vídeo por vez: fecha o que estiver aberto (e a projeção dele).
  if (player.state.hasOpenMedia || player.pending != null || player.busy) {
    final wasProjecting = player.state.videoControls?.projecting ?? false;
    await player.send(
      RemoteCommand(id: 'youtube-replace', action: RemoteAction.stop),
    );
    if (wasProjecting) await PhoneProjection.end();
  }
  // Como na Liturgia: o player de Hinos fecha para ficar só o vídeo.
  if (nowPlaying.hasTrack) {
    await HymnAudioPlayer.instance.stop();
    nowPlaying.stop();
    StageSession.instance.stopHymnAudio();
  }
  player.choose(
    LiturgyItem(
      id: 'youtube-${video.videoId}',
      type: LiturgyItemType.onlineVideo,
      name: video.title,
      subtitle: video.channel,
      url: video.watchUrl,
    ),
    language: language,
    date: DateTime.now(),
  );
  try {
    await player.openPending();
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text('youtube.actions.failed'.tr())),
    );
  }
}

/// Módulo YouTube (a partir de Hinos): buscar, tocar e projetar vídeos,
/// histórico, favoritos, coletâneas online e downloads offline.
/// Paridade com o módulo YouTube do desktop.
class YoutubePage extends StatelessWidget {
  const YoutubePage({
    super.key,
    this.search,
    this.storage,
    this.openPlayer = openYoutubePlayer,
  });

  final YoutubeSearchRepository? search;
  final YoutubeLibraryStorage? storage;
  final YoutubePlayerOpener openPlayer;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => YoutubeCubit(
      search: search ?? YoutubeSearchRepositoryImpl(),
      storage: storage,
    )..load(),
    child: _YoutubeView(openPlayer: openPlayer),
  );
}

class _YoutubeView extends StatefulWidget {
  const _YoutubeView({required this.openPlayer});
  final YoutubePlayerOpener openPlayer;

  @override
  State<_YoutubeView> createState() => _YoutubeViewState();
}

class _YoutubeViewState extends State<_YoutubeView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final _searchField = TextEditingController();
  final _historyFilter = TextEditingController();
  final _favoritesFilter = TextEditingController();
  final _scroll = ScrollController();
  final _openedCollection = ValueNotifier<String?>(null);
  Timer? _typing;

  /// Busca sozinha depois de uma pausa na digitação.
  static const typingPause = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (YoutubeDownloads.supported) {
      unawaited(YoutubeDownloads.instance.measure());
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchField.dispose();
    _historyFilter.dispose();
    _favoritesFilter.dispose();
    _scroll.dispose();
    _openedCollection.dispose();
    _typing?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 600) {
      unawaited(context.read<YoutubeCubit>().loadMore());
    }
  }

  YoutubeCubit get _cubit => context.read<YoutubeCubit>();

  Future<void> _play(YoutubeVideo video) async {
    FocusScope.of(context).unfocus();
    unawaited(_cubit.recordPlay(video));
    await widget.openPlayer(context, video);
  }

  /// Enquanto digita: busca sozinha após a pausa (3+ letras). Link não
  /// toca sozinho: só pela lupa/Enter.
  void _onTyping(String value) {
    _typing?.cancel();
    final text = value.trim();
    if (text.isEmpty) {
      _cubit.clearSearch();
      return;
    }
    if (text.length < 3 ||
        text == _cubit.state.query ||
        LiturgyWebTarget.parse(text)?.kind == 'youtube') {
      return;
    }
    _typing = Timer(typingPause, () {
      if (mounted) unawaited(_runSearch(text));
    });
  }

  Future<void> _runSearch(String text) async {
    await _cubit.search(text);
    if (!mounted) return;
    unawaited(
      YoutubeDownloads.instance.refresh(
        _cubit.state.results.map((v) => v.videoId),
      ),
    );
  }

  /// Link colado: toca direto (busca título/canal para o histórico).
  Future<void> _submit() async {
    _typing?.cancel();
    final text = _searchField.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final target = LiturgyWebTarget.parse(text);
    if (target != null &&
        target.kind == 'youtube' &&
        YoutubeVideo.isValidId(target.videoId)) {
      var video = YoutubeVideo(videoId: target.videoId, title: target.videoId);
      try {
        final info = await LiturgyLinkRepositoryImpl()
            .info(target.url)
            .timeout(const Duration(seconds: 20));
        video = YoutubeVideo(
          videoId: target.videoId,
          title: info.title.isNotEmpty ? info.title : target.videoId,
          channel: info.source,
        );
      } catch (_) {
        /* fica com o id como título */
      }
      if (!mounted) return;
      await _play(video);
      return;
    }
    await _runSearch(text);
  }

  Future<void> _importPlaylist() async {
    final created = await showYoutubePlaylistImport(context);
    if (created == null || !mounted) return;
    _tabs.animateTo(3);
    _openedCollection.value = created.id;
    showYoutubeToast(
      context,
      'youtube.playlist.created'.tr(
        namedArgs: {'name': created.name, 'n': '${created.videos.length}'},
      ),
    );
  }

  YoutubeVideoTile _tile(
    YoutubeVideo video,
    YoutubeState state, {
    String? subtitle,
    List<YoutubeTileAction> extra = const [],
  }) => YoutubeVideoTile(
    video: video,
    favorite: state.isFavorite(video.videoId),
    subtitle: subtitle,
    onPlay: () => _play(video),
    onFavorite: () => _cubit.toggleFavorite(video),
    onAddToCollection: () => showYoutubeCollectionPicker(context, video),
    extraActions: extra,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<YoutubeCubit, YoutubeState>(
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('youtube.title'.tr()),
              Text(
                'youtube.subtitle'.tr(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          actions: [
            if (YoutubeDownloads.supported)
              _StorageChip(
                onTap: () {
                  final state = _cubit.state;
                  showYoutubeStorageSheet(
                    context,
                    known: [
                      ...state.results,
                      ...state.favorites.map((v) => v.toVideo()),
                      ...state.history.map((v) => v.toVideo()),
                      for (final c in state.collections)
                        ...c.videos.map((v) => v.toVideo()),
                    ],
                  );
                },
              ),
            IconButton(
              key: const Key('youtube-playlist-import'),
              tooltip: 'youtube.playlist.open'.tr(),
              onPressed: _importPlaylist,
              icon: const Icon(TablerIcons.clipboardList),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'youtube.tabs.search'.tr()),
              _countTab('youtube.tabs.history'.tr(), state.history.length),
              _countTab('youtube.tabs.favorites'.tr(), state.favorites.length),
              _countTab(
                'youtube.tabs.collections'.tr(),
                state.collections.length,
              ),
            ],
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(child: _tabViews()),
              // O mesmo player da Liturgia (visual do controle remoto).
              BlocBuilder<LocalLiturgyPlayer, RemotePlayerState>(
                bloc: localLiturgyPlayer,
                builder: (context, _) => localLiturgyPlayer.hasContent
                    ? ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .62,
                        ),
                        child: const SingleChildScrollView(
                          child: LocalLiturgyPlayerBar(),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabViews() => BlocBuilder<YoutubeCubit, YoutubeState>(
    builder: (context, state) => TabBarView(
      controller: _tabs,
      children: [
        _searchTab(state, Theme.of(context)),
        _historyTab(state),
        _favoritesTab(state),
        YoutubeCollectionsTab(
          tile: (video, collectionState, {extra = const []}) =>
              _tile(video, collectionState, extra: extra),
          opened: _openedCollection,
          onImportPlaylist: _importPlaylist,
          onOpenSearch: () => _tabs.animateTo(0),
        ),
      ],
    ),
  );

  Tab _countTab(String label, int count) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Badge(
            label: Text('$count'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            textColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ],
      ],
    ),
  );

  Widget _searchTab(YoutubeState state, ThemeData theme) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s3,
        AppSpacing.s3,
        AppSpacing.s3,
        AppSpacing.s2,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('youtube-search-field'),
              controller: _searchField,
              textInputAction: TextInputAction.search,
              onChanged: _onTyping,
              decoration: InputDecoration(
                hintText: 'youtube.search.placeholder'.tr(),
                prefixIcon: const Icon(TablerIcons.brandYoutube),
                border: const OutlineInputBorder(borderRadius: AppRadius.md),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: _searchField,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'common.clearSearch'.tr(),
                          onPressed: () {
                            _typing?.cancel();
                            _searchField.clear();
                            _cubit.clearSearch();
                          },
                          icon: const Icon(TablerIcons.x),
                        ),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          // Lupa: busca na hora (o Enter do teclado nem sempre chega).
          SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('youtube-search-submit'),
              onPressed: _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
              ),
              child: state.searching
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Icon(
                      TablerIcons.search,
                      semanticLabel: 'youtube.search.submit'.tr(),
                    ),
            ),
          ),
        ],
      ),
    );

    Widget body;
    if (state.searching) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.s3),
            Text('youtube.search.loading'.tr()),
          ],
        ),
      );
    } else if (state.searchError) {
      body = EmptyState(
        icon: TablerIcons.wifiOff,
        title: 'youtube.search.error'.tr(),
        actionLabel: 'common.retry'.tr(),
        onAction: () => _cubit.search(state.query),
      );
    } else if (state.searched && state.results.isEmpty) {
      body = EmptyState(
        icon: TablerIcons.moodEmpty,
        title: 'youtube.search.noResults'.tr(namedArgs: {'query': state.query}),
      );
    } else if (state.results.isNotEmpty) {
      body = ListView.builder(
        key: const Key('youtube-results'),
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: AppSpacing.s8),
        itemCount: state.results.length + 1,
        itemBuilder: (context, i) {
          if (i == state.results.length) {
            return state.continuation == null
                ? const SizedBox(height: AppSpacing.s4)
                : const Padding(
                    padding: EdgeInsets.all(AppSpacing.s4),
                    child: Center(child: CircularProgressIndicator()),
                  );
          }
          return _tile(state.results[i], state);
        },
      );
    } else {
      body = ListView(
        children: [
          if (state.recentQueries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'youtube.search.recent'.tr().toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: [
                      for (final q in state.recentQueries)
                        InputChip(
                          key: Key('youtube-recent-$q'),
                          label: Text(q),
                          onPressed: () {
                            _searchField.text = q;
                            _submit();
                          },
                          onDeleted: () => _cubit.forgetQuery(q),
                          deleteButtonTooltipMessage: 'youtube.search.forget'
                              .tr(namedArgs: {'query': q}),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.s8),
          EmptyState(
            icon: TablerIcons.musicSearch,
            title: 'youtube.search.empty'.tr(),
          ),
        ],
      );
    }
    return Column(
      children: [
        header,
        Expanded(child: body),
      ],
    );
  }

  Widget _filterField(TextEditingController controller, String hint) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.s3,
      AppSpacing.s3,
      AppSpacing.s3,
      AppSpacing.s1,
    ),
    child: TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        prefixIcon: const Icon(TablerIcons.filter),
        border: const OutlineInputBorder(borderRadius: AppRadius.md),
      ),
    ),
  );

  Widget _historyTab(YoutubeState state) {
    if (state.history.isEmpty) {
      return EmptyState(
        icon: TablerIcons.history,
        title: 'youtube.history.empty'.tr(),
      );
    }
    final query = _historyFilter.text;
    final list = filterYoutubeVideos(
      state.history,
      query,
      (e) => '${e.title} ${e.channel}',
    );
    return Column(
      children: [
        _filterField(_historyFilter, 'youtube.history.filter'.tr()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'youtube.history.count'.tr(
                    namedArgs: {'n': '${state.history.length}'},
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton.icon(
                key: const Key('youtube-history-clear'),
                onPressed: () async {
                  final ok = await confirmYoutubeAction(
                    context,
                    title: 'youtube.history.clearTitle'.tr(),
                    message: 'youtube.history.clearMessage'.tr(),
                    confirm: 'youtube.history.clearConfirm'.tr(),
                    confirmKey: const Key('youtube-history-clear-confirm'),
                  );
                  if (ok) await _cubit.clearHistory();
                },
                icon: const Icon(TablerIcons.trash, size: 18),
                label: Text('youtube.history.clear'.tr()),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? EmptyState(
                  icon: TablerIcons.search,
                  title: 'youtube.history.noMatch'.tr(
                    namedArgs: {'query': query},
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final entry = list[i];
                    return _tile(
                      entry.toVideo(),
                      state,
                      subtitle: 'youtube.history.plays'.tr(
                        namedArgs: {'n': '${entry.playCount}'},
                      ),
                      extra: [
                        YoutubeTileAction(
                          icon: TablerIcons.trash,
                          label: 'youtube.actions.remove'.tr(),
                          destructive: true,
                          onTap: () => _cubit.removeFromHistory(entry.videoId),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _favoritesTab(YoutubeState state) {
    if (state.favorites.isEmpty) {
      return EmptyState(
        icon: TablerIcons.heart,
        title: 'youtube.favorites.empty'.tr(),
      );
    }
    final query = _favoritesFilter.text;
    final list = filterYoutubeVideos(
      state.favorites,
      query,
      (e) => '${e.title} ${e.channel}',
    );
    return Column(
      children: [
        _filterField(_favoritesFilter, 'youtube.favorites.filter'.tr()),
        Expanded(
          child: list.isEmpty
              ? EmptyState(
                  icon: TablerIcons.search,
                  title: 'youtube.history.noMatch'.tr(
                    namedArgs: {'query': query},
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _tile(list[i].toVideo(), state),
                ),
        ),
      ],
    );
  }
}

/// Total dos vídeos baixados (toque mostra os detalhes).
class _StorageChip extends StatelessWidget {
  const _StorageChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final downloads = YoutubeDownloads.instance;
    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) => Tooltip(
        message: 'youtube.storage.hint'.tr(),
        child: TextButton.icon(
          key: const Key('youtube-storage'),
          onPressed: onTap,
          icon: const Icon(TablerIcons.database, size: 18),
          label: Text(formatYoutubeBytes(downloads.totalBytes)),
        ),
      ),
    );
  }
}
