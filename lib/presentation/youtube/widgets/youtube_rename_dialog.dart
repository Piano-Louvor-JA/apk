import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_radius.dart';
import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_downloads.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_file_name.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

/// "Renomear arquivo baixado" (paridade com o desktop): edita o nome e
/// mostra na hora como ele fica (sem acento nem símbolo, com o código do
/// vídeo no fim). Devolve o nome novo do arquivo, ou nulo.
Future<String?> showYoutubeRenameDialog(
  BuildContext context,
  YoutubeVideo video, {
  YoutubeDownloads? downloads,
}) async {
  final d = downloads ?? YoutubeDownloads.instance;
  await d.loadIndex();
  if (!context.mounted) return null;
  final current = d.fileNameOf(video);
  final initial = editableYoutubeTitle(current, video.videoId);
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(
      video: video,
      current: current,
      initial: initial.isEmpty ? sanitizeYoutubeTitle(video.title) : initial,
    ),
  );
  if (name == null || !context.mounted) return null;
  final messenger = ScaffoldMessenger.of(context);
  final fileName = await d.rename(video, name);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          fileName == null
              ? 'youtube.download.renameFailed'.tr()
              : 'youtube.download.renamed'.tr(namedArgs: {'name': fileName}),
        ),
      ),
    );
  return fileName;
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({
    required this.video,
    required this.current,
    required this.initial,
  });
  final YoutubeVideo video;
  final String current, initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final preview = youtubeFileName(_controller.text, widget.video.videoId);
    // Sem mudança: só fecha.
    Navigator.pop(context, preview == widget.current ? null : _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(TablerIcons.pencil, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.s2),
          Expanded(child: Text('youtube.download.renameTitle'.tr())),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            TextField(
              key: const Key('youtube-rename-field'),
              controller: _controller,
              autofocus: true,
              maxLength: youtubeFileTitleMax * 2,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirm(),
              decoration: InputDecoration(
                labelText: 'youtube.download.renameLabel'.tr(),
                border: const OutlineInputBorder(borderRadius: AppRadius.md),
                helperText: 'youtube.download.renameHint'.tr(
                  namedArgs: {'n': '$youtubeFileTitleMax'},
                ),
                helperMaxLines: 4,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: AppRadius.md,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'youtube.download.renamePreview'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      youtubeFileName(_controller.text, widget.video.videoId),
                      key: const Key('youtube-rename-preview'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton.icon(
          key: const Key('youtube-rename-confirm'),
          onPressed: _confirm,
          icon: const Icon(TablerIcons.check, size: 18),
          label: Text('youtube.download.renameConfirm'.tr()),
        ),
      ],
    );
  }
}
