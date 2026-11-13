library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../core/services/hymn_catalog_access.dart';
import '../../data/datasources/local/playlist_storage.dart';
import '../../domain/entities/hymn.dart';

String _languageOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'es' ? 'es' : 'pt';

PlaylistItem playlistItemOf(Hymn hymn) => PlaylistItem(
  musicId: hymn.id,
  albumId: hymn.albumIds.isEmpty ? null : hymn.albumIds.first,
  title: hymn.title ?? 'Hino #${hymn.id}',
);

/// "+" da playlist (paridade desktop "Adicionar músicas"): busca no acervo
/// com o mesmo critério da busca de Hinos e adiciona com um toque.
Future<void> showAddMusicSheet(BuildContext context, String playlistId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddMusicSheet(
      playlistId: playlistId,
      language: _languageOf(context),
    ),
  );
}

class _AddMusicSheet extends StatefulWidget {
  final String playlistId;
  final String language;

  const _AddMusicSheet({required this.playlistId, required this.language});

  @override
  State<_AddMusicSheet> createState() => _AddMusicSheetState();
}

class _AddMusicSheetState extends State<_AddMusicSheet> {
  final _storage = PlaylistStorage();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Hymn> _results = const [];
  Set<int> _inPlaylist = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshPlaylist();
  }

  Future<void> _refreshPlaylist() async {
    final list = await _storage.list();
    final p = list.where((e) => e.id == widget.playlistId).firstOrNull;
    if (mounted) {
      setState(() => _inPlaylist = {...?p?.items.map((i) => i.musicId)});
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _loading = true);
      try {
        final repo = await HymnCatalogAccess.repository(widget.language);
        final r = await repo.searchHymns(q);
        if (mounted) setState(() => _results = r);
      } catch (_) {
        if (mounted) setState(() => _results = const []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _add(Hymn hymn) async {
    await _storage.addItem(widget.playlistId, playlistItemOf(hymn));
    await _refreshPlaylist();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Adicionar músicas',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(TablerIcons.search),
                  hintText: 'Nome, número ou trecho da música',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _controller.text.trim().isEmpty
                              ? 'Digite o nome, número ou trecho da música '
                                    'para pesquisar.'
                              : 'Nenhuma música encontrada',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final h = _results[i];
                        final added = _inPlaylist.contains(h.id);
                        return ListTile(
                          leading: SizedBox(
                            width: 36,
                            child: Text(
                              h.number != null ? '${h.number}' : '—',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          title: Text(
                            h.title ?? 'Hino #${h.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: (h.albumNames ?? '').isEmpty
                              ? null
                              : Text(
                                  h.albumNames!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: added
                              ? Tooltip(
                                  message: 'Já está nesta playlist',
                                  child: Icon(
                                    TablerIcons.circleCheck,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(TablerIcons.plus),
                                  tooltip: 'Adicionar',
                                  onPressed: () => _add(h),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ícone de playlist no resultado da busca (paridade desktop): escolhe a
/// playlist (ou cria uma) e adiciona a música.
Future<void> showAddToPlaylistSheet(BuildContext context, Hymn hymn) async {
  final storage = PlaylistStorage();
  final messenger = ScaffoldMessenger.of(context);
  final item = playlistItemOf(hymn);
  final chosen = await showModalBottomSheet<Object>(
    context: context,
    useSafeArea: true,
    builder: (context) => FutureBuilder<List<Playlist>>(
      future: storage.list(),
      builder: (context, snap) {
        final lists = snap.data ?? const <Playlist>[];
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                'Adicionar “${item.title}” à playlist',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final p in lists)
              ListTile(
                leading: const Icon(TablerIcons.playlist),
                title: Text(p.name),
                subtitle: Text('${p.items.length} faixa(s)'),
                onTap: () => Navigator.pop(context, p),
              ),
            ListTile(
              leading: const Icon(TablerIcons.plus),
              title: const Text('Nova playlist'),
              onTap: () => Navigator.pop(context, 'new'),
            ),
          ],
        );
      },
    ),
  );
  if (chosen == null || !context.mounted) return;
  Playlist? target = chosen is Playlist ? chosen : null;
  if (chosen == 'new') {
    final name = await askPlaylistName(context, title: 'Nova playlist');
    if (name == null || name.trim().isEmpty) return;
    target = await storage.create(name.trim());
  }
  if (target == null) return;
  final result = await storage.addItem(target.id, item);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        result?.added == false
            ? '“${item.title}” já está em “${target.name}”.'
            : '“${item.title}” adicionada a “${target.name}”.',
      ),
    ),
  );
}

Future<String?> askPlaylistName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nome da playlist'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
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
}
