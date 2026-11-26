import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_radius.dart';
import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_channel_parser.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_channels.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_downloads.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_channel.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/empty_state.dart';
import 'package:louvorja_piano_mobile/presentation/youtube/bloc/youtube_cubit.dart';

import 'youtube_sheets.dart';

/// Canal e playlist abertos na aba (nulos = lista de canais / de playlists).
/// Ficam na página para sobreviver à troca de abas.
class YoutubeChannelsSelection {
  final channel = ValueNotifier<String?>(null);
  final playlist = ValueNotifier<String?>(null);

  void dispose() {
    channel.dispose();
    playlist.dispose();
  }
}

/// Canais (paridade com a seção Canais do desktop): o canal da CPB (todos os
/// hinos do Novo Hinário numa lista só), canais cadastrados pelo link ou pela
/// pesquisa de canais adventistas; o cadastrado abre nas playlists
/// (categorias) e cada uma nos vídeos.
class YoutubeChannelsTab extends StatefulWidget {
  const YoutubeChannelsTab({
    super.key,
    required this.tile,
    required this.selection,
    required this.onSavedCollection,
    this.typingPause = const Duration(milliseconds: 700),
  });

  final Widget Function(YoutubeVideo video, YoutubeState state) tile;
  final YoutubeChannelsSelection selection;

  /// "Salvar como coletânea": a página abre a coletânea criada.
  final ValueChanged<YoutubeCollection> onSavedCollection;
  final Duration typingPause;

  @override
  State<YoutubeChannelsTab> createState() => _YoutubeChannelsTabState();
}

class _YoutubeChannelsTabState extends State<YoutubeChannelsTab> {
  final _add = TextEditingController();
  final _search = TextEditingController();
  final _playlistFilter = TextEditingController();
  final _videoFilter = TextEditingController();
  Timer? _typing;
  String _lastAddText = '';
  bool _adding = false;
  String? _addError;

  List<YoutubeVideo> _videos = const [];
  bool _loading = false;
  String? _loadError;
  int _loadSeq = 0;

  YoutubeChannelsSelection get _sel => widget.selection;
  YoutubeCubit get _cubit => context.read<YoutubeCubit>();

  @override
  void initState() {
    super.initState();
    _sel.channel.addListener(_onSelection);
    _sel.playlist.addListener(_onSelection);
    // Volta para o canal/playlist que estava aberto (setState só depois de montar).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onSelection();
    });
  }

  @override
  void dispose() {
    _sel.channel.removeListener(_onSelection);
    _sel.playlist.removeListener(_onSelection);
    _typing?.cancel();
    _add.dispose();
    _search.dispose();
    _playlistFilter.dispose();
    _videoFilter.dispose();
    super.dispose();
  }

  /* ---------- Abrir canal / playlist ---------- */

  void _openChannel(YoutubeChannel channel) {
    FocusScope.of(context).unfocus();
    _playlistFilter.clear();
    _sel.playlist.value = null;
    _sel.channel.value = channel.id;
    if (channel.userAdded) unawaited(_cubit.refreshChannel(channel));
  }

  void _onSelection() {
    final channel = _cubit.state.channel(_sel.channel.value);
    final playlist = channel?.playlist(_sel.playlist.value);
    _videoFilter.clear();
    unawaited(_load(channel, playlist));
  }

  Future<void> _load(
    YoutubeChannel? channel,
    YoutubeChannelPlaylist? playlist, {
    bool force = false,
  }) async {
    final seq = ++_loadSeq;
    final merged = playlist == null && (channel?.merged ?? false);
    if (playlist == null && !merged) {
      setState(() {
        _videos = const [];
        _loading = false;
        _loadError = null;
      });
      return;
    }
    final loader = _cubit.channelLoader;
    final cached = playlist != null && !force ? loader.cached(playlist.id) : null;
    if (cached != null) {
      _show(cached, null);
      return;
    }
    setState(() {
      _videos = const [];
      _loading = true;
      _loadError = null;
    });
    final result = merged
        ? await loadChannelVideos(channel!, loader)
        : await loader.load(playlist!.id, force: force);
    if (!mounted || seq != _loadSeq) return;
    _show(result.items, result.error);
  }

  void _show(List<YoutubeVideo> videos, String? error) {
    if (!mounted) return;
    setState(() {
      _videos = videos;
      _loading = false;
      _loadError = error;
    });
    if (videos.isNotEmpty && YoutubeDownloads.supported) {
      unawaited(YoutubeDownloads.instance.refresh(videos.map((v) => v.videoId)));
    }
  }

  /* ---------- Cadastrar / pesquisar / excluir ---------- */

  Future<void> _addChannel(String text) async {
    final q = text.trim();
    if (q.isEmpty || _adding) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _adding = true;
      _addError = null;
    });
    final result = await _cubit.addChannel(q);
    if (!mounted) return;
    setState(() => _adding = false);
    final channel = result.channel;
    if (channel == null) {
      setState(
        () => _addError = switch (result.error) {
          'invalid' => 'youtube.channels.addInvalid',
          'empty' => 'youtube.channels.addEmpty',
          _ => 'youtube.channels.addError',
        },
      );
      return;
    }
    if (_add.text.trim() == q) {
      _add.clear();
      _lastAddText = '';
    }
    showYoutubeToast(
      context,
      (result.status == YoutubeChannelSaveStatus.builtIn
              ? 'youtube.channels.alreadyDefault'
              : 'youtube.channels.added')
          .tr(namedArgs: {'name': channel.name}),
    );
    _openChannel(channel);
  }

  /// Colou um link de canal: cadastra na hora (digitar não dispara).
  void _onAddChanged(String value) {
    final pasted = value.length - _lastAddText.length > 1;
    _lastAddText = value;
    if (pasted && YoutubeChannelParser.isChannelLink(value)) {
      unawaited(_addChannel(value));
    }
  }

  /// Pesquisa enquanto digita (igual à busca de vídeos): pausa e 3+ letras.
  void _onSearchChanged(String value) {
    _typing?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      _cubit.clearChannelSearch();
      return;
    }
    if (q.length < 3 || q == _cubit.state.channelQuery) return;
    _typing = Timer(widget.typingPause, () {
      if (mounted) unawaited(_cubit.searchChannels(q));
    });
  }

  void _submitSearch() {
    _typing?.cancel();
    FocusScope.of(context).unfocus();
    unawaited(_cubit.searchChannels(_search.text));
  }

  void _closeSearch() {
    _typing?.cancel();
    _search.clear();
    _cubit.clearChannelSearch();
  }

  Future<void> _delete(YoutubeChannel channel) async {
    final ok = await confirmYoutubeAction(
      context,
      title: 'youtube.channels.deleteTitle'.tr(
        namedArgs: {'name': channel.name},
      ),
      message: 'youtube.channels.deleteMessage'.tr(),
      confirm: 'youtube.channels.deleteConfirm'.tr(),
      confirmKey: const Key('youtube-channel-delete-confirm'),
    );
    if (!ok || !mounted) return;
    if (_sel.channel.value == channel.id) {
      _sel.playlist.value = null;
      _sel.channel.value = null;
    }
    await _cubit.removeChannel(channel.id);
  }

  Future<void> _saveAsCollection(YoutubeChannelPlaylist playlist) async {
    if (_videos.isEmpty) return;
    final created = await _cubit.createFromPlaylist(playlist.name, _videos);
    if (created != null && mounted) widget.onSavedCollection(created);
  }

  /* ---------- Telas ---------- */

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_sel.channel, _sel.playlist]),
    builder: (context, _) => BlocBuilder<YoutubeCubit, YoutubeState>(
      builder: (context, state) {
        final channel = state.channel(_sel.channel.value);
        if (channel == null) return _list(state);
        final playlist = channel.playlist(_sel.playlist.value);
        if (playlist == null && !channel.merged) {
          return _playlists(channel);
        }
        return _videoList(state, channel, playlist);
      },
    ),
  );

  InputDecoration _field(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        isDense: true,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: const OutlineInputBorder(borderRadius: AppRadius.md),
      );

  Widget _spinner() => const SizedBox(
    width: 18,
    height: 18,
    child: Padding(
      padding: EdgeInsets.all(2),
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );

  Widget _list(YoutubeState state) {
    final theme = Theme.of(context);
    return ListView(
      key: const Key('youtube-channels-list'),
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s3,
            AppSpacing.s3,
            AppSpacing.s3,
            AppSpacing.s1,
          ),
          child: TextField(
            key: const Key('youtube-channel-add-input'),
            controller: _add,
            enabled: !_adding,
            maxLength: 300,
            textInputAction: TextInputAction.go,
            onChanged: _onAddChanged,
            onSubmitted: _addChannel,
            decoration: _field(
              'youtube.channels.addPlaceholder'.tr(),
              TablerIcons.brandYoutube,
              suffix: IconButton(
                key: const Key('youtube-channel-add'),
                tooltip: 'youtube.channels.add'.tr(),
                onPressed: _adding ? null : () => _addChannel(_add.text),
                icon: _adding ? _spinner() : const Icon(TablerIcons.plus),
              ),
            ).copyWith(counterText: ''),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s3,
            AppSpacing.s1,
            AppSpacing.s3,
            AppSpacing.s2,
          ),
          child: TextField(
            key: const Key('youtube-channel-search-input'),
            controller: _search,
            maxLength: 200,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _submitSearch(),
            decoration: _field(
              'youtube.channels.searchPlaceholder'.tr(),
              TablerIcons.search,
              suffix: state.channelSearching
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: _spinner(),
                    )
                  : null,
            ).copyWith(counterText: ''),
          ),
        ),
        if (_addError != null)
          Padding(
            key: const Key('youtube-channel-add-error'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s1,
            ),
            child: Row(
              children: [
                Icon(
                  TablerIcons.alertCircle,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    _addError!.tr(),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        if (state.channelQuery.isNotEmpty) _results(state),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s2,
            AppSpacing.s4,
            AppSpacing.s2,
          ),
          child: Text(
            'youtube.channels.hint'.tr(),
            style: theme.textTheme.bodySmall,
          ),
        ),
        for (final channel in state.channels) _channelCard(channel),
      ],
    );
  }

  Widget _results(YoutubeState state) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('youtube-channel-results'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'youtube.channels.searchTitle'.tr(
                      namedArgs: {'query': state.channelQuery},
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: const Key('youtube-channel-search-close'),
                  tooltip: 'youtube.channels.searchClose'.tr(),
                  onPressed: _closeSearch,
                  icon: const Icon(TablerIcons.x),
                ),
              ],
            ),
          ),
          if (state.channelSearching)
            Padding(
              key: const Key('youtube-channel-searching'),
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Row(
                children: [
                  _spinner(),
                  const SizedBox(width: AppSpacing.s2),
                  Text('youtube.channels.searching'.tr()),
                ],
              ),
            )
          else if (state.channelSearchError != null)
            Padding(
              key: const Key('youtube-channel-search-error'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                0,
                AppSpacing.s4,
                AppSpacing.s4,
              ),
              child: Text(
                (state.channelSearchError == 'empty'
                        ? 'youtube.channels.searchEmpty'
                        : 'youtube.channels.searchError')
                    .tr(namedArgs: {'query': state.channelQuery}),
              ),
            )
          else
            for (final item in state.channelResults) _resultTile(state, item),
        ],
      ),
    );
  }

  Widget _resultTile(YoutubeState state, YoutubeChannelSearchItem item) {
    final theme = Theme.of(context);
    final known = state.knownChannel(item.id);
    final meta = [item.handle, item.subscribers].where((t) => t.isNotEmpty);
    return ListTile(
      key: Key('youtube-channel-result-${item.id}'),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.16),
        foregroundImage: item.avatar.isEmpty ? null : NetworkImage(item.avatar),
        onForegroundImageError: item.avatar.isEmpty ? null : (_, _) {},
        child: Icon(TablerIcons.brandYoutube, color: theme.colorScheme.primary),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [meta.join(' · '), item.description].where((t) => t.isNotEmpty).join('\n'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: known != null
          ? TextButton.icon(
              key: Key('youtube-channel-result-open-${item.id}'),
              onPressed: () => _openChannel(known),
              icon: const Icon(TablerIcons.circleCheck, size: 18),
              label: Text(
                (known.userAdded
                        ? 'youtube.channels.registered'
                        : 'youtube.channels.builtIn')
                    .tr(),
              ),
            )
          : FilledButton(
              key: Key('youtube-channel-result-add-${item.id}'),
              onPressed: _adding ? null : () => _addChannel(item.url),
              child: Text('youtube.channels.register'.tr()),
            ),
    );
  }

  Widget _channelCard(YoutubeChannel channel) {
    final theme = Theme.of(context);
    final covers = channel.covers;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: ListTile(
        key: Key('youtube-channel-${channel.id}'),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.16),
          foregroundImage: covers.isEmpty
              ? null
              : NetworkImage(channel.avatar.isNotEmpty ? channel.avatar : covers.first),
          onForegroundImageError: covers.isEmpty ? null : (_, _) {},
          child: Icon(TablerIcons.broadcast, color: theme.colorScheme.primary),
        ),
        title: Text(channel.name),
        subtitle: Text(
          channel.subtitle.isNotEmpty
              ? channel.subtitle
              : 'youtube.channels.playlistCount'.tr(
                  namedArgs: {'n': '${channel.playlists.length}'},
                ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (channel.userAdded)
              IconButton(
                key: Key('youtube-channel-delete-${channel.id}'),
                tooltip: 'youtube.channels.delete'.tr(),
                onPressed: () => _delete(channel),
                icon: Icon(TablerIcons.trash, color: theme.colorScheme.error),
              ),
            const Icon(TablerIcons.chevronRight),
          ],
        ),
        onTap: () => _openChannel(channel),
      ),
    );
  }

  Widget _header({
    required Key backKey,
    required String backTooltip,
    required VoidCallback onBack,
    required String title,
    String? subtitle,
    List<Widget> actions = const [],
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s1,
        AppSpacing.s2,
        AppSpacing.s1,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            key: backKey,
            tooltip: backTooltip,
            onPressed: onBack,
            icon: const Icon(TablerIcons.arrowLeft),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const Key('youtube-channel-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (subtitle != null)
                  Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }

  Widget _filter(TextEditingController controller, String hint, Key key) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s3,
          AppSpacing.s2,
          AppSpacing.s3,
          AppSpacing.s1,
        ),
        child: TextField(
          key: key,
          controller: controller,
          onChanged: (_) => setState(() {}),
          decoration: _field(hint, TablerIcons.filter),
        ),
      );

  Widget _playlists(YoutubeChannel channel) {
    final theme = Theme.of(context);
    final list = filterYoutubeVideos(
      channel.playlists,
      _playlistFilter.text,
      (p) => p.name,
    );
    return Column(
      children: [
        _header(
          backKey: const Key('youtube-channel-back'),
          backTooltip: 'youtube.channels.backToChannels'.tr(),
          onBack: () => _sel.channel.value = null,
          title: channel.name,
          subtitle: 'youtube.channels.playlistCount'.tr(
            namedArgs: {'n': '${channel.playlists.length}'},
          ),
          actions: [
            if (channel.userAdded)
              IconButton(
                key: const Key('youtube-channel-delete-open'),
                tooltip: 'youtube.channels.delete'.tr(),
                onPressed: () => _delete(channel),
                icon: Icon(TablerIcons.trash, color: theme.colorScheme.error),
              ),
          ],
        ),
        _filter(
          _playlistFilter,
          'youtube.channels.filterPlaylists'.tr(),
          const Key('youtube-channel-playlist-filter'),
        ),
        Expanded(
          child: list.isEmpty
              ? EmptyState(
                  icon: TablerIcons.search,
                  title: 'youtube.channels.noPlaylistMatch'.tr(
                    namedArgs: {'query': _playlistFilter.text.trim()},
                  ),
                )
              : ListView.builder(
                  key: const Key('youtube-channel-playlists'),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return ListTile(
                      key: Key('youtube-channel-playlist-${p.id}'),
                      leading: ClipRRect(
                        borderRadius: AppRadius.sm,
                        child: SizedBox(
                          width: 80,
                          height: 45,
                          child: p.cover.isEmpty
                              ? ColoredBox(
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  child: const Icon(TablerIcons.playlist),
                                )
                              : Image.network(
                                  p.cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    TablerIcons.playlist,
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: p.videoCount > 0
                          ? Text(
                              'youtube.collections.videoCount'.tr(
                                namedArgs: {'n': '${p.videoCount}'},
                              ),
                            )
                          : null,
                      trailing: const Icon(TablerIcons.chevronRight),
                      onTap: () => _sel.playlist.value = p.id,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _videoList(
    YoutubeState state,
    YoutubeChannel channel,
    YoutubeChannelPlaylist? playlist,
  ) {
    final filtered = filterChannelVideos(_videos, _videoFilter.text);
    final Widget body;
    if (_loading) {
      body = Center(
        key: const Key('youtube-channel-loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.s3),
            Text('youtube.channels.loading'.tr()),
          ],
        ),
      );
    } else if (_loadError != null) {
      body = EmptyState(
        key: const Key('youtube-channel-error'),
        icon: TablerIcons.wifiOff,
        title: (_loadError == 'empty'
                ? 'youtube.channels.empty'
                : 'youtube.channels.error')
            .tr(),
        actionLabel: 'youtube.channels.retry'.tr(),
        onAction: () => _load(channel, playlist, force: true),
      );
    } else if (filtered.isEmpty) {
      body = EmptyState(
        key: const Key('youtube-channel-no-match'),
        icon: TablerIcons.search,
        title: 'youtube.channels.noMatch'.tr(
          namedArgs: {'query': _videoFilter.text.trim()},
        ),
      );
    } else {
      body = ListView.builder(
        key: const Key('youtube-channel-videos'),
        itemCount: filtered.length,
        itemBuilder: (context, i) => widget.tile(filtered[i], state),
      );
    }
    return Column(
      children: [
        _header(
          backKey: playlist != null
              ? const Key('youtube-channel-playlist-back')
              : const Key('youtube-channel-back'),
          backTooltip: (playlist != null
                  ? 'youtube.channels.backToPlaylists'
                  : 'youtube.channels.backToChannels')
              .tr(),
          onBack: () => playlist != null
              ? _sel.playlist.value = null
              : _sel.channel.value = null,
          title: playlist?.name ?? channel.name,
          subtitle: _videos.isEmpty
              ? null
              : 'youtube.collections.videoCount'.tr(
                  namedArgs: {'n': '${_videos.length}'},
                ),
          actions: [
            if (playlist != null)
              IconButton(
                key: const Key('youtube-channel-save-collection'),
                tooltip: 'youtube.channels.saveAsCollection'.tr(),
                onPressed: _loading || _videos.isEmpty
                    ? null
                    : () => _saveAsCollection(playlist),
                icon: const Icon(TablerIcons.playlistAdd),
              ),
          ],
        ),
        _filter(
          _videoFilter,
          'youtube.channels.filter'.tr(),
          const Key('youtube-channel-filter'),
        ),
        Expanded(child: body),
      ],
    );
  }
}
