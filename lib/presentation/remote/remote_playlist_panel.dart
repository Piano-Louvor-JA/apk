import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import '../../core/services/remote/remote_protocol.dart';
import '../../core/services/remote/remote_session.dart';

class RemotePlaylistSelection {
  const RemotePlaylistSelection({
    required this.playlistId,
    required this.index,
    required this.musicId,
    required this.mode,
  });
  final String playlistId;
  final int index, musicId;
  final String mode;
}

class RemotePlaylistPanel extends StatefulWidget {
  const RemotePlaylistPanel({
    super.key,
    this.state,
    this.send,
    this.selection,
    this.onSelectionChanged,
  });
  final RemotePlaylistSelection? selection;
  final ValueChanged<RemotePlaylistSelection?>? onSelectionChanged;
  final RemotePlaylistState? state;
  final Future<void> Function(RemoteCommand command)? send;
  @override
  State<RemotePlaylistPanel> createState() => _RemotePlaylistPanelState();
}

class _RemotePlaylistPanelState extends State<RemotePlaylistPanel> {
  String? _selectedId;
  String _mode = 'audio';
  Future<void> _send(
    RemoteAction action, {
    String? targetId,
    int? index,
    bool? enabled,
  }) => (widget.send ?? RemoteSession.instance.send)(
    RemoteCommand(
      id: 'pl${DateTime.now().microsecondsSinceEpoch}',
      action: action,
      targetId: targetId,
      index: index,
      mode: _mode,
      enabled: enabled,
    ),
  );

  bool _pending(RemotePlaylist playlist, int index) =>
      widget.selection?.playlistId == playlist.id &&
      widget.selection?.index == index;
  bool _highlight(RemotePlaylist playlist, int index) =>
      _pending(playlist, index) ||
      widget.state?.currentMusicId == playlist.items[index].musicId;
  void _select(RemotePlaylist playlist, int index) {
    widget.onSelectionChanged?.call(
      _pending(playlist, index)
          ? null
          : RemotePlaylistSelection(
              playlistId: playlist.id,
              index: index,
              musicId: playlist.items[index].musicId,
              mode: _mode,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.state;
    if (model == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'remote.playlist.unavailable'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    RemotePlaylist? selected;
    for (final list in model.lists) {
      if (list.id == _selectedId) selected = list;
    }
    selected ??= model.lists.isEmpty ? null : model.lists.first;
    final playlist = selected;
    final theme = Theme.of(context);
    return Column(
      children: [
        if (model.lists.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: DropdownButtonFormField<String>(
              key: ValueKey('playlist-list-${playlist?.id}'),
              initialValue: playlist?.id,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'remote.tabPlaylist'.tr()),
              items: model.lists
                  .map(
                    (list) => DropdownMenuItem(
                      value: list.id,
                      child: Text(
                        '${list.name} (${list.items.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                setState(() => _selectedId = id);
                widget.onSelectionChanged?.call(null);
              },
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (model.lists.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('remote.playlist.empty'.tr()),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in [
                      ('audio', 'remote.playlist.audio'),
                      ('instrumental', 'remote.playlist.instrumental'),
                      ('no_audio', 'remote.playlist.slides'),
                    ])
                      ChoiceChip(
                        label: Text(option.$2.tr()),
                        selected: _mode == option.$1,
                        onSelected: (_) {
                          setState(() => _mode = option.$1);
                          final selected = widget.selection;
                          if (selected != null) {
                            widget.onSelectionChanged?.call(
                              RemotePlaylistSelection(
                                playlistId: selected.playlistId,
                                index: selected.index,
                                musicId: selected.musicId,
                                mode: _mode,
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('playlist-play'),
                      onPressed: playlist?.items.isNotEmpty == true
                          ? () => _send(
                              RemoteAction.playlistPlay,
                              targetId: playlist!.id,
                            )
                          : null,
                      icon: const Icon(TablerIcons.playerPlay),
                      label: Text('remote.playlist.playAll'.tr()),
                    ),
                    OutlinedButton.icon(
                      key: const Key('playlist-shuffle'),
                      onPressed: playlist?.items.isNotEmpty == true
                          ? () => _send(
                              RemoteAction.playlistShuffle,
                              targetId: playlist!.id,
                            )
                          : null,
                      icon: const Icon(TablerIcons.arrowsShuffle),
                      label: Text('remote.playlist.shuffle'.tr()),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (playlist != null && playlist.items.isEmpty)
                  Text('remote.playlist.emptyList'.tr()),
                if (playlist != null)
                  for (var index = 0; index < playlist.items.length; index++)
                    Card(
                      color: _highlight(playlist, index)
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : null,
                      shape: _highlight(playlist, index)
                          ? RoundedRectangleBorder(
                              side: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 1.5,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                            )
                          : null,
                      child: ListTile(
                        key: Key('playlist-item-$index'),
                        selected: _highlight(playlist, index),
                        selectedColor: theme.colorScheme.primary,
                        leading: Text(
                          '${index + 1}',
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                        title: Text(playlist.items[index].title),
                        onTap: () => _select(playlist, index),
                        trailing:
                            model.currentMusicId ==
                                playlist.items[index].musicId
                            ? Icon(
                                TablerIcons.music,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
