library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/playlist_storage.dart';
import 'package:louvorja_piano_mobile/presentation/custom/save_to_collection_sheet.dart';

import '../../core/services/now_playing.dart';
import '../../core/services/palco/palco_foreground.dart';
import '../../core/services/pip_controller.dart';
import '../../core/services/media_session.dart';
import '../../core/services/dlna/stage_session.dart';
import '../../core/services/palco/palco_controller.dart' show PalcoAudioRoute;
import '../shared/widgets/stage_stop_video_button.dart';
import '../../domain/entities/hymn.dart';
import '../../domain/entities/lyric_slides.dart';
import '../shared/widgets/player_timeline.dart';

/// Tela "Now Playing" — o player modo vídeo do pianolouvorja/app.
///
/// Como no Electron (FullscreenPlayer.vue + Media.js):
/// - fundo = url_image do slide atual (carry-over incluído)
/// - texto da estrofe centralizado
/// - slides trocam SOZINHOS no tempo do áudio (times[] do modo)
/// - toque/seta = goToSlide → seek do áudio (bidirecional)
/// - modos: cantado / instrumental (se houver) / sem áudio
class NowPlayingPage extends StatefulWidget {
  final Hymn detail;
  final bool instrumental;

  /// Cover do álbum (para o quadradinho now-playing no Palco).
  final String? albumCoverUrl;
  final HymnPlayerLike player;
  final String filesUrl;
  final VoidCallback? onClose;
  // F3.2: fonte de áudio resolvida (local ou remota) + modo instrumental,
  // para rotear o som pro Palco quando audioRoute != local.
  final String? audioSource;
  final bool audioIsLocal;

  /// Duração vinda da lista do álbum. Hinários trazem este campo mesmo
  /// quando decoder Android não fornece metadata do MP3.
  final int? catalogDurationMs;

  const NowPlayingPage({
    super.key,
    required this.detail,
    required this.instrumental,
    this.albumCoverUrl,
    required this.player,
    required this.filesUrl,
    this.onClose,
    this.audioSource,
    this.audioIsLocal = false,
    this.catalogDurationMs,
  });

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  late LyricSlides _slides;
  int _index = 0;
  bool _noAudio = false;
  DateTime? _manualSlideUntil;
  StreamSubscription<Duration>? _posSub;
  Duration? _lastPosition; // F3.3g: última posição do player local
  bool _routeListenerAdded = false; // F3.2: listener de mudança de audioRoute

  // Palco: sessão GLOBAL (StageSession) — o player projeta no mesmo
  // palco que Liturgia/Bíblia. Sem controller local (bug 2026-08-16:
  // cast do player era órfão e os slides nunca chegavam à TV).

  @override
  void initState() {
    super.initState();
    _slides = LyricSlides.fromApi(
      musicName: widget.detail.title ?? '',
      coverUrl: widget.detail.imageUrl,
      raw: widget.detail.lyricRaw ?? const [],
    );
    // F3.2: modo de áudio mudado em runtime (painel do cast) — ajusta
    // o player local: modo tv = mudo, volta pro local = retoma.
    StageSession.instance.addListener(_onAudioRouteChanged);
    _routeListenerAdded = true;
    _posSub = widget.player.positionStream.listen((pos) {
      _lastPosition = pos; // F3.3g
      if (!mounted || _noAudio) return;
      // Evita evento com posição antiga desfazer um toque no chevron antes
      // de Android concluir seek (mais visível nos MP3s do hinário).
      if (_manualSlideUntil?.isAfter(DateTime.now()) ?? false) return;
      final idx = _slides.indexAt(pos, instrumental: widget.instrumental);
      if (idx != _index) {
        setState(() => _index = idx);
        _projectCurrentSlide();
      }
    });
    // Player nativo já usa AudioContext stayAwake em background. Esta tela
    // segura tela ativa durante operação; não depende do notifier do adapter.
    WakelockPlus.enable();
    // Serviço mantém áudio/clock/sender vivos fora do app. É compartilhado
    // com Palco e não pode ser parado ao entrar em PiP.
    PalcoForeground.start();
    PipController.setEnabled(true);
    // MediaSession: notificação de mídia + lock screen + ações PiP.
    MediaSession.onPlayPause = (play) {
      if (!mounted) return;
      if (play) {
        if (StageSession.instance.audioRoute == PalcoAudioRoute.tv) {
          StageSession.instance.palco?.resumeAudio();
        } else {
          widget.player.resume();
        }
      } else {
        _pauseAudioEverywhere();
      }
      if (mounted) setState(() {});
    };
    MediaSession.onPrev = () => _goToSlide(_index - 1);
    MediaSession.onNext = () => _goToSlide(_index + 1);
    MediaSession.init().then((_) {
      if (!mounted) return;
      MediaSession.setMetadata(
        title: widget.detail.title ?? '',
        album: nowPlaying.track?.album ?? '',
        artUrl: widget.detail.imageUrl,
        durationMs: widget.catalogDurationMs ?? widget.detail.durationMs ?? 0,
      );
    });
    // F3.2: roteia áudio pro palco (se ativo e modo != local).
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeAudio());
  }

  /// F3.2/F3.3e: modo mudou em runtime — silencia/retoma o player local.
  /// Modo tv: MUDO (setVolume 0), NÃO pausado — o player local continua
  /// sendo o relógio dos slides (pausar congelava a letra projetada).
  void _onAudioRouteChanged() {
    if (!mounted) return;
    final route = StageSession.instance.audioRoute;
    if (route == PalcoAudioRoute.tv) {
      widget.player.setVolume(0); // TV vira a caixa de som; celular = controle
    } else {
      widget.player.setVolume(1); // local/mirror: som volta no celular
    }
    setState(() {});
  }

  @override
  void dispose() {
    PipController.setEnabled(false);
    MediaSession.release();
    if (!StageSession.instance.isOn) {
      WakelockPlus.disable();
      PalcoForeground.stop();
    }
    if (_routeListenerAdded) {
      StageSession.instance.removeListener(_onAudioRouteChanged);
    }
    _posSub?.cancel();
    // Multi-palco: minimizar (voltar pro mini player) NÃO para a música
    // na TV — o player singleton segue tocando e a projeção permanece.
    // Parar de verdade é o long-press no X (_stopAudioEverywhere) ou o
    // botão stop do mini player.
    // Palco global NÃO é desconectado aqui: sessão persiste entre telas.
    super.dispose();
  }

  // ===== Palco: usar o botão compartilhado na AppBar (StageSession) =====

  /// F3.2/F3.3e: roteia o áudio pro palco (se ativo e modo != local).
  /// Em modo tv, o player LOCAL fica MUDO (não pausado) — continua sendo
  /// o relógio dos slides; a TV toca via proxy do sender.
  void _routeAudio() {
    final stage = StageSession.instance;
    if (!stage.isOn || widget.audioSource == null) return;
    if (stage.audioRoute == PalcoAudioRoute.tv) {
      widget.player.setVolume(0); // mudo, não pausado (relógio dos slides)
    } else {
      widget.player.setVolume(1);
    }
    _resolveCoverForPalco().then((cover) {
      stage.playHymnAudio(
        widget.audioSource!,
        title: widget.detail.title ?? '',
        subtitle: widget.instrumental ? 'Instrumental' : null,
        // Quadradinho na TV = cover do ALBUM (nao a imagem da música/slide).
        cover: cover,
        // BG do slide atual atrás do now-playing (senão caía no fallback).
        background: _bgUrl,
        position: widget.audioIsLocal ? null : _currentLocalPosition(),
      );
    });
  }

  /// Cover do álbum resolvido pra uma URL que a TV alcança.
  ///
  /// Hinários têm capa LOCAL (`asset:hymnal.jpeg`) — não vem da API. O
  /// receiver não resolve `asset:` (caía no logo default). Aqui o asset é
  /// lido do bundle e servido via /media do sender, virando http://.
  /// Capas de coletâneas (caminho relativo da API) viram URL absoluta.
  Future<String?> _resolveCoverForPalco() async {
    final raw = widget.albumCoverUrl ?? widget.detail.imageUrl;
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('asset:')) {
      try {
        final stage = StageSession.instance;
        final assetPath = raw.substring('asset:'.length);
        final bytes = await rootBundle.load(assetPath);
        return stage.palco?.serveMedia(
          'album_cover_${assetPath.split('/').last}',
          bytes.buffer.asUint8List(),
        );
      } catch (_) {
        return null;
      }
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    // Caminho relativo da API (coletâneas): resolve pro endpoint de files.
    return '${widget.filesUrl}/$raw';
  }

  /// F3.3g: posição corrente do player local (para sincronizar a TV no
  /// play de tela no meio da faixa). Null quando não dá pra saber.
  Duration? _currentLocalPosition() => _lastPosition;

  void _pauseAudioEverywhere() {
    widget.player.pause();
    StageSession.instance.pauseHymnAudio();
  }

  void _stopAudioEverywhere() {
    widget.player.stop();
    StageSession.instance.stopHymnAudio();
  }

  /// Projeta o slide ATUAL do hino no palco global (se ligado).
  /// Mesma sessao da Liturgia/Biblia — um palco so.
  Future<void> _projectCurrentSlide() async {
    final stage = StageSession.instance;
    if (!stage.isOn) return;
    final slide = _slides.slides.isEmpty ? null : _slides.slides[_index];
    if (slide == null) return;
    // Resolve BG: asset local (hinario) -> serve via /media;
    // URL relativa da API -> ja e alcancavel pelo receiver;
    // null -> receiver usa bg-fallback.
    String? bg;
    if (_bgUrl != null) {
      if (_bgUrl!.startsWith('asset:')) {
        try {
          final assetPath = _bgUrl!.substring('asset:'.length);
          final bytes = await rootBundle.load(assetPath);
          bg = stage.palco?.serveMedia(
            'slide_bg_${assetPath.split('/').last}',
            bytes.buffer.asUint8List(),
          );
        } catch (_) {}
      } else {
        bg = _bgUrl;
      }
    }
    final ok = await stage.project(
      title: slide.text,
      footer: widget.detail.title,
      background: bg,
      module: 'hymns',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('stage.disconnected'.tr())));
    }
  }

  void _goToSlide(int index) {
    if (index < 0 || index >= _slides.slides.length) return;
    setState(() => _index = index);
    _manualSlideUntil = DateTime.now().add(const Duration(milliseconds: 800));
    _projectCurrentSlide();
    if (!_noAudio) {
      final t = widget.instrumental
          ? _slides.slides[index].instrumentalTime
          : _slides.slides[index].time;
      if (t != null) {
        if (StageSession.instance.audioRoute == PalcoAudioRoute.tv) {
          // só-TV: seek vai pro receiver (celular mudo não é o relógio)
          StageSession.instance.seekHymnAudio(t);
        } else {
          widget.player.seek(t);
        }
      }
    }
  }

  String? get _bgUrl {
    final img = _slides.slides.isEmpty ? null : _slides.slides[_index].imageUrl;
    if (img == null || img.isEmpty) return null;
    // asset: (capa de hinario local) — devolve cru, o chamador trata.
    if (img.startsWith('asset:')) return img;
    return '${widget.filesUrl}/$img'.replaceAll('//images', '/images');
  }

  /// Sheet de "Adicionar à playlist": lista playlists existentes + criar
  /// nova inline. Playlist = seleção de hinos do acervo (local, sem auth).
  Future<void> _addToPlaylist(BuildContext context) async {
    final storage = PlaylistStorage();
    final playlists = await storage.list();
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Adicionar à playlist',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhuma playlist ainda — crie a primeira.'),
              ),
            for (final p in playlists)
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(p.name),
                subtitle: Text('${p.items.length} hinos'),
                onTap: () => Navigator.pop(sheetContext, p.id),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Criar nova playlist'),
              onTap: () => Navigator.pop(sheetContext, '__new__'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    String playlistId = selected;
    if (selected == '__new__') {
      final controller = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nova playlist'),
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
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Criar'),
            ),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty || !mounted) return;
      final created = await storage.create(name);
      playlistId = created.id;
    }
    final result = await storage.addItem(
      playlistId,
      PlaylistItem(
        musicId: widget.detail.id,
        title: widget.detail.title ?? 'Hino',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result != null && result.added
              ? '"${widget.detail.title ?? 'Hino'}" adicionada à playlist.'
              : 'Já é a última faixa da playlist.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slide = _slides.slides.isEmpty ? null : _slides.slides[_index];
    final playing = widget.player.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fundo do slide — asset local (hinario) ou URL da API.
          if (_bgUrl != null)
            _bgUrl!.startsWith('asset:')
                ? Image.asset(
                    _bgUrl!.substring('asset:'.length),
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    imageUrl: _bgUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
          Container(color: Colors.black54),

          // Conteúdo
          SafeArea(
            child: Column(
              children: [
                // Top bar: título + modos + minimizar + fechar
                Row(
                  children: [
                    // Minimizar: esconde o NowPlaying SEM parar nada —
                    // música/projeção seguem; volta pelo mini player.
                    IconButton(
                      tooltip: 'Minimizar (música continua)',
                      icon: const Icon(
                        TablerIcons.arrowsDiagonal2,
                        color: Colors.white,
                      ),
                      onPressed:
                          widget.onClose ??
                          () => Navigator.of(context).maybePop(),
                    ),
                    IconButton(
                      icon: const Icon(TablerIcons.x, color: Colors.white),
                      // X = para tudo (local + todas as TVs) E fecha.
                      onPressed: () {
                        _stopAudioEverywhere();
                        if (mounted) {
                          Navigator.of(context).maybePop();
                        }
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.detail.title ?? '',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const StageStopVideoButton(),
                    // Salvar este hino numa coletânea custom (conteúdo do usuário).
                    IconButton(
                      tooltip: 'Salvar em coletânea',
                      icon: const Icon(
                        TablerIcons.playlistAdd,
                        color: Colors.white,
                      ),
                      onPressed: () => showSaveToCollectionSheet(
                        context,
                        officialMusicId: widget.detail.id,
                        hymnTitle: widget.detail.title ?? 'Hino',
                      ),
                    ),
                    // Adicionar a uma PLAYLIST (seleção de hinos do acervo,
                    // salva localmente — paridade com a /media do web).
                    IconButton(
                      tooltip: 'Adicionar à playlist',
                      icon: const Icon(
                        TablerIcons.playlist,
                        color: Colors.white,
                      ),
                      onPressed: () => _addToPlaylist(context),
                    ),
                    // Cast só no AppBar (hinos/sub-módulos) — nunca abaixo.
                    // Configura uma vez; cada hino não repete o controle.
                    if (widget.detail.hasInstrumental)
                      IconButton(
                        tooltip: widget.instrumental
                            ? 'Cantado'
                            : 'Instrumental',
                        icon: Icon(
                          widget.instrumental
                              ? TablerIcons.microphone
                              : TablerIcons.piano,
                          color: Colors.white,
                        ),
                        onPressed: () => setState(() {
                          // Alterna modo local na exibição; reabrir troca fonte.
                        }),
                      ),
                    IconButton(
                      tooltip: _noAudio ? 'Com áudio' : 'Sem áudio',
                      icon: Icon(
                        _noAudio ? TablerIcons.volume : TablerIcons.volumeOff,
                        color: Colors.white,
                      ),
                      onPressed: () => setState(() => _noAudio = !_noAudio),
                    ),
                  ],
                ),

                // Capa do álbum grande (referência 2026-08-21) + letra
                // sobreposta; swipe na área troca slide.
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (d) {
                      if (d.primaryVelocity == null) return;
                      if (d.primaryVelocity! < 0) _goToSlide(_index + 1);
                      if (d.primaryVelocity! > 0) _goToSlide(_index - 1);
                    },
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        // Capa quadrada ocupando a largura útil.
                        if (widget.albumCoverUrl != null)
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: widget.albumCoverUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorWidget: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        // Letra sincronizada abaixo da capa.
                        Expanded(
                          flex: 4,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                slide?.text ?? '',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Indicador de slides (pontos)
                if (_slides.slides.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${_index + 1} / ${_slides.slides.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),

                // Player: timeline + play/pause + prev/next slide
                if (!_noAudio)
                  PlayerTimeline(
                    positionStream: widget.player.positionStream,
                    durationStream: widget.player.durationStream,
                    onSeek: widget.player.seek,
                    fallbackDuration: Duration(
                      // Lista do hinário é a fonte estável. Detail pode
                      // não trazer duração em cache legado.
                      milliseconds:
                          widget.catalogDurationMs ??
                          widget.detail.durationMs ??
                          0,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        TablerIcons.chevronLeft,
                        color: Colors.white,
                      ),
                      onPressed: () => _goToSlide(_index - 1),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      iconSize: 56,
                      icon: Icon(
                        playing
                            ? TablerIcons.playerPause
                            : TablerIcons.playerPlay,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        if (widget.player.isPlaying) {
                          _pauseAudioEverywhere();
                          MediaSession.setPlaybackState(
                            isPlaying: false,
                            positionMs: _lastPosition?.inMilliseconds ?? 0,
                          );
                        } else if (StageSession.instance.audioRoute ==
                            PalcoAudioRoute.tv) {
                          // só-TV: retoma SÓ no palco; player local nunca
                          // volta a tocar neste modo (F3.3 T3).
                          StageSession.instance.palco?.resumeAudio();
                        } else {
                          await widget.player.resume();
                          _routeAudio();
                          MediaSession.setPlaybackState(
                            isPlaying: true,
                            positionMs: _lastPosition?.inMilliseconds ?? 0,
                          );
                        }
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(
                        TablerIcons.chevronRight,
                        color: Colors.white,
                      ),
                      onPressed: () => _goToSlide(_index + 1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
