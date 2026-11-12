library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../core/services/now_playing.dart';
import '../../../../core/services/dlna/stage_session.dart';
import '../../../../core/services/palco/palco_controller.dart'
    show PalcoAudioRoute;
import '../../palco/remote_control_sheet.dart';
import 'dart:async';

import '../../tools/monitor_share_link.dart';

import '../../../../core/services/palco/palco_controller.dart' show PalcoTarget;

import '../../../../core/services/dlna/slide_http_server.dart';

import '../../../../core/services/palco/palco_orchestrator.dart';

import '../../../../core/services/hymn_audio_player.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/api_config.dart';

import 'package:flutter/services.dart' show rootBundle;

import 'player_timeline.dart';
import '../../hymns/now_playing_page.dart';
import '../../../../domain/entities/lyric_slides.dart';
import '../../../../core/services/playlist_player.dart';

/// Miniplayer fixo (issue #90): barra acima da nav com a faixa ativa.
///
/// Referencia visual: Player.vue location='footer' do Electron
/// (footer-player-bar): info a esquerda, controles play/pause + stop,
/// tap na barra retorna para a origem (tab Hinos).
///
/// Aparece apenas com faixa ativa; some ao parar.
class MiniPlayerBar extends StatefulWidget {
  final NowPlayingNotifier notifier;
  final HymnPlayerLike player;
  final VoidCallback? onOpenPlayer;

  const MiniPlayerBar({
    super.key,
    required this.notifier,
    required this.player,
    this.onOpenPlayer,
  });

  @override
  State<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends State<MiniPlayerBar> {
  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onChanged);
    widget.player.playingListenable.addListener(_onPlayerChanged);
    _syncSlides();
    _posSub = widget.player.positionStream.listen(_onPosition);
    projecting.addListener(_onChanged);
  }

  @override
  void dispose() {
    _closeVolume();
    _posSub?.cancel();
    projecting.removeListener(_onChanged);
    _endStageReturn();
    widget.notifier.removeListener(_onChanged);
    widget.player.playingListenable.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onChanged() {
    _syncSlides();
    if (mounted) setState(() {});
  }

  void _onPlayerChanged() {
    // Espelha o player real (faixa terminou/pausou externamente).
    widget.notifier.setPlaying(widget.player.isPlaying);
  }

  Future<void> _toggle() async {
    final stage = StageSession.instance;
    if (widget.notifier.isPlaying) {
      await widget.player.pause();
      widget.notifier.pause();
      stage.pauseHymnAudio(); // espelha no Palco
    } else if (stage.audioRoute == PalcoAudioRoute.tv && stage.isPalcoMode) {
      // modo só-TV: retoma APENAS no palco (celular é controle)
      stage.palco?.resumeAudio();
      widget.notifier.setPlaying(true);
    } else if (_isPreparedOnly()) {
      // Hino só selecionado na lista (ainda não carregado no player):
      // o play daqui começa a tocar e leva o áudio ao palco se ligado.
      final track = widget.notifier.track!;
      final source = track.audioSource!;
      await widget.player.playSource(source);
      widget.notifier.setPlaying(true);
      if (stage.isOn) {
        stage.playHymnAudio(
          source,
          title: track.title,
          subtitle: track.instrumental ? 'Instrumental' : null,
          cover: track.detail?.imageUrl,
        );
      }
    } else {
      await widget.player.resume();
      widget.notifier.setPlaying(true);
      stage.rerouteCurrentAudio();
    }
  }

  bool _isPreparedOnly() {
    final source = widget.notifier.track?.audioSource;
    return source != null && HymnAudioPlayer.instance.currentUrl != source;
  }

  Future<void> _stop() async {
    await widget.player.stop();
    widget.notifier.stop();
    StageSession.instance.stopHymnAudio(); // espelha no Palco
  }

  // Prévia da letra (paridade Controle Remoto): slide atual pelo tempo.
  LyricSlides? _slides;
  int? _slidesHymnId;
  int _slideIndex = 0;
  bool _previewOpen = true;
  StreamSubscription<Duration>? _posSub;

  void _syncSlides() {
    final track = widget.notifier.track;
    final detail = track?.detail;
    if (track == null || detail == null) {
      _slides = null;
      _slidesHymnId = null;
      _endStageReturn();
      return;
    }
    if (_slidesHymnId == track.hymnId && _slides != null) return;
    _slidesHymnId = track.hymnId;
    _slideIndex = 0;
    _slides = LyricSlides.fromApi(
      musicName: detail.title ?? track.title,
      coverUrl: detail.imageUrl,
      raw: detail.lyricRaw ?? const [],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _projectSlide());
  }

  void _onPosition(Duration pos) {
    final slides = _slides;
    if (!mounted || slides == null || slides.slides.isEmpty) return;
    final idx = slides.indexAt(
      pos,
      instrumental: widget.notifier.track?.instrumental ?? false,
    );
    _lastPos = pos;
    final changed = idx != _slideIndex;
    if (changed) {
      setState(() => _slideIndex = idx);
      _projectSlide();
    }
    _sendStageReturn(pos, force: changed);
  }

  /// Setinha de projetar (paridade Controle Remoto): a letra só vai às
  /// telas (monitores do computador, TVs, OBS, retorno) depois do toque.
  /// Global: continua projetando ao trocar de música ou de tela.
  static final projecting = ValueNotifier<bool>(false);
  bool _projectBusy = false;

  Future<void> _toggleProjection() async {
    if (_projectBusy) return;
    final stage = StageSession.instance;
    if (projecting.value) {
      projecting.value = false;
      _endStageReturn();
      await stage.clearContent();
      // Sem projeção: esconde as telas do computador (se a opção pedir).
      await MonitorShareSession.instance.setProjecting(false);
      return;
    }
    setState(() => _projectBusy = true);
    try {
      if (!stage.isPalcoMode && !await _turnOnPhoneStage()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não deu para ligar o palco: sem rede Wi-Fi?'),
            ),
          );
        }
        return;
      }
      // Monitores do computador: reconecta se estava salvo e caiu.
      final principal = PalcoOrchestrator.instance.slot('principal');
      final ip = SlideHttpServer.localIp;
      if (principal != null && ip != null) {
        await MonitorShareSession.instance.ensureConnected(
          phoneIp: ip,
          wsPort: principal.wsPort,
        );
      }
      projecting.value = true;
      await MonitorShareSession.instance.setProjecting(true);
      await _projectSlide();
      final pos = _lastPos;
      if (pos != null) await _sendStageReturn(pos, force: true);
    } finally {
      if (mounted) setState(() => _projectBusy = false);
    }
  }

  /// Liga o palco do celular (conexão Principal), igual à Transmissão.
  Future<bool> _turnOnPhoneStage() async {
    final orch = PalcoOrchestrator.instance;
    await orch.loadStoredConfig();
    if (orch.slot('principal') == null) {
      orch.addSlot(id: 'principal', label: 'Principal');
    }
    final principal = orch.slot('principal')!;
    await SlideHttpServer.resolveLocalIp();
    final ip = SlideHttpServer.localIp;
    if (ip == null) return false;
    return StageSession.instance.turnOnPalco(
      PalcoTarget(name: principal.label, ip: ip, wsPort: principal.wsPort),
    );
  }

  Duration? _lastPos;

  // Retorno de palco (paridade desktop): atual + próximo + barra.
  DateTime _lastReturnAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _returnActive = false;

  Duration? _slideStart(int i) {
    final s = _slides!.slides[i];
    return (widget.notifier.track?.instrumental ?? false)
        ? s.instrumentalTime
        : s.time;
  }

  Future<void> _sendStageReturn(Duration pos, {bool force = false}) async {
    final stage = StageSession.instance;
    final slides = _slides;
    if (!projecting.value ||
        !stage.isPalcoMode ||
        slides == null ||
        slides.slides.isEmpty) {
      return;
    }
    final now = DateTime.now();
    // Barra: ~3 atualizações/s bastam (o receiver interpola).
    if (!force && now.difference(_lastReturnAt).inMilliseconds < 330) return;
    _lastReturnAt = now;
    final i = _slideIndex.clamp(0, slides.slides.length - 1);
    final current = slides.slides[i];
    final hasNext = i + 1 < slides.slides.length;
    final start = _slideStart(i) ?? Duration.zero;
    final end = hasNext
        ? (_slideStart(i + 1) ?? start)
        : Duration(milliseconds: widget.notifier.track?.durationMs ?? 0);
    final span = (end - start).inMilliseconds;
    final progress = span > 0
        ? ((pos - start).inMilliseconds / span).clamp(0.0, 1.0)
        : 0.0;
    _returnActive = true;
    stage.sendStageReturn({
      'active': true,
      'current': current.text,
      'next': hasNext ? slides.slides[i + 1].text : '',
      'isCover': i == 0,
      'nextIsCover': false,
      'slideIndex': i,
      'progress': progress,
      if (await _slideBg(current) case final bg?) 'background': bg,
      'style': const <String, dynamic>{},
    });
  }

  void _endStageReturn() {
    if (!_returnActive) return;
    _returnActive = false;
    StageSession.instance.sendStageReturn({'active': false});
  }

  /// Fundo do slide em URL que a TV/OBS alcança (asset vira /media).
  String? _bgKey;
  String? _bgValue;

  Future<String?> _slideBg(LyricSlide slide) async {
    final img = slide.imageUrl;
    if (img == null || img.isEmpty) return null;
    if (img == _bgKey) return _bgValue;
    _bgKey = img;
    return _bgValue = await _resolveBg(img);
  }

  Future<String?> _resolveBg(String img) async {
    if (!img.startsWith('asset:')) {
      return '${ApiConfig.urlFiles}/$img'.replaceAll('//images', '/images');
    }
    try {
      final assetPath = img.substring('asset:'.length);
      final bytes = await rootBundle.load(assetPath);
      return StageSession.instance.palco?.serveMedia(
        'slide_bg_${assetPath.split('/').last}',
        bytes.buffer.asUint8List(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Palco ligado (Transmissão/TV): a prévia também projeta o trecho atual,
  /// como a tela cheia — busca, playlists e fila tocam sem abri-la.
  Future<void> _projectSlide() async {
    final stage = StageSession.instance;
    final slides = _slides;
    final track = widget.notifier.track;
    if (!projecting.value ||
        !stage.isOn ||
        NowPlayingPage.openCount > 0 ||
        slides == null ||
        slides.slides.isEmpty ||
        track == null) {
      return;
    }
    final slide = slides.slides[_slideIndex.clamp(0, slides.slides.length - 1)];
    final bg = await _slideBg(slide);
    await stage.project(
      title: slide.text,
      footer: track.title,
      background: bg,
      module: 'hymns',
      isCover: _slideIndex == 0,
    );
  }

  Widget _preview(ThemeData theme) {
    final slides = _slides;
    if (slides == null || slides.slides.isEmpty) return const SizedBox.shrink();
    final slide = slides.slides[_slideIndex.clamp(0, slides.slides.length - 1)];
    // Fundo do slide igual à tela cheia (asset do hinário ou URL da API).
    final img = slide.imageUrl;
    String? bg;
    if (img != null && img.isNotEmpty) {
      bg = img.startsWith('asset:')
          ? img
          : '${ApiConfig.urlFiles}/$img'.replaceAll('//images', '/images');
    }
    return GestureDetector(
      key: const Key('miniplayer-preview'),
      onTap: widget.onOpenPlayer,
      child: SizedBox(
        height: 170,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            if (bg != null)
              bg.startsWith('asset:')
                  ? Image.asset(bg.substring('asset:'.length), fit: BoxFit.cover)
                  // coverage:ignore-start
                  : CachedNetworkImage(
                      imageUrl: bg,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
            // coverage:ignore-end
            const ColoredBox(color: Colors.black54),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  slide.text,
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Volume igual ao Controle Remoto: popup com slider vertical + mudo.
  static const _volumePopupMaxHeight = 380.0;
  static const _volumePopupWidth = 44.0;
  static const _volumePopupTopMargin = 16.0;
  double _volume = 100;
  double _volumeBeforeMute = 100;
  double _volumePopupHeight = _volumePopupMaxHeight;
  OverlayEntry? _volumeEntry;

  Future<void> _setVolume(double v) async {
    setState(() => _volume = v);
    _volumeEntry?.markNeedsBuild();
    await widget.player.setVolume(v / 100);
  }

  Future<void> _toggleMute() async {
    if (_volume > 0) {
      _volumeBeforeMute = _volume;
      await _setVolume(0);
    } else {
      await _setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 100);
    }
  }

  void _closeVolume() {
    _volumeEntry?.remove();
    _volumeEntry = null;
  }

  void _openVolume(BuildContext iconContext) {
    final box = iconContext.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final left = topLeft.dx + (box.size.width - _volumePopupWidth) / 2;
    final bottom = overlayBox.size.height - topLeft.dy + 4;
    final available = topLeft.dy - 4 - _volumePopupTopMargin;
    _volumePopupHeight = available < _volumePopupMaxHeight
        ? available
        : _volumePopupMaxHeight;
    _volumeEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeVolume,
            ),
          ),
          Positioned(
            left: left < 0 ? 0 : left,
            bottom: bottom,
            child: _volumePopup(),
          ),
        ],
      ),
    );
    overlay.insert(_volumeEntry!);
  }

  Widget _volumePopup() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 6,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: SizedBox(
        width: _volumePopupWidth,
        height: _volumePopupHeight,
        child: Column(
          children: [
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  key: const Key('miniplayer-volume-popup'),
                  value: _volume.clamp(0, 100),
                  max: 100,
                  onChanged: _setVolume,
                ),
              ),
            ),
            IconButton(
              key: const Key('miniplayer-mute'),
              tooltip: _volume > 0 ? 'remote.mute'.tr() : 'remote.unmute'.tr(),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: _volumePopupWidth,
                height: _volumePopupWidth,
              ),
              onPressed: _toggleMute,
              icon: Icon(
                _volume > 0 ? TablerIcons.volume : TablerIcons.volumeOff,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Layout do player do Controle Remoto (sem prévia): título, timeline
  /// com tempos e controles; o ícone de tela cheia abre o player inteiro.
  @override
  Widget build(BuildContext context) {
    final track = widget.notifier.track;
    if (track == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final playing = widget.notifier.isPlaying;
    final queue = PlaylistPlayer.instance;

    // Destaque: a música selecionada na lista está aqui (linha de cor no
    // topo + fundo levemente tingido), ligando a linha marcada ao player.
    return Material(
      elevation: 4,
      color: Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.08),
        theme.colorScheme.surfaceContainer,
      ),
      shape: Border(
        top: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      child: Padding(
        // Respiro entre os controles e a barra de navegação.
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_previewOpen)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                child: _preview(theme),
              ),
            InkWell(
              key: const Key('miniplayer-tap-area'),
              onTap: widget.onOpenPlayer,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (track.album.isNotEmpty)
                          Text(
                            track.album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if ((_slides?.slides.isNotEmpty ?? false))
                    IconButton(
                      key: const Key('miniplayer-preview-toggle'),
                      icon: Icon(
                        _previewOpen
                            ? TablerIcons.chevronDown
                            : TablerIcons.chevronUp,
                      ),
                      tooltip: _previewOpen
                          ? 'Esconder prévia'
                          : 'Mostrar prévia',
                      onPressed: () =>
                          setState(() => _previewOpen = !_previewOpen),
                    ),
                  IconButton(
                    key: const Key('miniplayer-expand'),
                    icon: const Icon(TablerIcons.maximize),
                    tooltip: 'Tela cheia',
                    onPressed: widget.onOpenPlayer,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                height: 28,
                child: PlayerTimeline(
                  key: const Key('miniplayer-timeline'),
                  positionStream: widget.player.positionStream,
                  durationStream: widget.player.durationStream,
                  onSeek: widget.player.seek,
                  fallbackDuration: Duration(
                    milliseconds: track.durationMs ?? 0,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Builder(
                  builder: (iconContext) => IconButton(
                    key: const Key('miniplayer-volume-button'),
                    tooltip: 'remote.volume'.tr(),
                    iconSize: 18,
                    onPressed: () => _openVolume(iconContext),
                    icon: Icon(
                      _volume > 0 ? TablerIcons.volume : TablerIcons.volumeOff,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('miniplayer-previous'),
                  icon: const Icon(TablerIcons.playerSkipBack),
                  onPressed: queue.canPrevious ? queue.previous : null,
                ),
                // Selecionada e ainda parada: o play pulsa primeiro.
                _Pulse(
                  pulse: !playing && _isPreparedOnly(),
                  child: IconButton.filled(
                    key: const Key('miniplayer-toggle'),
                    iconSize: 30,
                    icon: Icon(
                      playing ? TablerIcons.playerPause : TablerIcons.playerPlay,
                    ),
                    onPressed: _toggle,
                    tooltip: playing ? 'common.pause'.tr() : 'common.play'.tr(),
                  ),
                ),
                IconButton(
                  key: const Key('miniplayer-next'),
                  icon: const Icon(TablerIcons.playerSkipForward),
                  onPressed: queue.canNext ? queue.next : null,
                ),
                _PulsingArrow(
                  key: const Key('miniplayer-project'),
                  // Só depois de tocar: aí a seta pede para projetar.
                  pulse: playing && !projecting.value && !_projectBusy,
                  projecting: projecting.value,
                  busy: _projectBusy,
                  onPressed: _toggleProjection,
                ),
                // Controle remoto/palco: mesma sessão WS de antes.
                IconButton.outlined(
                  key: const Key('miniplayer-remote'),
                  icon: const Icon(TablerIcons.deviceTv, size: 20),
                  color: theme.colorScheme.primary,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const RemoteControlSheet(),
                  ),
                  tooltip: 'remote.title'.tr(),
                ),
                IconButton(
                  key: const Key('miniplayer-stop'),
                  icon: const Icon(TablerIcons.x),
                  onPressed: () {
                    queue.stop();
                    _stop();
                  },
                  tooltip: 'common.stop'.tr(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Seta de projetar do miniplayer (mesmo visual do Controle Remoto):
/// pulsa enquanto nada está projetado; ↓ cheia = projetando.
class _PulsingArrow extends StatefulWidget {
  final bool pulse;
  final bool projecting;
  final bool busy;
  final VoidCallback onPressed;

  const _PulsingArrow({
    super.key,
    required this.pulse,
    required this.projecting,
    required this.busy,
    required this.onPressed,
  });

  @override
  State<_PulsingArrow> createState() => _PulsingArrowState();
}

class _PulsingArrowState extends State<_PulsingArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 1.3,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_PulsingArrow old) {
    super.didUpdateWidget(old);
    if (old.pulse != widget.pulse) _sync();
  }

  void _sync() {
    if (widget.pulse) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _bold = [Offset(0.5, 0), Offset(-0.5, 0), Offset(0, 0.5), Offset(0, -0.5)];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    if (widget.busy) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return ScaleTransition(
      scale: _scale,
      child: IconButton(
        tooltip: widget.projecting ? 'Parar projeção' : 'Projetar nos selecionados',
        style: widget.projecting
            ? IconButton.styleFrom(backgroundColor: primary)
            : IconButton.styleFrom(
                backgroundColor: primary.withValues(alpha: 0.22),
                side: BorderSide(color: primary, width: 2),
              ),
        onPressed: widget.onPressed,
        icon: Icon(
          widget.projecting ? TablerIcons.arrowDown : TablerIcons.arrowUpRight,
          color: widget.projecting
              ? Theme.of(context).colorScheme.onPrimary
              : primary,
          shadows: [
            for (final o in _bold)
              Shadow(
                color: widget.projecting
                    ? Theme.of(context).colorScheme.onPrimary
                    : primary,
                offset: o,
              ),
          ],
        ),
      ),
    );
  }
}

/// Pulso de atenção (mesmo ritmo do Controle Remoto).
class _Pulse extends StatefulWidget {
  final bool pulse;
  final Widget child;

  const _Pulse({required this.pulse, required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 1.14,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    if (old.pulse != widget.pulse) _sync();
  }

  void _sync() {
    if (widget.pulse) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
