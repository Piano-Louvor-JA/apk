import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_radius.dart';
import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_downloads.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

import 'youtube_rename_dialog.dart';

/// Ação extra do menu "⋮" do card.
class YoutubeTileAction {
  const YoutubeTileAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

/// Card de vídeo do módulo YouTube: capa, título, canal e as ações
/// (tocar, favoritar, coletânea, baixar).
class YoutubeVideoTile extends StatelessWidget {
  const YoutubeVideoTile({
    super.key,
    required this.video,
    required this.favorite,
    required this.onPlay,
    required this.onFavorite,
    required this.onAddToCollection,
    this.subtitle,
    this.detail,
    this.leading,
    this.extraActions = const [],
    this.downloads = true,
  });

  final YoutubeVideo video;
  final bool favorite;
  final VoidCallback onPlay, onFavorite, onAddToCollection;

  /// Linha extra (ex.: "3× tocado").
  final String? subtitle;

  /// Linha em destaque (ex.: "Arquivo renomeado: …" na aba Baixados).
  final String? detail;

  /// Antes da capa (ex.: setas de reordenar na coletânea).
  final Widget? leading;
  final List<YoutubeTileAction> extraActions;

  /// Botão de baixar (falso no controle remoto: quem toca é o computador).
  final bool downloads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meta = [
      video.channel,
      video.viewsText,
      video.publishedText,
    ].where((t) => t.isNotEmpty).join(' · ');
    return Card(
      key: Key('youtube-video-${video.videoId}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ?leading,
                  _Thumb(video: video),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (meta.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              meta,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        if (detail != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              key: Key('youtube-detail-${video.videoId}'),
                              children: [
                                Icon(
                                  TablerIcons.filePencil,
                                  size: 14,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    detail!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // Wrap: baixado ganha lixeira e renomear; em tela estreita
              // os botões descem de linha em vez de estourar.
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  IconButton(
                    key: Key('youtube-play-${video.videoId}'),
                    tooltip: 'youtube.actions.play'.tr(),
                    onPressed: onPlay,
                    icon: const Icon(TablerIcons.playerPlay),
                  ),
                  IconButton(
                    key: Key('youtube-favorite-${video.videoId}'),
                    tooltip:
                        (favorite
                                ? 'youtube.favorites.remove'
                                : 'youtube.favorites.add')
                            .tr(),
                    onPressed: onFavorite,
                    isSelected: favorite,
                    icon: Icon(
                      TablerIcons.heart,
                      color: favorite ? scheme.primary : null,
                    ),
                    style: favorite
                        ? IconButton.styleFrom(
                            backgroundColor: scheme.primary.withValues(
                              alpha: 0.16,
                            ),
                          )
                        : null,
                  ),
                  IconButton(
                    key: Key('youtube-add-${video.videoId}'),
                    tooltip: 'youtube.collections.addTo'.tr(),
                    onPressed: onAddToCollection,
                    icon: const Icon(TablerIcons.playlistAdd),
                  ),
                  if (downloads && YoutubeDownloads.supported)
                    YoutubeDownloadButton(video: video),
                  if (extraActions.isNotEmpty)
                    PopupMenuButton<int>(
                      tooltip: 'youtube.actions.more'.tr(),
                      icon: const Icon(TablerIcons.dotsVertical),
                      onSelected: (i) => extraActions[i].onTap(),
                      itemBuilder: (_) => [
                        for (var i = 0; i < extraActions.length; i++)
                          PopupMenuItem(
                            value: i,
                            child: Row(
                              children: [
                                Icon(
                                  extraActions[i].icon,
                                  size: 20,
                                  color: extraActions[i].destructive
                                      ? scheme.error
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.s3),
                                Flexible(child: Text(extraActions[i].label)),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.video});
  final YoutubeVideo video;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = video.live ? 'youtube.search.live'.tr() : video.durationText;
    return ClipRRect(
      borderRadius: AppRadius.sm,
      child: SizedBox(
        width: 128,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailOrDefault,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Icon(
                    TablerIcons.brandYoutube,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (badge.isNotEmpty)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: video.live
                          ? scheme.error
                          : scheme.scrim.withValues(alpha: 0.75),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: video.live ? scheme.onError : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baixar: anel de progresso enquanto baixa (toque cancela), aviso de erro
/// (toque tenta de novo) e, baixado, os botões na ordem do desktop:
/// lixeira, ✓ (também apaga) e renomear.
class YoutubeDownloadButton extends StatelessWidget {
  const YoutubeDownloadButton({super.key, required this.video, this.downloads});
  final YoutubeVideo video;
  final YoutubeDownloads? downloads;

  Future<void> _confirmRemove(BuildContext context, YoutubeDownloads d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('youtube.download.removeTitle'.tr()),
        content: Text(
          'youtube.download.removeMessage'.tr(
            namedArgs: {'title': video.title},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            key: const Key('youtube-download-remove-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text('youtube.download.removeConfirm'.tr()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final removed = await d.remove(video.videoId);
    if (!removed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('youtube.download.removeFailed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = downloads ?? YoutubeDownloads.instance;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) {
        final status = d.statusOf(video.videoId);
        switch (status.phase) {
          case YoutubeDownloadPhase.queued:
          case YoutubeDownloadPhase.downloading:
            final percent = ((status.progress ?? 0) * 100).round();
            return IconButton(
              key: Key('youtube-download-${video.videoId}'),
              tooltip: status.phase == YoutubeDownloadPhase.queued
                  ? '${'youtube.download.queued'.tr()} · ${'youtube.download.cancel'.tr()}'
                  : '${'youtube.download.progress'.tr(namedArgs: {'n': '$percent'})} · ${'youtube.download.cancel'.tr()}',
              onPressed: () => d.cancel(video.videoId),
              icon: SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2.5,
                      value: status.phase == YoutubeDownloadPhase.queued
                          ? 0
                          : status.progress,
                    ),
                    const Icon(TablerIcons.x, size: 12),
                  ],
                ),
              ),
            );
          case YoutubeDownloadPhase.done:
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('youtube-download-remove-${video.videoId}'),
                  tooltip: 'youtube.download.remove'.tr(),
                  onPressed: () => _confirmRemove(context, d),
                  icon: const Icon(TablerIcons.trash),
                ),
                IconButton(
                  key: Key('youtube-download-${video.videoId}'),
                  tooltip:
                      '${'youtube.download.done'.tr()} · ${'youtube.download.remove'.tr()}',
                  onPressed: () => _confirmRemove(context, d),
                  icon: Icon(TablerIcons.circleCheck, color: scheme.primary),
                ),
                IconButton(
                  key: Key('youtube-download-rename-${video.videoId}'),
                  tooltip: 'youtube.download.rename'.tr(),
                  onPressed: () =>
                      showYoutubeRenameDialog(context, video, downloads: d),
                  icon: const Icon(TablerIcons.pencil),
                ),
              ],
            );
          case YoutubeDownloadPhase.failed:
            return IconButton(
              key: Key('youtube-download-${video.videoId}'),
              tooltip: 'youtube.download.failed'.tr(),
              onPressed: () => d.download([video]),
              icon: Icon(TablerIcons.alertTriangle, color: scheme.error),
            );
          case YoutubeDownloadPhase.none:
            return IconButton(
              key: Key('youtube-download-${video.videoId}'),
              tooltip: 'youtube.download.action'.tr(),
              onPressed: () => d.download([video]),
              icon: const Icon(TablerIcons.download),
            );
        }
      },
    );
  }
}
