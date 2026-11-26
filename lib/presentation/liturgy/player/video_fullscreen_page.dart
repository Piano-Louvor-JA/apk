import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

/// Tela cheia do vídeo e do YouTube da Liturgia (como a dos slides dos
/// hinos): o vídeo ocupa a tela, com título, tempo e play/pausa por cima.
/// Libera o giro para paisagem enquanto aberta; ao sair, o app volta em pé.
class VideoFullscreenPage extends StatefulWidget {
  const VideoFullscreenPage({
    super.key,
    required this.initial,
    required this.states,
    required this.send,
    required this.video,
  });

  final RemotePlayerState initial;
  final Stream<RemotePlayerState> states;
  final Future<void> Function(RemoteCommand command) send;

  /// O mesmo vídeo da barra (VideoPlayer ou o espaço do player web).
  final Widget video;

  static Route<void> route({
    required RemotePlayerState initial,
    required Stream<RemotePlayerState> states,
    required Future<void> Function(RemoteCommand command) send,
    required Widget video,
  }) => PageRouteBuilder<void>(
    opaque: true,
    pageBuilder: (_, _, _) => VideoFullscreenPage(
      initial: initial,
      states: states,
      send: send,
      video: video,
    ),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  /// Aberta agora: o player minimizado da Liturgia não aparece por cima.
  static final open = ValueNotifier<bool>(false);

  @override
  State<VideoFullscreenPage> createState() => _VideoFullscreenPageState();
}

class _VideoFullscreenPageState extends State<VideoFullscreenPage> {
  double? _dragMs;
  double? _dragVolume;
  int? _volumeBeforeMute;
  bool _volumeOpen = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    VideoFullscreenPage.open.value = true;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    VideoFullscreenPage.open.value = false;
    // O app é só em pé (main.dart).
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exit() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  Future<void> _command(
    RemoteAction action, {
    Duration? position,
    int? volume,
  }) => widget.send(
    RemoteCommand(
      id: 'fs${DateTime.now().microsecondsSinceEpoch}',
      action: action,
      position: position,
      volume: volume,
    ),
  );

  void _toggleMute(int volume) {
    if (volume > 0) {
      _volumeBeforeMute = volume;
      _command(RemoteAction.setVolume, volume: 0);
    } else {
      _command(RemoteAction.setVolume, volume: _volumeBeforeMute ?? 100);
    }
  }

  /// Áudio, como na barra do player: o ícone abre o volume para cima
  /// (barra vertical com o mudo embaixo); envia só ao soltar a barra.
  Widget _audio(RemotePlayerState state) {
    final volume = state.volume.clamp(0, 100);
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_volumeOpen)
            Material(
              key: const Key('video-fullscreen-volume-panel'),
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 44,
                height: 180,
                child: Column(
                  children: [
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          key: const Key('video-fullscreen-volume'),
                          value: _dragVolume ?? volume.toDouble(),
                          max: 100,
                          onChanged: (v) => setState(() => _dragVolume = v),
                          onChangeEnd: (v) {
                            setState(() => _dragVolume = null);
                            _command(RemoteAction.setVolume, volume: v.round());
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('video-fullscreen-mute'),
                      tooltip: (volume > 0 ? 'remote.mute' : 'remote.unmute')
                          .tr(),
                      iconSize: 18,
                      onPressed: () => _toggleMute(volume),
                      icon: Icon(
                        volume > 0 ? TablerIcons.volume : TablerIcons.volumeOff,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            key: const Key('video-fullscreen-audio'),
            tooltip: 'remote.volume'.tr(),
            color: Colors.white,
            onPressed: () => setState(() => _volumeOpen = !_volumeOpen),
            icon: Icon(volume > 0 ? TablerIcons.volume : TablerIcons.volumeOff),
          ),
        ],
      ),
    );
  }

  static String _clock(int ms) {
    final total = ms ~/ 1000;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onVideo = Colors.white;
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<RemotePlayerState>(
        stream: widget.states,
        initialData: widget.initial,
        builder: (context, snapshot) {
          final state = snapshot.data ?? widget.initial;
          // Mídia fechada (pela barra, pelo fim da liturgia): sai junto.
          if (!state.hasOpenMedia) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _exit();
            });
          }
          final durationMs = state.duration.inMilliseconds;
          final max = durationMs <= 0 ? 1.0 : durationMs.toDouble();
          final value = (_dragMs ?? state.position.inMilliseconds.toDouble())
              .clamp(0.0, max);
          return SafeArea(
            // Coluna, sem nada por cima do vídeo: o YouTube é uma WebView
            // desenhada numa camada acima do app e esconderia os controles.
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key('video-fullscreen-exit'),
                      tooltip: 'remote.video.exitFullscreen'.tr(),
                      color: onVideo,
                      onPressed: _exit,
                      icon: const Icon(TablerIcons.minimize),
                    ),
                    Expanded(
                      child: Text(
                        state.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: onVideo,
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(child: Center(child: widget.video)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _audio(state),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('video-fullscreen-play'),
                        tooltip:
                            (state.playing ? 'remote.pause' : 'remote.play')
                                .tr(),
                        color: onVideo,
                        iconSize: 32,
                        onPressed: () => _command(
                          state.playing
                              ? RemoteAction.pause
                              : RemoteAction.play,
                        ),
                        icon: Icon(
                          state.playing
                              ? TablerIcons.playerPauseFilled
                              : TablerIcons.playerPlayFilled,
                        ),
                      ),
                      Text(
                        _clock(value.toInt()),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onVideo,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          key: const Key('video-fullscreen-seek'),
                          value: value,
                          max: max,
                          onChanged: durationMs <= 0
                              ? null
                              : (v) => setState(() => _dragMs = v),
                          onChangeEnd: (v) {
                            setState(() => _dragMs = null);
                            _command(
                              RemoteAction.seek,
                              position: Duration(milliseconds: v.round()),
                            );
                          },
                        ),
                      ),
                      Text(
                        _clock(durationMs),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onVideo,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
