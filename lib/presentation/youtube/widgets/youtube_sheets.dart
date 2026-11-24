import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_radius.dart';
import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_channel_parser.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_downloads.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/presentation/youtube/bloc/youtube_cubit.dart';

/// Confirmação padrão (Cancelar / ação). true = confirmou.
Future<bool> confirmYoutubeAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  Key? confirmKey,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          key: confirmKey,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Pergunta um nome (renomear coletânea). Nulo = cancelou.
Future<String?> askYoutubeName(
  BuildContext context, {
  required String title,
  required String initial,
}) async {
  final controller = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const Key('youtube-name-field'),
        controller: controller,
        autofocus: true,
        maxLength: YoutubeLibraryStorage.collectionNameMax,
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text('common.save'.tr()),
        ),
      ],
    ),
  );
  controller.dispose();
  return name;
}

void showYoutubeToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// "Adicionar à coletânea": marca/desmarca cada coletânea e permite criar
/// uma nova já com o vídeo.
Future<void> showYoutubeCollectionPicker(
  BuildContext context,
  YoutubeVideo video,
) {
  final cubit = context.read<YoutubeCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _CollectionPicker(video: video),
    ),
  );
}

class _CollectionPicker extends StatefulWidget {
  const _CollectionPicker({required this.video});
  final YoutubeVideo video;

  @override
  State<_CollectionPicker> createState() => _CollectionPickerState();
}

class _CollectionPickerState extends State<_CollectionPicker> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _createAndAdd() async {
    final cubit = context.read<YoutubeCubit>();
    final created = await cubit.createCollection(_name.text);
    if (created == null) return;
    await cubit.addToCollection(created.id, widget.video);
    _name.clear();
    if (mounted) {
      showYoutubeToast(
        context,
        'youtube.collections.added'.tr(namedArgs: {'name': created.name}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s4,
        right: AppSpacing.s4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.s4,
      ),
      child: BlocBuilder<YoutubeCubit, YoutubeState>(
        builder: (context, state) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'youtube.collections.addTo'.tr(),
              style: theme.textTheme.titleMedium,
            ),
            Text(
              widget.video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.s3),
            if (state.collections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                child: Text('youtube.collections.pickerEmpty'.tr()),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in state.collections)
                      CheckboxListTile(
                        key: Key('youtube-picker-${c.id}'),
                        value: c.has(widget.video.videoId),
                        title: Text(c.name),
                        subtitle: Text(
                          'youtube.collections.videoCount'.tr(
                            namedArgs: {'n': '${c.videos.length}'},
                          ),
                        ),
                        onChanged: (checked) {
                          final cubit = context.read<YoutubeCubit>();
                          if (checked == true) {
                            cubit.addToCollection(c.id, widget.video);
                          } else {
                            cubit.removeFromCollection(
                              c.id,
                              widget.video.videoId,
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('youtube-picker-new'),
                    controller: _name,
                    maxLength: YoutubeLibraryStorage.collectionNameMax,
                    decoration: InputDecoration(
                      hintText: 'youtube.collections.newPlaceholder'.tr(),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _createAndAdd(),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                FilledButton.icon(
                  key: const Key('youtube-picker-create'),
                  onPressed: _createAndAdd,
                  icon: const Icon(TablerIcons.plus, size: 18),
                  label: Text('youtube.collections.createAndAdd'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Colar playlist do YouTube → nome da coletânea → cria.
Future<YoutubeCollection?> showYoutubePlaylistImport(BuildContext context) {
  final cubit = context.read<YoutubeCubit>();
  return showDialog<YoutubeCollection>(
    context: context,
    builder: (_) =>
        BlocProvider.value(value: cubit, child: const _PlaylistImport()),
  );
}

class _PlaylistImport extends StatefulWidget {
  const _PlaylistImport();

  @override
  State<_PlaylistImport> createState() => _PlaylistImportState();
}

class _PlaylistImportState extends State<_PlaylistImport> {
  final _url = TextEditingController();
  final _name = TextEditingController();
  bool _loading = false, _naming = false;
  String? _errorKey;
  List<YoutubeVideo> _items = const [];
  String _title = '';
  int _seq = 0;

  @override
  void dispose() {
    _seq++;
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  String _lastUrl = '';

  /// Botão "Colar": link de playlist já é lido, sem precisar de "Continuar".
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() => _url.text = _lastUrl = text);
    if (YoutubeChannelParser.isPlaylistLink(text)) unawaited(_load());
  }

  /// Colou (o texto cresceu de uma vez) um link de playlist: lê na hora.
  void _onUrlChanged(String value) {
    final pasted = value.length - _lastUrl.length > 1;
    _lastUrl = value;
    if (pasted && !_loading && YoutubeChannelParser.isPlaylistLink(value)) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final text = _url.text.trim();
    if (text.isEmpty) return;
    final mine = ++_seq;
    setState(() {
      _loading = true;
      _errorKey = null;
    });
    final result = await context.read<YoutubeCubit>().fetchPlaylist(text);
    if (!mounted || mine != _seq) return;
    if (result.items.isEmpty) {
      setState(() {
        _loading = false;
        _errorKey = switch (result.error) {
          'invalid' => 'youtube.playlist.invalid',
          'empty' => 'youtube.playlist.empty',
          _ => 'youtube.playlist.error',
        };
      });
      return;
    }
    setState(() {
      _loading = false;
      _naming = true;
      _items = result.items;
      _title = result.title;
      _name.text = result.title.isNotEmpty
          ? result.title
          : 'youtube.playlist.defaultName'.tr();
    });
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _items.isEmpty) return;
    final created = await context.read<YoutubeCubit>().createFromPlaylist(
      name,
      _items,
    );
    if (mounted) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(TablerIcons.brandYoutube, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.s2),
          Expanded(child: Text('youtube.playlist.title'.tr())),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: _naming ? _nameStep(theme) : _urlStep(theme),
      ),
      actions: _naming
          ? [
              TextButton.icon(
                onPressed: () => setState(() => _naming = false),
                icon: const Icon(TablerIcons.arrowLeft, size: 18),
                label: Text('youtube.playlist.back'.tr()),
              ),
              FilledButton.icon(
                key: const Key('youtube-playlist-create'),
                onPressed: _create,
                icon: const Icon(TablerIcons.playlistAdd, size: 18),
                label: Text('youtube.playlist.create'.tr()),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton.icon(
                key: const Key('youtube-playlist-load'),
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(TablerIcons.arrowRight, size: 18),
                label: Text(
                  (_loading
                          ? 'youtube.playlist.loading'
                          : 'youtube.playlist.next')
                      .tr(),
                ),
              ),
            ],
    );
  }

  Widget _urlStep(ThemeData theme) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('youtube.playlist.urlHint'.tr(), style: theme.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.s3),
      TextField(
        key: const Key('youtube-playlist-url'),
        controller: _url,
        enabled: !_loading,
        autofocus: true,
        keyboardType: TextInputType.url,
        onChanged: _onUrlChanged,
        decoration: InputDecoration(
          hintText: 'youtube.playlist.urlPlaceholder'.tr(),
          suffixIcon: IconButton(
            tooltip: 'youtube.playlist.paste'.tr(),
            onPressed: _loading ? null : _paste,
            icon: const Icon(TablerIcons.clipboard),
          ),
        ),
        onSubmitted: (_) => _load(),
      ),
      if (_errorKey != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s2),
          child: Text(
            _errorKey!.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
    ],
  );

  Widget _nameStep(ThemeData theme) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: AppRadius.md,
        ),
        child: Row(
          children: [
            Icon(TablerIcons.playlist, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title.isNotEmpty
                        ? _title
                        : 'youtube.playlist.defaultName'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    'youtube.playlist.found'.tr(
                      namedArgs: {'n': '${_items.length}'},
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.s3),
      TextField(
        key: const Key('youtube-playlist-name'),
        controller: _name,
        autofocus: true,
        maxLength: YoutubeLibraryStorage.collectionNameMax,
        decoration: InputDecoration(
          labelText: 'youtube.playlist.nameLabel'.tr(),
        ),
        onSubmitted: (_) => _create(),
      ),
    ],
  );
}

/// Espaço usado pelos vídeos baixados, a lista deles com a lixeira de cada
/// um e "Apagar todos". [known] são os vídeos que o módulo conhece
/// (busca, histórico, favoritos, coletâneas): é deles que vêm os títulos.
Future<void> showYoutubeStorageSheet(
  BuildContext context, {
  List<YoutubeVideo> known = const [],
  YoutubeDownloads? downloads,
}) {
  final d = downloads ?? YoutubeDownloads.instance;
  final byId = <String, YoutubeVideo>{};
  for (final video in known) {
    byId.putIfAbsent(video.videoId, () => video);
  }
  unawaited(d.refresh(byId.keys));
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: d,
      builder: (context, _) {
        final theme = Theme.of(context);
        final saved = byId.values
            .where(
              (v) => d.statusOf(v.videoId).phase == YoutubeDownloadPhase.done,
            )
            .toList();
        final others = d.totalVideos - saved.length;

        Future<void> removeOne(YoutubeVideo video) async {
          final ok = await confirmYoutubeAction(
            context,
            title: 'youtube.download.removeTitle'.tr(),
            message: 'youtube.download.removeMessage'.tr(
              namedArgs: {'title': video.title},
            ),
            confirm: 'youtube.download.removeConfirm'.tr(),
            confirmKey: const Key('youtube-storage-remove-confirm'),
          );
          if (!ok) return;
          final removed = await d.remove(video.videoId);
          if (!removed && context.mounted) {
            showYoutubeToast(context, 'youtube.download.removeFailed'.tr());
          }
        }

        Future<void> removeAll() async {
          final ok = await confirmYoutubeAction(
            context,
            title: 'youtube.storage.removeAllTitle'.tr(),
            message: 'youtube.storage.removeAllMessage'.tr(
              namedArgs: {'n': '${saved.length}'},
            ),
            confirm: 'youtube.download.removeConfirm'.tr(),
            confirmKey: const Key('youtube-storage-remove-all-confirm'),
          );
          if (!ok) return;
          for (final video in saved) {
            await d.remove(video.videoId);
          }
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              0,
              AppSpacing.s4,
              AppSpacing.s6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'youtube.storage.title'.tr(),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.s3),
                Row(
                  children: [
                    Icon(
                      TablerIcons.database,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Text(
                        'youtube.storage.total'.tr(
                          namedArgs: {
                            'n': '${d.totalVideos}',
                            'size': formatYoutubeBytes(d.totalBytes),
                          },
                        ),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (saved.length > 1)
                      TextButton.icon(
                        key: const Key('youtube-storage-remove-all'),
                        onPressed: removeAll,
                        icon: const Icon(TablerIcons.trash, size: 18),
                        label: Text('youtube.storage.removeAll'.tr()),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                if (saved.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s3,
                    ),
                    child: Text(
                      'youtube.storage.empty'.tr(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: saved.length,
                      itemBuilder: (context, i) {
                        final video = saved[i];
                        return ListTile(
                          key: Key('youtube-storage-item-${video.videoId}'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(TablerIcons.video),
                          title: Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            formatYoutubeBytes(d.statusOf(video.videoId).bytes),
                          ),
                          trailing: IconButton(
                            key: Key('youtube-storage-remove-${video.videoId}'),
                            tooltip: 'youtube.download.remove'.tr(),
                            onPressed: () => removeOne(video),
                            icon: Icon(
                              TablerIcons.trash,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (others > 0) ...[
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'youtube.storage.others'.tr(namedArgs: {'n': '$others'}),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.s3),
                Text(
                  'youtube.storage.where'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
