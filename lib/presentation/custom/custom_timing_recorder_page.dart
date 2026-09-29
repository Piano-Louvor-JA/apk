import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_file_api.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_lyric_slide.dart';

/// Gravação de timing (v3.1c): toca o áudio e o usuário marca o instante
/// de cada estrofe com um botão — igual ao editor do desktop.
///
/// Os tempos salvam no formato MM:SS.mmm (convenção .slja/DB custom).
class CustomTimingRecorderPage extends StatefulWidget {
  final CustomCatalogApiImpl api;
  final String bearerToken;
  final int musicId;
  final String musicName;
  final String audioUrl;
  final List<CustomLyricSlide> slides;

  const CustomTimingRecorderPage({
    super.key,
    required this.api,
    required this.bearerToken,
    required this.musicId,
    required this.musicName,
    required this.audioUrl,
    required this.slides,
  });

  @override
  State<CustomTimingRecorderPage> createState() =>
      _CustomTimingRecorderPageState();
}

class _CustomTimingRecorderPageState extends State<CustomTimingRecorderPage> {
  final HymnAudioPlayer _player = HymnAudioPlayer.instance;
  List<CustomLyricSlide> _slides = [];
  int _current = 0;
  bool _saving = false;
  String? _error;
  String? _lastUrl;
  Duration? _lastPosition;

  /// Tempos marcados (índice da estrofe → MM:SS.mmm).
  final Map<int, String> _marked = {};

  /// Imagens de fundo escolhidas (índice → id_file do upload).
  final Map<int, int> _bgFiles = {};

  @override
  void initState() {
    super.initState();
    _slides = widget.slides;
    _posSub = _player.positionStream.listen((d) {
      _lastPosition = d;
      if (mounted) setState(() {});
    });
    _initAudio();
  }

  late final StreamSubscription<Duration> _posSub;

  Future<void> _initAudio() async {
    try {
      final url = widget.audioUrl.startsWith('http')
          ? widget.audioUrl
          : '${widget.api.apiBaseUrl}${widget.audioUrl}';
      _lastUrl = url;
      await _player.playUrl(url);
      await _player.pause();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar o áudio: $e');
      }
    }
  }

  @override
  void dispose() {
    _posSub.cancel();
    _player.stop();
    super.dispose();
  }

  String _formatMs(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final mmm = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$mm:$ss.$mmm';
  }

  /// Escolhe imagem de fundo pra estrofe corrente e salva via PUT.
  Future<void> _pickBackground() async {
    if (_current >= _slides.length) return;
    const typeGroup = XTypeGroup(
      label: 'Imagem',
      extensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final upload = await CustomFileApi().upload(
        File(file.path),
        kind: 'imagens',
        bearerToken: widget.bearerToken,
      );
      await widget.api.updateLyric(
        _slides[_current].id,
        idFileImage: upload.idFile,
        bearerToken: widget.bearerToken,
      );
      if (!mounted) return;
      setState(() => _bgFiles[_current] = upload.idFile);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fundo da estrofe ${_current + 1} salvo!')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao enviar a imagem.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Marca o tempo atual pra estrofe corrente e avança.
  Future<void> _markAndAdvance() async {
    if (_current >= _slides.length) return;
    // posição vem do stream; guarda a última conhecida
    final pos = _lastPosition ?? Duration.zero;
    final stamp = _formatMs(pos);
    setState(() {
      _marked[_current] = stamp;
      _current++;
    });
    // Salva imediatamente (best-effort): continuar mesmo se um PUT falhar.
    try {
      await widget.api.updateLyric(
        _slides[_current - 1].id,
        time: stamp,
        bearerToken: widget.bearerToken,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao salvar estrofe ${_current} — segue; '
              'pode regravar.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveWithoutMoreMarks() async {
    // Marca a estrofe corrente e encerra.
    await _markAndAdvance();
    if (!mounted) return;
    Navigator.of(context).pop(_marked.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = _marked.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Timing: ${widget.musicName}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveWithoutMoreMarks,
            child: const Text('Concluir'),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, snap) {
                          final pos = snap.data ?? Duration.zero;
                          return Text(
                            _formatMs(pos),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          StreamBuilder<bool>(
                            stream: _player.playingStream,
                            builder: (context, snap) {
                              final playing = snap.data == true;
                              return IconButton.filled(
                                iconSize: 36,
                                onPressed: () => playing
                                    ? _player.pause()
                                    : _player.playUrl(_lastUrl!),
                                icon: Icon(
                                  playing ? Icons.pause : Icons.play_arrow,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            tooltip: 'Reiniciar',
                            onPressed: () => _player.seek(Duration.zero),
                            icon: const Icon(Icons.replay),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$done/${_slides.length} estrofes marcadas',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Estrofe corrente em destaque + botão gigante de marcação.
                if (_current < _slides.length)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Estrofe ${_current + 1}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _slides[_current].text,
                            style: theme.textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _pickBackground,
                            icon: const Icon(Icons.wallpaper),
                            label: Text(
                              _bgFiles.containsKey(_current)
                                  ? 'Fundo definido ✓'
                                  : 'Fundo desta estrofe (opcional)',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            onPressed: _markAndAdvance,
                            icon: const Icon(Icons.flag, size: 28),
                            label: const Text(
                              'Esta estrofe começa AGORA',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 56,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Todas as estrofes marcadas!',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(done),
                            child: const Text('Salvar e sair'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
