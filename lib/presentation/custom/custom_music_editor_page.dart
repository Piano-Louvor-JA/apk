import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_selector/file_selector.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/local_custom_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_file_api.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_lyric_slide.dart'
    show CustomLyricSlide, effectiveSlideBg;
import 'package:louvorja_piano_mobile/presentation/custom/custom_timing_recorder_page.dart';

/// Criador de música custom (v3.1): nome, letra dividida em estrofes,
/// áudio OBRIGATÓRIO e timing gravado tocando a música.
///
/// Fluxo: salvar música → abre gravação de timing (áudio sempre presente).
/// Fundo por estrofe pode ser escolhido na criação (opcional).
///
/// Modo LOCAL (localStore != null): salva no dispositivo sem auth — o
/// áudio NÃO sobe, fica no arquivo original (caminho local) e as estrofes
/// vão pro store local. Nunca chama a API.
class CustomMusicEditorPage extends StatefulWidget {
  final CustomCatalogApiImpl api;
  final CustomFileApi fileApi;
  final CustomCollection collection;
  final String? bearerToken;
  final LocalCustomStore? localStore;

  const CustomMusicEditorPage({
    super.key,
    required this.api,
    required this.fileApi,
    required this.collection,
    this.bearerToken,
    this.localStore,
  });

  @override
  State<CustomMusicEditorPage> createState() => _CustomMusicEditorPageState();
}

class _CustomMusicEditorPageState extends State<CustomMusicEditorPage> {
  final _nameController = TextEditingController();
  final _lyricController = TextEditingController();
  File? _audioFile;
  double _uploadProgress = 0;
  bool _busy = false;

  /// Fundo escolhido por estrofe (índice do slide → arquivo).
  final Map<int, File> _bgFiles = {};

  @override
  void dispose() {
    _nameController.dispose();
    _lyricController.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    const typeGroup = XTypeGroup(
      label: 'Áudio',
      extensions: ['mp3', 'm4a', 'aac', 'ogg', 'wav'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    setState(() => _audioFile = File(file.path));
  }

  /// Escolhe imagem de fundo pra uma estrofe específica (na criação).
  Future<void> _pickBackground(int slideIndex, String slidePreview) async {
    const typeGroup = XTypeGroup(
      label: 'Imagens',
      extensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    setState(() => _bgFiles[slideIndex] = File(file.path));
  }

  /// Salva: upload de áudio (se houver) → cria música → cria estrofes com
  /// order sequencial (time vazio = slide manual; timing vem depois).
  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (_busy || !mounted) return;
    if (name.isEmpty) {
      _showSnack('Dá um nome pra música antes de salvar.');
      return;
    }
    final slides = CustomLyricSlide.splitIntoSlides(_lyricController.text);
    if (slides.isEmpty) {
      _showSnack('Escreve a letra — pelo menos uma estrofe.');
      return;
    }
    if (_audioFile == null) {
      _showSnack('Escolhe o áudio da música — é obrigatório pra tocar.');
      return;
    }
    setState(() => _busy = true);

    // MODO LOCAL (sem auth): salva no dispositivo, sem API, sem upload.
    if (widget.localStore != null) {
      try {
        final saved = widget.localStore!.saveLocalMusic(
          collectionId: widget.collection.id,
          name: name,
          lyric: _lyricController.text.trim(),
          audioPath: _audioFile!.path,
          slides: [
            for (var i = 0; i < slides.length; i++)
              {'text': slides[i], 'time': '00:00.000', 'order': i},
          ],
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"$name" salva neste dispositivo (${slides.length} estrofes).',
            ),
          ),
        );
        // Sincronização letra↔áudio direto: recorder com o arquivo local
        // (playUrl aceita path via DeviceFileSource).
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomTimingRecorderPage(
              api: widget.api,
              bearerToken: '',
              musicId: (saved['id'] as num).toInt(),
              musicName: name,
              audioUrl: _audioFile!.path,
              slides: [
                for (var i = 0; i < slides.length; i++)
                  CustomLyricSlide(
                    id: i + 1,
                    text: slides[i],
                    time: '00:00.000',
                    order: i,
                  ),
              ],
            ),
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop((saved['id'] as num).toInt());
      } catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
      }
      return;
    }

    try {
      final bearer = widget.bearerToken;
      int? idFileAudio;
      if (_audioFile != null && bearer != null) {
        final upload = await widget.fileApi.upload(
          _audioFile!,
          kind: 'audio',
          bearerToken: bearer,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
        idFileAudio = upload.idFile;
      }

      final musicId = await widget.api.createMusic(
        collectionId: widget.collection.id,
        name: name,
        lyric: _lyricController.text.trim(),
        idFileAudio: idFileAudio,
        bearerToken: widget.bearerToken,
      );

      // Fundos por estrofe (opcional): upload das imagens escolhidas.
      // Upload único por imagem distinta; slides sem BG herdando o slide 0
      // recebem o MESMO id (padrão da música no servidor).
      final bgIds = <int, int?>{};
      final uploadedIds = <String, int>{}; // path → id_file
      for (var i = 0; i < slides.length; i++) {
        final bg = effectiveSlideBg(_bgFiles, i);
        if (bg == null) continue;
        final cached = uploadedIds[bg.path];
        if (cached != null) {
          bgIds[i] = cached;
          continue;
        }
        final up = await widget.fileApi.upload(
          bg,
          kind: 'imagens',
          bearerToken: bearer!,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
        uploadedIds[bg.path] = up.idFile;
        bgIds[i] = up.idFile;
      }

      // Estrofes: salvo cada uma com order (timing opcional depois) + BG.
      for (var i = 0; i < slides.length; i++) {
        await widget.api.addLyric(
          musicId: musicId,
          lyric: slides[i],
          order: i,
          time: '00:00.000',
          idFileImage: bgIds[i],
          bearerToken: widget.bearerToken,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$name" criada com ${slides.length} estrofes!'),
        ),
      );
      // Player com preview: abre a sincronização de letra↔áudio direto,
      // igual ao editor do web — usuário ajusta o timing na hora.
      if (!mounted) return;
      final detail = await widget.api.fetchMusicDetail(musicId);
      if (!mounted) return;
      if (detail.audioUrl != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomTimingRecorderPage(
              api: widget.api,
              bearerToken: bearer ?? '',
              musicId: musicId,
              musicName: name,
              audioUrl: detail.audioUrl!,
              slides: detail.lyrics
                  .map(
                    (l) => CustomLyricSlide(
                      id: l.id,
                      text: l.text,
                      time: l.time,
                      order: l.order,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(musicId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slides = CustomLyricSlide.splitIntoSlides(_lyricController.text);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova música'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome da música',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lyricController,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Letra',
              helperText:
                  'Separe os slides com uma linha em branco (igual no PC)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (slides.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${slides.length} estrofes detectadas',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Áudio OBRIGATÓRIO — sem ele a música não toca e o timing
          // não pode ser gravado.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickAudio,
                  icon: Icon(
                    Icons.audiotrack,
                    color: _audioFile == null ? theme.colorScheme.error : null,
                  ),
                  label: Text(
                    _audioFile == null
                        ? 'Escolher áudio (obrigatório) *'
                        : 'Áudio: ${_audioFile!.path.split('/').last}',
                    style: _audioFile == null
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          // Fundos por estrofe (opcional): um chip por estrofe detectada.
          if (slides.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Fundo por estrofe (opcional)',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < slides.length; i++)
                  ActionChip(
                    avatar: Icon(
                      _bgFiles.containsKey(i)
                          ? Icons.image
                          : Icons.image_not_supported,
                      size: 18,
                      color: _bgFiles.containsKey(i)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    label: Text(
                      _bgFiles.containsKey(i)
                          ? 'Estrofe ${i + 1} ✓'
                          : 'Fundo ${i + 1}',
                    ),
                    onPressed: _busy
                        ? null
                        : () => _pickBackground(i, slides[i]),
                  ),
              ],
            ),
          ],
          if (_busy && _audioFile != null && _uploadProgress < 1) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 4),
            Text(
              'Enviando áudio: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
