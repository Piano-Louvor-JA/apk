import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/core/services/download_url_builder.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_catalog_provider.dart';
import 'package:louvorja_piano_mobile/core/services/playlist_player.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/playlist_io.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/playlist_storage.dart';
import 'package:louvorja_piano_mobile/presentation/playlists/playlist_sheets.dart';

/// Playlists: seleção de hinos do ACERVO, salva no dispositivo.
/// Paridade com a /media do web (playlist-storage). DIFERENTE de
/// coletânea personalizada (que é conteúdo do usuário via API).
class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  final _storage = PlaylistStorage();
  List<Playlist>? _playlists;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _storage.list();
      if (!mounted) return;
      setState(() {
        _playlists = list;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível carregar as playlists.');
    }
  }

  final _newName = TextEditingController();

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  /// Criação inline (paridade desktop: "Nome da nova playlist..." + Criar).
  Future<void> _create() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    await _storage.create(name);
    _newName.clear();
    if (mounted) FocusScope.of(context).unfocus();
    _load();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Exporta no formato do desktop (abre no app e vice-versa).
  Future<void> _export() async {
    final list = _playlists ?? const <Playlist>[];
    if (list.isEmpty) {
      _toast('Nenhuma playlist para exportar.');
      return;
    }
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final saved = await FilePicker.saveFile(
        fileName: 'playlists-$today.json',
        bytes: Uint8List.fromList(utf8.encode(PlaylistIo.encode(list))),
      );
      if (saved != null) _toast('Playlists exportadas.');
    } catch (_) {
      _toast('Não foi possível exportar as playlists.');
    }
  }

  /// Importa e mescla por nome (igual ao desktop).
  Future<void> _import() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;
    final String raw;
    try {
      raw = utf8.decode(await file.readAsBytes());
    } catch (_) {
      _toast('Arquivo de playlists inválido.');
      return;
    }
    final imported = PlaylistIo.decode(raw);
    if (imported == null) {
      _toast('Arquivo de playlists inválido.');
      return;
    }
    final (merged, newLists, tracks) = PlaylistIo.merge(
      await _storage.list(),
      imported,
    );
    await _storage.saveAll(merged);
    final parts = [
      if (newLists > 0) '$newLists playlist(s) nova(s)',
      if (tracks > 0) '$tracks faixa(s) adicionada(s)',
    ];
    _toast(
      parts.isEmpty ? 'Nada novo para importar.' : 'Importado: ${parts.join(', ')}.',
    );
    _load();
  }

  Future<void> _addMusic(Playlist playlist) async {
    await showAddMusicSheet(context, playlist.id);
    _load();
  }

  Future<void> _openDetail(Playlist playlist) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaylistDetailPage(playlistId: playlist.id),
      ),
    );
    _load();
  }

  Future<void> _rename(Playlist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear playlist'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || name == playlist.name) return;
    await _storage.rename(playlist.id, name);
    _load();
  }

  Future<void> _delete(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir playlist “${playlist.name}”?'),
        content: const Text(
          'A playlist será excluída. As músicas e os arquivos baixados '
          'serão mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir playlist'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.delete(playlist.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = _playlists;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            key: const Key('playlists-import'),
            icon: const Icon(TablerIcons.upload),
            tooltip: 'Importar playlists',
            onPressed: _import,
          ),
          IconButton(
            key: const Key('playlists-export'),
            icon: const Icon(TablerIcons.download),
            tooltip: 'Exportar playlists',
            onPressed: _export,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('playlists-new-name'),
                    controller: _newName,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _create(),
                    decoration: const InputDecoration(
                      hintText: 'Nome da nova playlist...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('playlists-create'),
                  onPressed: _create,
                  icon: const Icon(TablerIcons.plus, size: 18),
                  label: const Text('Criar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: list == null && _error == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(TablerIcons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  )
                : list!.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(TablerIcons.playlist, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Nenhuma playlist criada ainda.\n\n'
                            'Playlist é a sua seleção de hinos do acervo — '
                            'diferente das coletâneas da comunidade.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = list[index];
                      final empty = p.items.isEmpty;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openDetail(p),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        TablerIcons.playlist,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          Text(
                                            '${p.items.length} faixa(s)',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(TablerIcons.chevronRight),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(TablerIcons.pencil),
                                      tooltip: 'Renomear playlist',
                                      onPressed: () => _rename(p),
                                    ),
                                    IconButton(
                                      icon: const Icon(TablerIcons.plus),
                                      tooltip: 'Adicionar músicas',
                                      onPressed: () => _addMusic(p),
                                    ),
                                    IconButton(
                                      icon: const Icon(TablerIcons.arrowsShuffle),
                                      tooltip: 'Tocar aleatório',
                                      onPressed: empty
                                          ? null
                                          : () => PlaylistPlayer.instance.play(
                                              context,
                                              p,
                                              shuffle: true,
                                            ),
                                    ),
                                    IconButton(
                                      icon: const Icon(TablerIcons.playerPlay),
                                      tooltip: 'Tocar playlist',
                                      onPressed: empty
                                          ? null
                                          : () => PlaylistPlayer.instance.play(
                                              context,
                                              p,
                                            ),
                                    ),
                                    IconButton(
                                      icon: const Icon(TablerIcons.trash),
                                      tooltip: 'Excluir playlist',
                                      onPressed: () => _delete(p),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Detalhe: faixas da playlist + abrir o hino do acervo ao tocar.
class PlaylistDetailPage extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailPage({super.key, required this.playlistId});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final _storage = PlaylistStorage();
  Playlist? _playlist;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _storage.list();
    if (!mounted) return;
    setState(() {
      _playlist = list.where((p) => p.id == widget.playlistId).firstOrNull;
    });
  }

  Future<void> _removeItem(int index) async {
    final item = _playlist?.items.elementAtOrNull(index);
    if (item == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover da playlist?'),
        content: Text(
          '“${item.title}” sai de “${_playlist!.name}”. A música e os '
          'arquivos baixados continuam no acervo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.removeItem(widget.playlistId, index);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _playlist;
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist?.name ?? 'Playlist'),
        actions: playlist == null
            ? null
            : [
                IconButton(
                  icon: const Icon(TablerIcons.plus),
                  tooltip: 'Adicionar músicas',
                  onPressed: () async {
                    await showAddMusicSheet(context, playlist.id);
                    _load();
                  },
                ),
                IconButton(
                  icon: const Icon(TablerIcons.arrowsShuffle),
                  tooltip: 'Tocar aleatório',
                  onPressed: playlist.items.isEmpty
                      ? null
                      : () => PlaylistPlayer.instance.play(
                          context,
                          playlist,
                          shuffle: true,
                        ),
                ),
                IconButton(
                  icon: const Icon(TablerIcons.playerPlay),
                  tooltip: 'Tocar playlist',
                  onPressed: playlist.items.isEmpty
                      ? null
                      : () => PlaylistPlayer.instance.play(context, playlist),
                ),
              ],
      ),
      body: playlist == null
          ? const Center(child: Text('Playlist não encontrada.'))
          : playlist.items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Playlist vazia.\n\nToque em + para buscar músicas, ou use '
                  'o ícone de playlist nos resultados da busca de Hinos.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ReorderableListView.builder(
              itemCount: playlist.items.length,
              onReorder: (oldIndex, newIndex) async {
                final items = [...playlist.items];
                if (newIndex > oldIndex) newIndex -= 1;
                final moved = items.removeAt(oldIndex);
                items.insert(newIndex, moved);
                await _storage.saveAll(
                  [...await _storage.list()]
                      .map((p) => p.id == playlist.id ? p.withItems(items) : p)
                      .toList(),
                );
                _load();
              },
              itemBuilder: (context, index) {
                final item = playlist.items[index];
                return ListTile(
                  key: ValueKey('${item.musicId}-${item.albumId}-$index'),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${index + 1}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ItemCover(albumId: item.albumId),
                    ],
                  ),
                  title: Text(item.title),
                  // Toque toca a playlist a partir desta faixa.
                  onTap: () => PlaylistPlayer.instance.play(
                    context,
                    playlist,
                    startAt: index,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(TablerIcons.x),
                        tooltip: 'Remover da playlist',
                        onPressed: () => _removeItem(index),
                      ),
                      const Icon(TablerIcons.gripVertical, size: 18),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Capinha da coletânea da faixa (mesma capa usada no álbum e na busca).
class _ItemCover extends StatelessWidget {
  final int? albumId;

  const _ItemCover({required this.albumId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const size = 40.0;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        TablerIcons.music,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final id = albumId;
    final cover = id == null ? null : hymnCatalogProvider.albumCoverById(id);
    if (cover == null || cover.isEmpty) return placeholder;
    final Widget image = cover.startsWith('asset:')
        ? Image.asset(
            cover.substring('asset:'.length),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          )
        // coverage:ignore-start
        : CachedNetworkImage(
            imageUrl: DownloadUrlBuilder.build(cover),
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
    // coverage:ignore-end
    return ClipRRect(borderRadius: BorderRadius.circular(6), child: image);
  }
}
