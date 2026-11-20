import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_radius.dart';
import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_downloads.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/empty_state.dart';
import 'package:louvorja_piano_mobile/presentation/youtube/bloc/youtube_cubit.dart';

import 'youtube_sheets.dart';
import 'youtube_reorder.dart';
import 'youtube_video_tile.dart';

typedef YoutubeTileBuilder =
    Widget Function(
      YoutubeVideo video,
      YoutubeState state, {
      List<YoutubeTileAction> extra,
      bool draggable,
    });

/// Coletâneas online: lista (criar, abrir) e a coletânea aberta (renomear,
/// excluir, reordenar, remover, baixar todos / parar).
class YoutubeCollectionsTab extends StatefulWidget {
  const YoutubeCollectionsTab({
    super.key,
    required this.tile,
    required this.opened,
    required this.onImportPlaylist,
    required this.onOpenSearch,
  });

  final YoutubeTileBuilder tile;

  /// Id da coletânea aberta (nulo = lista).
  final ValueNotifier<String?> opened;
  final VoidCallback onImportPlaylist, onOpenSearch;

  @override
  State<YoutubeCollectionsTab> createState() => _YoutubeCollectionsTabState();
}

class _YoutubeCollectionsTabState extends State<YoutubeCollectionsTab> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await context.read<YoutubeCubit>().createCollection(
      _name.text,
    );
    if (created == null) return;
    _name.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  void _open(YoutubeCollection c) {
    widget.opened.value = c.id;
    YoutubeDownloads.instance.refresh(c.videos.map((v) => v.videoId));
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: widget.opened,
    builder: (context, openedId, _) => BlocBuilder<YoutubeCubit, YoutubeState>(
      builder: (context, state) {
        final opened = openedId == null ? null : state.collection(openedId);
        return opened == null ? _list(state) : _detail(state, opened);
      },
    ),
  );

  Widget _list(YoutubeState state) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
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
                  key: const Key('youtube-collection-new'),
                  controller: _name,
                  maxLength: YoutubeLibraryStorage.collectionNameMax,
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: 'youtube.collections.newPlaceholder'.tr(),
                    border: const OutlineInputBorder(
                      borderRadius: AppRadius.md,
                    ),
                  ),
                  onSubmitted: (_) => _create(),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              FilledButton.icon(
                key: const Key('youtube-collection-create'),
                onPressed: _create,
                icon: const Icon(TablerIcons.plus, size: 18),
                label: Text('youtube.collections.create'.tr()),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
            child: TextButton.icon(
              onPressed: widget.onImportPlaylist,
              icon: const Icon(TablerIcons.brandYoutube, size: 18),
              label: Text('youtube.playlist.open'.tr()),
            ),
          ),
        ),
        Expanded(
          child: state.collections.isEmpty
              ? EmptyState(
                  icon: TablerIcons.playlist,
                  title: 'youtube.collections.empty'.tr(),
                )
              : youtubeReorderableList<YoutubeCollection>(
                  key: const Key('youtube-collections-list'),
                  items: state.collections,
                  idOf: (c) => c.id,
                  onMove: context.read<YoutubeCubit>().reorderCollections,
                  itemBuilder: (context, c) {
                    final cover = c.videos.firstOrNull?.toVideo();
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s3,
                        vertical: AppSpacing.s1,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.md,
                      ),
                      child: ListTile(
                        key: Key('youtube-collection-${c.id}'),
                        contentPadding: const EdgeInsets.only(
                          left: AppSpacing.s2,
                          right: AppSpacing.s4,
                        ),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'youtube.actions.dragHint'.tr(),
                              child: Icon(
                                TablerIcons.gripVertical,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 6),
                            CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.16,
                          ),
                          foregroundImage: cover == null
                              ? null
                              : NetworkImage(cover.thumbnailOrDefault),
                          child: Icon(
                            TablerIcons.playlist,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                          ],
                        ),
                        title: Text(c.name),
                        subtitle: Text(
                          'youtube.collections.videoCount'.tr(
                            namedArgs: {'n': '${c.videos.length}'},
                          ),
                        ),
                        trailing: const Icon(TablerIcons.chevronRight),
                        onTap: () => _open(c),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _rename(YoutubeCollection c) async {
    final name = await askYoutubeName(
      context,
      title: 'youtube.collections.rename'.tr(),
      initial: c.name,
    );
    if (name != null && mounted) {
      await context.read<YoutubeCubit>().renameCollection(c.id, name);
    }
  }

  Future<void> _delete(YoutubeCollection c) async {
    final ok = await confirmYoutubeAction(
      context,
      title: 'youtube.collections.deleteTitle'.tr(namedArgs: {'name': c.name}),
      message: 'youtube.collections.deleteMessage'.tr(),
      confirm: 'youtube.collections.deleteConfirm'.tr(),
      confirmKey: const Key('youtube-collection-delete-confirm'),
    );
    if (!ok || !mounted) return;
    YoutubeDownloads.instance.cancelAll(c.videos.map((v) => v.videoId));
    widget.opened.value = null;
    await context.read<YoutubeCubit>().deleteCollection(c.id);
  }

  Widget _detail(YoutubeState state, YoutubeCollection c) {
    final theme = Theme.of(context);
    final cubit = context.read<YoutubeCubit>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s1,
            AppSpacing.s2,
            AppSpacing.s1,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('youtube-collection-back'),
                tooltip: 'youtube.collections.backToList'.tr(),
                onPressed: () => widget.opened.value = null,
                icon: const Icon(TablerIcons.arrowLeft),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      'youtube.collections.videoCount'.tr(
                        namedArgs: {'n': '${c.videos.length}'},
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'youtube.collections.rename'.tr(),
                onPressed: () => _rename(c),
                icon: const Icon(TablerIcons.pencil),
              ),
              IconButton(
                key: const Key('youtube-collection-delete'),
                tooltip: 'youtube.collections.delete'.tr(),
                onPressed: () => _delete(c),
                icon: Icon(TablerIcons.trash, color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
        if (c.videos.isNotEmpty && YoutubeDownloads.supported)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
            child: _DownloadAllBar(collection: c),
          ),
        Expanded(
          child: c.videos.isEmpty
              ? EmptyState(
                  icon: TablerIcons.playlist,
                  title: 'youtube.collections.emptyVideos'.tr(),
                  actionLabel: 'youtube.tabs.search'.tr(),
                  onAction: widget.onOpenSearch,
                )
              : youtubeReorderableList<YoutubeSavedVideo>(
                  key: const Key('youtube-collection-videos'),
                  items: c.videos,
                  idOf: (v) => v.videoId,
                  onMove: (from, to) => cubit.reorderInCollection(c.id, from, to),
                  itemBuilder: (context, saved) {
                    final i = c.videos.indexOf(saved);
                    final video = saved.toVideo();
                    return widget.tile(
                      video,
                      state,
                      draggable: true,
                      extra: [
                        if (i > 0)
                          YoutubeTileAction(
                            icon: TablerIcons.arrowUp,
                            label: 'youtube.collections.moveUp'.tr(),
                            onTap: () =>
                                cubit.moveInCollection(c.id, video.videoId, -1),
                          ),
                        if (i < c.videos.length - 1)
                          YoutubeTileAction(
                            icon: TablerIcons.arrowDown,
                            label: 'youtube.collections.moveDown'.tr(),
                            onTap: () =>
                                cubit.moveInCollection(c.id, video.videoId, 1),
                          ),
                        YoutubeTileAction(
                          icon: TablerIcons.playlistX,
                          label: 'youtube.collections.removeVideo'.tr(),
                          destructive: true,
                          onTap: () =>
                              cubit.removeFromCollection(c.id, video.videoId),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// "Baixar todos (n)" / "Baixando n…" + "Parar" / "Todos baixados".
class _DownloadAllBar extends StatelessWidget {
  const _DownloadAllBar({required this.collection});
  final YoutubeCollection collection;

  @override
  Widget build(BuildContext context) {
    final downloads = YoutubeDownloads.instance;
    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) {
        final videos = collection.videos.map((v) => v.toVideo()).toList();
        final pending = videos
            .where(
              (v) =>
                  downloads.statusOf(v.videoId).phase !=
                  YoutubeDownloadPhase.done,
            )
            .toList();
        final busy = videos.where((v) => downloads.isBusy(v.videoId)).length;
        if (pending.isEmpty) {
          return Row(
            children: [
              Icon(
                TablerIcons.circleCheck,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.s2),
              Text('youtube.download.allDone'.tr()),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                key: const Key('youtube-download-all'),
                onPressed: busy > 0 ? null : () => downloads.download(pending),
                icon: busy > 0
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(TablerIcons.download, size: 18),
                label: Text(
                  busy > 0
                      ? 'youtube.download.allBusy'.tr(namedArgs: {'n': '$busy'})
                      : 'youtube.download.all'.tr(
                          namedArgs: {'n': '${pending.length}'},
                        ),
                ),
              ),
            ),
            if (busy > 0) ...[
              const SizedBox(width: AppSpacing.s2),
              OutlinedButton.icon(
                key: const Key('youtube-download-stop'),
                onPressed: () =>
                    downloads.cancelAll(videos.map((v) => v.videoId)),
                icon: const Icon(TablerIcons.playerStop, size: 18),
                label: Text('youtube.download.stop'.tr()),
              ),
            ],
          ],
        );
      },
    );
  }
}
