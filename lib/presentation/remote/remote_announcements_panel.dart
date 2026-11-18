import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../core/services/remote/remote_protocol.dart';
import '../../core/services/remote/remote_session.dart';
import '../../app/theme/app_spacing.dart';

/// Controle dos anúncios do desktop conectado, sem catálogo local no APK.
class RemoteAnnouncementsPanel extends StatelessWidget {
  const RemoteAnnouncementsPanel({super.key, this.state, this.send});
  final RemoteAnnouncementsState? state;
  final Future<void> Function(RemoteCommand command)? send;

  Future<void> _send(
    RemoteAction action, {
    String? targetId,
    bool? enabled,
    int? durationMs,
  }) => (send ?? RemoteSession.instance.send)(
    RemoteCommand(
      id: 'ann${DateTime.now().microsecondsSinceEpoch}',
      action: action,
      targetId: targetId,
      enabled: enabled,
      durationMs: durationMs,
    ),
  );

  Future<void> _editDuration(BuildContext context, int currentMs) async {
    var input = '${currentMs ~/ 1000}';
    final form = GlobalKey<FormState>();
    final seconds = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('remote.announcements.seconds'.tr()),
        content: Form(
          key: form,
          child: TextFormField(
            key: const Key('announcements-seconds-input'),
            initialValue: input,
            onChanged: (value) => input = value,
            autofocus: true,
            keyboardType: TextInputType.number,
            validator: (raw) {
              final value = int.tryParse(raw ?? '');
              return value == null || value < 2 || value > 600
                  ? 'remote.announcements.durationRange'.tr()
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, int.parse(input));
              }
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    if (seconds != null) {
      await _send(
        RemoteAction.announcementsSetCarousel,
        durationMs: seconds * 1000,
      );
    }
  }

  IconData _icon(String kind) => switch (kind) {
    'text' => TablerIcons.alignLeft,
    'images' => TablerIcons.photo,
    'video' => TablerIcons.video,
    'presentation' => TablerIcons.presentation,
    'url' => TablerIcons.link,
    _ => TablerIcons.speakerphone,
  };

  @override
  Widget build(BuildContext context) {
    final model = state;
    if (model == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'remote.announcements.unavailable'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final items = model.activeList?.items ?? const <RemoteAnnouncement>[];
    final eligible = items.any(
      (item) => item.inCarousel && (item.kind == 'text' || item.fileCount > 0),
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('announcements-list-${model.activeList?.id}'),
          initialValue: model.activeList?.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'remote.announcements.list'.tr(),
          ),
          items: model.lists
              .map(
                (list) => DropdownMenuItem(
                  value: list.id,
                  child: Text(
                    list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id != null) {
              _send(RemoteAction.announcementsSelectList, targetId: id);
            }
          },
        ),
        const SizedBox(height: AppSpacing.s3),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('remote.announcements.empty'.tr()),
          ),
        for (final item in items)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              leading: Icon(_icon(item.kind), color: theme.colorScheme.primary),
              title: Text(
                item.title.isEmpty
                    ? 'remote.announcements.kinds.${item.kind}'.tr()
                    : item.title,
              ),
              subtitle: Text(
                item.text.isNotEmpty
                    ? item.text
                    : item.fileName.isNotEmpty
                    ? item.fileName
                    : '${'remote.announcements.kinds.${item.kind}'.tr()}${item.kind == 'images' ? ' · ${item.fileCount}' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: item.text.isEmpty
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          item.title,
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                        content: SingleChildScrollView(
                          child: SelectableText(item.text),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('common.close'.tr()),
                          ),
                        ],
                      ),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.supportsCarousel)
                    IconButton(
                      key: Key('announcement-include-${item.id}'),
                      tooltip: 'remote.announcements.include'.tr(),
                      icon: Icon(
                        item.inCarousel
                            ? TablerIcons.photoCheck
                            : TablerIcons.photoOff,
                        color: item.inCarousel
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      onPressed: () => _send(
                        RemoteAction.announcementsInclude,
                        targetId: item.id,
                        enabled: !item.inCarousel,
                      ),
                    ),
                  IconButton(
                    key: Key('announcement-open-${item.id}'),
                    tooltip: 'remote.announcements.open'.tr(),
                    icon: Icon(
                      TablerIcons.playerPlay,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => _send(
                      RemoteAction.announcementsOpen,
                      targetId: item.id,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.s3),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'remote.announcements.carousel'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (model.active) ...[
                  const SizedBox(height: 12),
                  Text(
                    model.previewTitle,
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                  if (model.previewText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(model.previewText),
                    ),
                  Text(
                    '${model.slideCount > 0 ? model.slideIndex + 1 : 0} / ${model.slideCount}',
                    textAlign: TextAlign.center,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'remote.previousSlide'.tr(),
                        icon: const Icon(TablerIcons.chevronLeft),
                        onPressed: () =>
                            _send(RemoteAction.announcementsPrevious),
                      ),
                      IconButton.filled(
                        key: Key(
                          model.status == 'playing'
                              ? 'announcements-pause'
                              : 'announcements-resume',
                        ),
                        tooltip:
                            (model.status == 'playing'
                                    ? 'remote.pause'
                                    : 'remote.play')
                                .tr(),
                        icon: Icon(
                          model.status == 'playing'
                              ? TablerIcons.playerPause
                              : TablerIcons.playerPlay,
                        ),
                        onPressed: () => _send(
                          model.status == 'playing'
                              ? RemoteAction.announcementsPause
                              : RemoteAction.announcementsResume,
                        ),
                      ),
                      IconButton(
                        tooltip: 'remote.nextSlide'.tr(),
                        icon: const Icon(TablerIcons.chevronRight),
                        onPressed: () => _send(RemoteAction.announcementsNext),
                      ),
                      IconButton(
                        key: const Key('announcements-stop'),
                        tooltip: 'common.stop'.tr(),
                        icon: const Icon(TablerIcons.square),
                        onPressed: () => _send(RemoteAction.announcementsStop),
                      ),
                    ],
                  ),
                ] else
                  FilledButton.icon(
                    key: const Key('announcements-start'),
                    onPressed: eligible
                        ? () => _send(RemoteAction.announcementsStart)
                        : null,
                    icon: const Icon(TablerIcons.playerPlay),
                    label: Text('remote.announcements.start'.tr()),
                  ),
                TextButton.icon(
                  key: const Key('announcements-duration'),
                  onPressed: () => _editDuration(context, model.slideMs),
                  icon: const Icon(TablerIcons.clock),
                  label: Text(
                    '${'remote.announcements.seconds'.tr()}: ${model.slideMs / 1000}',
                  ),
                ),
                CheckboxListTile(
                  key: const Key('announcements-loop'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('remote.announcements.loop'.tr()),
                  value: model.loop,
                  onChanged: (value) {
                    if (value != null) {
                      _send(
                        RemoteAction.announcementsSetCarousel,
                        enabled: value,
                      );
                    }
                  },
                ),
                Text(
                  'remote.announcements.carouselHint'.tr(),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
