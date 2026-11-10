// Barra de controles do Controle Remoto, usada nas abas e na liturgia espelhada.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_player_presence.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_slide_gallery.dart';

/// Controles do player do alvo conectado.
///
/// Fonte dos controles: pianolouvorja/app/src/modules/media/components/MediaPlayerControls.vue
/// Quem decide o que cada comando faz é o desktop (remote/renderer/liturgy-bridge.ts).
class RemotePlayerBar extends StatefulWidget {
  const RemotePlayerBar({
    super.key,
    required this.state,
    this.pendingOpen,
    this.showTransport = false,
    this.send,
    this.videoFrame,
    this.compact = false,
    this.onExpand,
    this.onMinimize,
    this.navigatorKey,
  });

  /// Quadros da prévia do vídeo; default = sessão global. Injetável em teste.
  final ValueListenable<Uint8List?>? videoFrame;

  final RemotePlayerState state;
  final bool compact;
  final VoidCallback? onExpand;
  final VoidCallback? onMinimize;
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Item escolhido aguardando o play. Não nulo = botão pulsa e executa isto.
  final VoidCallback? pendingOpen;

  /// Mostra busca na faixa e navegação de slides (liturgia).
  final bool showTransport;

  /// Injetável para testes; default = sessão global.
  final Future<void> Function(RemoteCommand command)? send;

  @override
  State<RemotePlayerBar> createState() => _RemotePlayerBarState();
}

class _RemotePlayerBarState extends State<RemotePlayerBar> {
  bool _minimized = false;
  double? _dragVolume;
  OverlayEntry? _volumeEntry;

  static const _volumePopupMaxHeight = 380.0;
  static const _volumePopupWidth = 44.0;
  static const _volumePopupTopMargin = 16.0;

  double _volumePopupHeight = _volumePopupMaxHeight;
  double? _dragPositionMs;
  Timer? _seekEchoTimeout;
  static const _seekEchoLimit = Duration(seconds: 3);
  static const _seekEchoToleranceMs = 3000;
  int? _volumeBeforeMute;

  RemotePlayerState get _st => widget.state;

  /// Anterior/próximo item desativados por enquanto: voltam na playlist e no
  /// player das coletâneas e do hinário.
  static final bool _itemNavigationEnabled = false;

  // Slide escolhido no toque, mostrado antes do desktop confirmar.
  int? _pendingSlide;
  Timer? _slideEchoTimeout;
  static const _slideEchoLimit = Duration(milliseconds: 1500);

  int get _slideIndex => _pendingSlide ?? _st.slideIndex;

  void _goToSlide(int delta) {
    final target = (_slideIndex + delta).clamp(0, _st.slideCount - 1);
    _slideEchoTimeout?.cancel();
    _slideEchoTimeout = Timer(_slideEchoLimit, () {
      if (mounted) setState(() => _pendingSlide = null);
    });
    setState(() => _pendingSlide = target);
    _send(delta > 0 ? RemoteAction.slideNext : RemoteAction.slidePrevious);
  }

  void _releaseSeek() {
    _seekEchoTimeout?.cancel();
    _seekEchoTimeout = null;
    if (mounted) setState(() => _dragPositionMs = null);
  }

  @override
  void didUpdateWidget(RemotePlayerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_minimized && (
        (widget.pendingOpen != null && oldWidget.pendingOpen != widget.pendingOpen) ||
        oldWidget.state.hymnId != _st.hymnId || oldWidget.state.title != _st.title)) {
      _minimized = false;
    }
    if (_volumeEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _volumeEntry?.markNeedsBuild(),
      );
    }
    RemoteSlideGallery.remember(_st);
    if (_pendingSlide != null && _st.slideIndex == _pendingSlide) {
      _slideEchoTimeout?.cancel();
      _pendingSlide = null;
    }
    final target = _dragPositionMs;
    if (_seekEchoTimeout == null || target == null) return;
    final distance = (_st.position.inMilliseconds - target).abs();
    if (distance > _seekEchoToleranceMs) return;
    _seekEchoTimeout?.cancel();
    _seekEchoTimeout = null;
    _dragPositionMs = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) => remotePlayerPresence.update(this, false));
    _closeVolume();
    _seekEchoTimeout?.cancel();
    _slideEchoTimeout?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    RemoteSlideGallery.remember(_st);
  }

  /// Miniatura do slide mostrado: da galeria guardada, senão a do estado.
  Uint8List? get _previewBytes {
    final cached = RemoteSlideGallery.thumb(_st.slideGalleryKey, _slideIndex);
    if (cached != null) return cached;
    final source = _st.slidePreview;
    if (source == null) return null;
    if (source != _previewSource) {
      _previewSource = source;
      _decodedPreview = RemoteSlideGallery.decode(source);
    }
    return _decodedPreview;
  }

  Future<void> _send(
    RemoteAction action, {
    int? volume,
    Duration? position,
    String? mode,
    String? targetId,
    bool? enabled,
  }) async {
    final command = RemoteCommand(
      id: 'b${DateTime.now().microsecondsSinceEpoch}',
      action: action,
      volume: volume,
      position: position,
      mode: mode,
      targetId: targetId,
      enabled: enabled,
    );
    await (widget.send ?? RemoteSession.instance.send)(command);
  }

  void _openVolume(BuildContext iconContext) {
    final box = iconContext.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final left = topLeft.dx + (box.size.width - _volumePopupWidth) / 2;
    final bottom = overlayBox.size.height - topLeft.dy + AppSpacing.s1;
    final available = topLeft.dy - AppSpacing.s1 - _volumePopupTopMargin;
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
                  key: const Key('remote-volume-popup'),
                  value: _dragVolume ?? _st.volume.clamp(0, 100).toDouble(),
                  max: 100,
                  // Só envia ao soltar: evita flood WS no drag.
                  onChanged: _setDragVolume,
                  onChangeEnd: _commitVolume,
                ),
              ),
            ),
            IconButton(
              key: const Key('remote-mute'),
              tooltip: _st.volume > 0
                  ? 'remote.mute'.tr()
                  : 'remote.unmute'.tr(),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: _volumePopupWidth,
                height: _volumePopupWidth,
              ),
              onPressed: _toggleMute,
              icon: Icon(
                _st.volume > 0 ? TablerIcons.volume : TablerIcons.volumeOff,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setDragVolume(double value) {
    setState(() => _dragVolume = value);
    _volumeEntry?.markNeedsBuild();
  }

  Future<void> _commitVolume(double value) async {
    await _send(RemoteAction.setVolume, volume: value.round());
    if (!mounted) return;
    setState(() => _dragVolume = null);
    _volumeEntry?.markNeedsBuild();
  }

  void _closeVolume() {
    _volumeEntry?.remove();
    _volumeEntry = null;
  }

  void _toggleMute() {
    if (_st.volume > 0) {
      _volumeBeforeMute = _st.volume;
      _send(RemoteAction.setVolume, volume: 0);
    } else {
      _send(RemoteAction.setVolume, volume: _volumeBeforeMute ?? 100);
    }
  }

  bool get _mediaOpen => _st.hasOpenMedia;

  /// Item pendente tem prioridade; sem ele, o play só age sobre mídia aberta.
  VoidCallback? get _playAction {
    if (widget.pendingOpen != null) return widget.pendingOpen;
    if (!_mediaOpen) return null;
    return () => _send(_st.playing ? RemoteAction.pause : RemoteAction.play);
  }

  String _clock(int ms) {
    final total = ms ~/ 1000;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = !widget.compact && !_minimized && TickerMode.valuesOf(context).enabled && (ModalRoute.isCurrentOf(context) ?? true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      remotePlayerPresence.update(this, mounted && visible);
    });
    if (widget.compact) return _compact(theme);
    if (_minimized) return const SizedBox.shrink();
    final showPause = _st.playing && widget.pendingOpen == null;
    final slideCount = _st.slideCount;
    final durationMs = _st.duration.inMilliseconds;
    // O desktop executa o item vizinho na hora: com mídia aberta, tocaria junto.
    final canNavigate = _itemNavigationEnabled && !_mediaOpen;

    return Container(
      key: const Key('remote-player-bar'),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showTransport || widget.onMinimize != null)
              Row(children: [
                Expanded(child: Text(_st.title ?? '', maxLines: 1,
                  overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary))),
                IconButton(
                  key: const Key('remote-player-minimize'),
                  color: theme.colorScheme.primary,
                  tooltip: 'common.minimize'.tr(),
                  onPressed: widget.onMinimize ?? () => setState(() => _minimized = true),
                  icon: const Icon(TablerIcons.minus),
                ),
              ])
            else if (_st.title != null)
              Text(
                _st.title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
              ),
            if (_previewBytes case final bytes?)
              _preview(bytes)
            else if (_currentLyric case final lyric?)
              _lyricPreview(theme, lyric)
            else if (_st.videoControls != null)
              _videoFramePreview(),
            if (widget.showTransport) _videoControls(theme, _st.videoControls),
            if (widget.showTransport && slideCount > 1)
              _slides(theme, slideCount),
            if (widget.showTransport && durationMs > 0)
              _seek(theme, durationMs),
            const SizedBox(height: AppSpacing.s2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Builder(
                  builder: (iconContext) => IconButton(
                    key: const Key('remote-volume-button'),
                    tooltip: 'remote.volume'.tr(),
                    iconSize: 18,
                    onPressed: () => _openVolume(iconContext),
                    icon: Icon(
                      _st.volume > 0
                          ? TablerIcons.volume
                          : TablerIcons.volumeOff,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'remote.previous'.tr(),
                  onPressed: canNavigate && _st.canPrevious
                      ? () => _send(RemoteAction.previous)
                      : null,
                  icon: const Icon(TablerIcons.playerSkipBack),
                ),
                _PulsingAttention(
                  pulse: widget.pendingOpen != null,
                  child: IconButton.filled(
                    key: const Key('remote-play-button'),
                    iconSize: 36,
                    tooltip: showPause
                        ? 'remote.pause'.tr()
                        : 'remote.play'.tr(),
                    onPressed: _playAction,
                    icon: Icon(
                      showPause
                          ? TablerIcons.playerPause
                          : TablerIcons.playerPlay,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'remote.next'.tr(),
                  onPressed: canNavigate && _st.canNext
                      ? () => _send(RemoteAction.next)
                      : null,
                  icon: const Icon(TablerIcons.playerSkipForward),
                ),
                _lastAction(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _compact(ThemeData theme) {
    return Material(
      key: const Key('remote-mini-player'),
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.s2,
          right: AppSpacing.s2,
          bottom: AppSpacing.s2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _st.title ?? 'remote.title'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                IconButton(
                  key: const Key('remote-mini-close'),
                  tooltip: 'remote.video.closeMedia'.tr(),
                  icon: const Icon(TablerIcons.x),
                  onPressed: _confirmClose,
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 112,
                  height: 72,
                  child: _previewBytes != null
                      ? _preview(_previewBytes!)
                      : _currentLyric != null
                      ? _lyricPreview(theme, _currentLyric!)
                      : _st.videoControls != null
                      ? _videoFramePreview()
                      : const Icon(TablerIcons.music),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        key: const Key('remote-mini-toggle'),
                        tooltip: (_st.playing ? 'remote.pause' : 'remote.play')
                            .tr(),
                        icon: Icon(
                          _st.playing
                              ? TablerIcons.playerPause
                              : TablerIcons.playerPlay,
                        ),
                        onPressed: _playAction,
                      ),
                      IconButton(
                        key: const Key('remote-mini-expand'),
                        tooltip: 'remote.title'.tr(),
                        icon: const Icon(TablerIcons.maximize),
                        onPressed: widget.onExpand,
                      ),
                      if (_st.videoControls != null)
                        _lastAction(theme, includeClose: false),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Com barra de vídeo o último botão projeta; hino aberto mantém o stop.
  Widget _lastAction(ThemeData theme, {bool includeClose = true}) {
    final video = _st.videoControls;
    final keepStop = (!widget.showTransport && !widget.compact) || (video == null && _mediaOpen);
    if (keepStop) {
      return IconButton(
        tooltip: 'remote.stop'.tr(),
        onPressed: _confirmClose,
        icon: const Icon(TablerIcons.playerStop),
      );
    }
    final projecting = video?.projecting ?? false;
    final canProject = video?.canProject ?? false;
    final pulsing = canProject && !projecting;
    final primary = theme.colorScheme.primary;
    final color = projecting || canProject
        ? primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    final project = _PulsingAttention(
      pulse: pulsing,
      pulseKey: const Key('remote-project-pulse'),
      maxScale: 1.3,
      period: const Duration(milliseconds: 450),
      child: IconButton(
        key: const Key('remote-video-project'),
        tooltip: projecting
            ? 'remote.stopProjection'.tr()
            : 'remote.project'.tr(),
        isSelected: projecting,
        style: pulsing
            ? IconButton.styleFrom(
                backgroundColor: primary.withValues(alpha: 0.22),
                side: BorderSide(color: primary, width: 2),
              )
            : null,
        onPressed: projecting || canProject
            ? () => _send(RemoteAction.videoToggleProjection)
            : null,
        icon: Icon(
          projecting ? TablerIcons.arrowDown : TablerIcons.arrowUpRight,
          color: color,
          // A fonte Tabler tem peso único: o contorno engrossa o traço.
          shadows: [
            for (final offset in _boldOffsets)
              Shadow(color: color, offset: offset),
          ],
        ),
      ),
    );
    if (video == null || !includeClose) return project;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        project,
        IconButton(
          key: const Key('remote-close-media'),
          tooltip: 'remote.video.closeMedia'.tr(),
          onPressed: _confirmClose,
          icon: const Icon(TablerIcons.x),
        ),
      ],
    );
  }

  // Decodifica só quando a imagem muda: o estado chega várias vezes por segundo.
  String? _previewSource;
  Uint8List? _decodedPreview;

  /// Letra do slide mostrado (hino): acompanha o toque na seta, sem esperar.
  String? get _currentLyric {
    final lyrics = _st.slideLyrics;
    final index = _slideIndex;
    if (lyrics == null || index < 0 || index >= lyrics.length) return null;
    return lyrics[index];
  }

  Widget _lyricPreview(ThemeData theme, String lyric) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        // 16:9 como a tela projetada; a letra encolhe para caber inteira.
        child: _previewFrame(
          key: const Key('remote-lyric-preview'),
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_lyricBackground() case final background?)
                  Positioned.fill(child: background),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      lyric,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        shadows: const [Shadow(blurRadius: 6)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Moldura 16:9 da prévia, limitada a 30% da altura da tela para a barra
  /// caber em celular baixo ou deitado.
  Widget _previewFrame({Key? key, required Widget child}) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.3;
    return ConstrainedBox(
      key: key,
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Center(
        child: AspectRatio(aspectRatio: 16 / 9, child: child),
      ),
    );
  }

  /// Fundo do slide atrás da letra, escurecido para a letra continuar legível.
  Widget? _lyricBackground() {
    final background = RemoteSlideGallery.background(_st, _slideIndex);
    final Widget? image = switch (background) {
      final Uint8List bytes => Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
      final String url => Image.network(
        url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
      _ => null,
    };
    if (image == null) return null;
    return Stack(
      key: const Key('remote-lyric-background'),
      fit: StackFit.expand,
      children: [
        image,
        const ColoredBox(color: Color(0x73000000)),
      ],
    );
  }

  /// Vídeo/YouTube aberto: só a imagem escuta os quadros, a barra não reconstrói.
  Widget _videoFramePreview() {
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: widget.videoFrame ?? RemoteSession.instance.videoFrame,
      builder: (context, bytes, _) {
        if (bytes == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _previewFrame(
              child: ColoredBox(
                color: Colors.black,
                child: Image.memory(
                  bytes,
                  key: const Key('remote-video-frame'),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// O que está na tela do desktop, para o operador conferir pelo celular.
  Widget _preview(Uint8List bytes) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _previewFrame(
          child: ColoredBox(
            color: Colors.black,
            child: Image.memory(
              bytes,
              key: const Key('remote-slide-preview'),
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }

  /// Fechar encerra o que toca no desktop: um toque acidental não pode fazer isso.
  Future<void> _confirmClose() async {
    final confirmed = await showDialog<bool>(
      context: widget.navigatorKey?.currentContext ?? context,
      builder: (context) => AlertDialog(
        key: const Key('remote-close-confirm'),
        title: Text('remote.video.closeConfirmTitle'.tr()),
        content: Text('remote.video.closeConfirmMessage'.tr()),
        actions: [
          TextButton(
            key: const Key('remote-close-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text('remote.video.closeConfirmCancel'.tr()),
          ),
          FilledButton(
            key: const Key('remote-close-ok'),
            onPressed: () => Navigator.pop(context, true),
            child: Text('remote.video.closeConfirmOk'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) _send(RemoteAction.stop);
  }

  static const _boldOffsets = [
    Offset(0.6, 0),
    Offset(-0.6, 0),
    Offset(0, 0.6),
    Offset(0, -0.6),
  ];

  static const _audioOutputs = {
    'player': 'remote.video.audioPlayer',
    'connections': 'remote.video.audioConnections',
    'both': 'remote.video.audioBoth',
  };

  Widget _videoControls(ThemeData theme, RemoteVideoControls? video) {
    final selectedMonitors = [
      ..._targetMonitors(_st),
      ..._targetTvs(_st),
    ].where((m) => m.selected).length;
    final independent = video?.independent ?? _st.idleIndependent;
    final independentHot =
        independent != null && (independent.live || independent.armed);
    final audioOutput = video?.audioOutput ?? 'player';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(
          child: PopupMenuButton<String>(
            key: const Key('remote-audio-output'),
            tooltip: 'remote.video.audioDestination'.tr(),
            enabled: video != null,
            initialValue: audioOutput,
            onSelected: (mode) =>
                _send(RemoteAction.videoSetAudioOutput, mode: mode),
            itemBuilder: (_) => [
              for (final entry in _audioOutputs.entries)
                PopupMenuItem(
                  key: Key('remote-audio-option-${entry.key}'),
                  value: entry.key,
                  child: Text(entry.value.tr()),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(TablerIcons.speakerphone, size: 18),
                const SizedBox(width: AppSpacing.s1),
                Flexible(
                  child: Text(
                    (_audioOutputs[audioOutput] ?? 'remote.video.audioPlayer')
                        .tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                const Icon(TablerIcons.chevronDown, size: 16),
              ],
            ),
          ),
        ),
        IconButton(
          key: const Key('remote-video-targets'),
          tooltip: 'remote.video.selectScreens'.tr(),
          onPressed: _openTargets,
          icon: Badge(
            label: Text('$selectedMonitors'),
            isLabelVisible: selectedMonitors > 0,
            child: const Icon(TablerIcons.deviceDesktop),
          ),
        ),
        IconButton(
          key: const Key('remote-independent'),
          tooltip: 'remote.video.independent'.tr(),
          color: independentHot ? theme.colorScheme.primary : null,
          onPressed: _openIndependent,
          icon: const Icon(TablerIcons.devices),
        ),
        if (video != null && video.canControlCaptions)
          IconButton(
            key: const Key('remote-video-captions'),
            tooltip: video.captionsHidden
                ? 'remote.video.showCaptions'.tr()
                : 'remote.video.hideCaptions'.tr(),
            color: video.captionsHidden
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
            onPressed: () => _send(RemoteAction.videoToggleCaptions),
            icon: const Icon(TablerIcons.badgeCc),
          ),
      ],
    );
  }

  static List<RemoteVideoTarget> _targetMonitors(RemotePlayerState state) =>
      state.videoControls?.monitors ?? state.idleVideoTargets;

  static List<RemoteVideoTarget> _targetTvs(RemotePlayerState state) =>
      state.videoControls?.tvs ?? state.idleVideoTvs;

  void _openTargets() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _VideoTargetsSheet(
        initial: _st,
        onChanged: (id, enabled) =>
            _send(RemoteAction.videoSetTarget, targetId: id, enabled: enabled),
      ),
    );
  }

  void _openIndependent() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IndependentSheet(
        initial: _st,
        onMode: (mode) =>
            _send(RemoteAction.videoSetIndependentMode, mode: mode),
        onTarget: (id, enabled) => _send(
          RemoteAction.videoSetIndependentTarget,
          targetId: id,
          enabled: enabled,
        ),
      ),
    );
  }

  Widget _slides(ThemeData theme, int count) {
    final index = _slideIndex;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const Key('remote-slide-prev'),
          tooltip: 'remote.previousSlide'.tr(),
          onPressed: index > 0 ? () => _goToSlide(-1) : null,
          icon: const Icon(TablerIcons.chevronLeft),
        ),
        Text('${index + 1} / $count', style: theme.textTheme.labelMedium),
        IconButton(
          key: const Key('remote-slide-next'),
          tooltip: 'remote.nextSlide'.tr(),
          onPressed: index < count - 1 ? () => _goToSlide(1) : null,
          icon: const Icon(TablerIcons.chevronRight),
        ),
      ],
    );
  }

  Widget _seek(ThemeData theme, int durationMs) {
    final max = durationMs.toDouble();
    final value =
        _dragPositionMs ?? _st.position.inMilliseconds.toDouble().clamp(0, max);
    return Row(
      children: [
        Text(_clock(value.toInt()), style: theme.textTheme.labelSmall),
        Expanded(
          child: Slider(
            key: const Key('remote-seek'),
            value: value.toDouble(),
            max: max,
            onChanged: (v) => setState(() => _dragPositionMs = v),
            onChangeEnd: (v) {
              // Mantém a posição escolhida até o desktop confirmar.
              _seekEchoTimeout?.cancel();
              _seekEchoTimeout = Timer(_seekEchoLimit, _releaseSeek);
              _send(
                RemoteAction.seek,
                position: Duration(milliseconds: v.round()),
              );
            },
          ),
        ),
        Text(_clock(durationMs), style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// Telas e TVs de destino; acompanha o estado que chega do desktop.
class _VideoTargetsSheet extends StatelessWidget {
  const _VideoTargetsSheet({required this.initial, required this.onChanged});

  final RemotePlayerState initial;
  final void Function(String id, bool enabled) onChanged;

  Widget _tile(RemoteVideoTarget target, IconData icon) => CheckboxListTile(
    key: Key('remote-target-${target.id}'),
    value: target.selected,
    secondary: Icon(icon),
    title: Text(target.label),
    subtitle: target.detail == null ? null : Text(target.detail!),
    onChanged: (value) => onChanged(target.id, value == true),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<RemotePlayerState>(
        stream: RemoteSession.instance.states,
        builder: (context, snapshot) {
          final state = snapshot.data ?? initial;
          final monitors = _RemotePlayerBarState._targetMonitors(state);
          final tvs = _RemotePlayerBarState._targetTvs(state);
          final empty = monitors.isEmpty && tvs.isEmpty;
          return ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  'remote.video.selectScreens'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (empty) ListTile(title: Text('remote.video.noScreens'.tr())),
              for (final monitor in monitors)
                _tile(monitor, TablerIcons.deviceDesktop),
              if (tvs.isNotEmpty) ...[
                const Divider(),
                ListTile(
                  dense: true,
                  title: Text(
                    'remote.video.remoteConnections'.tr(),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                for (final tv in tvs) _tile(tv, TablerIcons.deviceTv),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Projeção independente; marcar só escolhe, quem projeta é a seta da barra.
class _IndependentSheet extends StatelessWidget {
  const _IndependentSheet({
    required this.initial,
    required this.onMode,
    required this.onTarget,
  });

  final RemotePlayerState initial;
  final ValueChanged<String> onMode;
  final void Function(String id, bool enabled) onTarget;

  Widget _tile(BuildContext context, RemoteVideoTarget target, IconData icon) {
    final theme = Theme.of(context);
    final details = [
      if (target.detail != null) target.detail!,
      if (!target.enabled) 'remote.video.enableInScreens'.tr(),
    ];
    return CheckboxListTile(
      key: Key('remote-independent-${target.id}'),
      value: target.selected,
      secondary: Icon(icon),
      title: Row(
        children: [
          Flexible(child: Text(target.label)),
          if (target.onAir) ...[
            const SizedBox(width: AppSpacing.s2),
            Text(
              'remote.video.onAir'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      onChanged: target.enabled
          ? (value) => onTarget(target.id, value == true)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: StreamBuilder<RemotePlayerState>(
        stream: RemoteSession.instance.states,
        builder: (context, snapshot) {
          final state = snapshot.data ?? initial;
          final independent =
              state.videoControls?.independent ?? state.idleIndependent;
          if (independent == null) {
            return ListTile(title: Text('remote.video.noScreens'.tr()));
          }
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            children: [
              ListTile(
                title: Text(
                  'remote.video.independent'.tr(),
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Text('remote.video.independentHint'.tr()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                child: Wrap(
                  spacing: AppSpacing.s2,
                  children: [
                    for (final mode in const ['overlay', 'share'])
                      ChoiceChip(
                        key: Key('remote-independent-mode-$mode'),
                        label: Text('remote.video.mode_$mode'.tr()),
                        selected: independent.mode == mode,
                        onSelected: (_) => onMode(mode),
                        selectedColor: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        checkmarkColor: theme.colorScheme.primary,
                        labelStyle: TextStyle(
                          color: independent.mode == mode
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              if (independent.monitors.isEmpty)
                ListTile(title: Text('remote.video.noScreens'.tr())),
              for (final monitor in independent.monitors)
                _tile(context, monitor, TablerIcons.deviceDesktop),
              ListTile(
                dense: true,
                title: Text(
                  'remote.video.remoteConnections'.tr(),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (independent.remotes.isEmpty)
                ListTile(title: Text('remote.video.noRemotes'.tr())),
              for (final remote in independent.remotes)
                _tile(context, remote, TablerIcons.deviceTv),
            ],
          );
        },
      ),
    );
  }
}

/// Pulsa o [child] enquanto [pulse] for true, para chamar a atencao.
class _PulsingAttention extends StatefulWidget {
  const _PulsingAttention({
    required this.pulse,
    required this.child,
    this.pulseKey = const Key('remote-play-pulse'),
    this.maxScale = 1.14,
    this.period = const Duration(milliseconds: 650),
  });

  final bool pulse;
  final Widget child;
  final Key pulseKey;
  final double maxScale;
  final Duration period;

  @override
  State<_PulsingAttention> createState() => _PulsingAttentionState();
}

class _PulsingAttentionState extends State<_PulsingAttention>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.period,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: widget.maxScale,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_PulsingAttention oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse) _sync();
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
  Widget build(BuildContext context) {
    return ScaleTransition(
      key: widget.pulse ? widget.pulseKey : null,
      scale: _scale,
      child: widget.child,
    );
  }
}
