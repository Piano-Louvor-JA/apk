import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/playlist_storage.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/album_detail_page.dart';

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

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome',
            helperText: 'Ex.: Culto de sábado',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    await _storage.create(name);
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
        title: Text('Excluir "${playlist.name}"?'),
        content: const Text(
          'A playlist é só a seleção de hinos — os hinos do acervo não são '
          'apagados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Nova playlist'),
      ),
      body: _playlists == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : _playlists!.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Nenhuma playlist ainda.\n\n'
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
              itemCount: _playlists!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = _playlists![index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: Text(p.name),
                    subtitle: Text('${p.items.length} hinos'),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailPage(playlistId: p.id),
                        ),
                      );
                      _load();
                    },
                    trailing: PopupMenuButton<String>(
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'rename', child: Text('Renomear')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                      onSelected: (value) {
                        if (value == 'rename') _rename(p);
                        if (value == 'delete') _delete(p);
                      },
                    ),
                  ),
                );
              },
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
    await _storage.removeItem(widget.playlistId, index);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _playlist;
    return Scaffold(
      appBar: AppBar(title: Text(playlist?.name ?? 'Playlist')),
      body: playlist == null
          ? const Center(child: Text('Playlist não encontrada.'))
          : playlist.items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Playlist vazia.\n\nAbra um hino do acervo e use '
                  '"Adicionar à playlist".',
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
                  leading: Text('${index + 1}'),
                  title: Text(item.title),
                  subtitle: item.albumId == null
                      ? null
                      : Text('Álbum ${item.albumId}'),
                  onTap: () {
                    if (item.albumId == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AlbumDetailPage(albumId: item.albumId!),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Remover da playlist',
                    onPressed: () => _removeItem(index),
                  ),
                );
              },
            ),
    );
  }
}
