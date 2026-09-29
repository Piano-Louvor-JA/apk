import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/local_custom_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_player_adapter.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_file_api.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection_music.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_music_editor_page.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/now_playing_page.dart';
import 'package:louvorja_piano_mobile/presentation/custom/import_slja.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_timing_recorder_page.dart';

/// Edição de coletânea própria (v2.1): lista músicas, adicionar/remover,
/// renomear e excluir. Dono apenas — chamada quando collection.isOwner.
class CustomCollectionEditPage extends StatefulWidget {
  final CustomCatalogApiImpl api;
  final CustomCollection collection;
  final String? bearerToken;
  final LocalCustomStore? localStore;

  const CustomCollectionEditPage({
    super.key,
    required this.api,
    required this.collection,
    this.bearerToken,
    this.localStore,
  });

  @override
  State<CustomCollectionEditPage> createState() =>
      _CustomCollectionEditPageState();
}

class _CustomCollectionEditPageState extends State<CustomCollectionEditPage> {
  late String _name;
  String? _coverUrl;
  List<CustomCollectionMusic>? _musics;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = widget.collection.name;
    _coverUrl = widget.collection.coverUrl;
    _load();
  }

  Future<void> _load() async {
    // MODO LOCAL: músicas do store do dispositivo, sem API.
    if (widget.localStore != null) {
      final rows = widget.localStore!.listLocalMusics(widget.collection.id);
      if (!mounted) return;
      setState(() {
        _musics = [
          for (final m in rows)
            CustomCollectionMusic(
              id: (m['id'] as num).toInt(),
              collectionId: widget.collection.id,
              name: m['name'] as String? ?? '',
            ),
        ];
        _error = null;
      });
      return;
    }
    try {
      final list = await widget.api.fetchCollectionMusics(
        widget.collection.id,
        bearerToken: widget.bearerToken ?? '',
      );
      if (!mounted) return;
      setState(() {
        _musics = list;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível carregar as músicas.');
    }
  }

  Future<void> _removeMusic(CustomCollectionMusic music) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover música'),
        content: Text('Remover "${music.name}" desta coletânea?'),
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
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    if (widget.localStore != null) {
      widget.localStore!.deleteLocalMusic(music.id);
      await _load();
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      await widget.api.removeMusicFromCollection(
        musicId: music.id,
        bearerToken: widget.bearerToken ?? '',
      );
      await _load();
    } catch (_) {
      if (mounted) _showSnack('Falha ao remover. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear coletânea'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == _name || !mounted) {
      return;
    }
    setState(() => _busy = true);
    // MODO LOCAL: rename só no store.
    if (widget.localStore != null) {
      widget.localStore!.renameLocalCollection(widget.collection.id, newName);
      if (!mounted) return;
      setState(() => _name = newName);
      _showSnack('Renomeada localmente.');
      return;
    }
    try {
      await widget.api.updateCollection(
        widget.collection.id,
        name: newName,
        bearerToken: widget.bearerToken ?? '',
      );
      if (!mounted) return;
      setState(() => _name = newName);
    } catch (_) {
      if (mounted) _showSnack('Falha ao renomear. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCollection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir coletânea'),
        content: Text(
          'Excluir "$_name" e suas ${_musics?.length ?? 0} músicas? Isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (widget.localStore != null) {
        widget.localStore!.deleteLocalCollection(widget.collection.id);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      await widget.api.deleteCollection(
        widget.collection.id,
        bearerToken: widget.bearerToken ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true); // sinaliza exclusão pra lista recarregar
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _showSnack('Falha ao excluir. Tente novamente.');
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Tap na música = tocar (NowPlayingPage com slides/timing custom).
  Future<void> _playCustom(CustomCollectionMusic music) async {
    // Sem áudio (ou sem timing gravado) abre em modo slides manuais —
    // mensagem explica o porquê em vez de falhar em silêncio.
    if (music.audioUrl == null) {
      _showSnack(
        'Sem áudio sincronizado — navegue pelos slides com as setas. '
        'Grave o timing (⏱) pra sincronizar.',
      );
    }
    try {
      final hymn = await widget.api.fetchCustomHymn(music.id);
      if (!mounted) return;
      // Resolve URL absoluta do áudio (audio_url vem relativo ou absoluto).
      final rawUrl = hymn.urlMusic;
      final source = (rawUrl == null || rawUrl.isEmpty)
          ? null
          : (rawUrl.startsWith('http')
                ? rawUrl
                : '${widget.api.filesBaseUrl}${rawUrl.startsWith('/') ? '' : '/'}$rawUrl');

      final player = HymnAudioPlayer.instance;
      if (source != null) await player.playUrl(source);

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NowPlayingPage(
            detail: hymn,
            instrumental: false,
            player: HymnPlayerAdapter(player),
            filesUrl: widget.api.filesBaseUrl,
            audioSource: source,
            audioIsLocal: false,
          ),
        ),
      );
    } catch (_) {
      if (mounted) _showSnack('Falha ao abrir "${music.name}".');
    }
  }

  Future<void> _openTimingRecorder(CustomCollectionMusic music) async {
    try {
      final slides = await widget.api.fetchLyrics(
        music.id,
        bearerToken: widget.bearerToken ?? '',
      );
      if (!mounted) return;
      if (slides.isEmpty) {
        _showSnack('Esta música não tem estrofes salvas.');
        return;
      }
      await Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (_) => CustomTimingRecorderPage(
            api: widget.api,
            bearerToken: widget.bearerToken ?? '',
            musicId: music.id,
            musicName: music.name,
            audioUrl: music.audioUrl!,
            slides: slides,
          ),
        ),
      );
    } catch (_) {
      if (mounted) _showSnack('Falha ao carregar estrofes.');
    }
  }

  Future<void> _showAddMenu() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Criar música nova'),
              subtitle: const Text('Digitar a letra aqui no app'),
              onTap: () => Navigator.pop(sheetContext, 'new'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Importar .slja'),
              subtitle: const Text('Apresentação feita no LouvorJA Delphi/PC'),
              onTap: () => Navigator.pop(sheetContext, 'slja'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || option == null) return;
    if (option == 'new') {
      await _openMusicEditor(context);
    } else if (option == 'slja') {
      await importSljaIntoCollection(
        context,
        api: widget.api,
        fileApi: CustomFileApi(),
        collection: widget.collection,
        bearerToken: widget.bearerToken ?? '',
        onDone: _load,
      );
    }
  }

  Future<void> _changeCover() async {
    const typeGroup = XTypeGroup(
      label: 'Imagem',
      extensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    // MODO LOCAL: capa vira caminho local no store (sem upload/API).
    if (widget.localStore != null) {
      // persistir cover local é enhancement futuro — por ora só reflete na UI
      if (!mounted) return;
      setState(() => _coverUrl = file.path);
      _showSnack('Capa definida localmente (não sincronizada).');
      return;
    }
    try {
      final upload = await CustomFileApi().upload(
        File(file.path),
        kind: 'imagens',
        bearerToken: widget.bearerToken ?? '',
      );
      await widget.api.updateCollection(
        widget.collection.id,
        coverUrl: upload.url,
        bearerToken: widget.bearerToken ?? '',
      );
      if (!mounted) return;
      setState(() => _coverUrl = upload.url);
    } catch (_) {
      if (mounted) _showSnack('Falha ao enviar a capa.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMusicEditor(BuildContext context) async {
    final fileApi = CustomFileApi();
    if (!mounted) return;
    final created = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => CustomMusicEditorPage(
          api: widget.api,
          fileApi: fileApi,
          collection: widget.collection,
          bearerToken: widget.bearerToken,
          localStore: widget.localStore,
        ),
      ),
    );
    if (created != null && mounted) _load();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          IconButton(
            tooltip: 'Alterar capa',
            icon: const Icon(Icons.image),
            onPressed: _busy ? null : _changeCover,
          ),
          IconButton(
            tooltip: 'Renomear',
            icon: const Icon(Icons.edit),
            onPressed: _busy ? null : _rename,
          ),
          IconButton(
            tooltip: 'Excluir coletânea',
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _deleteCollection,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _showAddMenu,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      body: _musics == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          : _musics!.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Coletânea vazia.\nToque em "+" para adicionar hinos.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Header de capa (v3.3)
                if (_coverUrl != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: _coverUrl!.startsWith('http')
                            ? _coverUrl!
                            : '${widget.api.filesBaseUrl}${_coverUrl!.startsWith('/') ? '' : '/'}$_coverUrl',
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                ..._musics!.map(
                  (m) => ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(m.name),
                    subtitle: m.duration != null ? Text(m.duration!) : null,
                    // Tap = tocar (playback custom via NowPlayingPage).
                    onTap: () => _playCustom(m),
                    trailing: _busy
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (m.audioUrl != null)
                                IconButton(
                                  tooltip: 'Gravar timing',
                                  icon: const Icon(Icons.timer),
                                  onPressed: () => _openTimingRecorder(m),
                                ),
                              IconButton(
                                tooltip: 'Remover',
                                icon: const Icon(Icons.close),
                                onPressed: () => _removeMusic(m),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
      // RF-03 (adicionar hino oficial) entra na v2.2 — depende do buscador
      // do catálogo local; a casca do FAB já fica pronta.
    );
  }
}
