library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../core/services/now_playing.dart';
import '../../../../core/services/dlna/stage_session.dart';
import '../../../../core/services/palco/palco_controller.dart'
    show PalcoAudioRoute;
import '../../palco/remote_control_sheet.dart';
import 'player_timeline.dart';

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
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onChanged);
    widget.player.playingListenable.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onChanged() {
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
    } else {
      await widget.player.resume();
      widget.notifier.setPlaying(true);
      stage.rerouteCurrentAudio();
    }
  }

  Future<void> _stop() async {
    await widget.player.stop();
    widget.notifier.stop();
    StageSession.instance.stopHymnAudio(); // espelha no Palco
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.notifier.track;
    if (track == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final playing = widget.notifier.isPlaying;

    return Material(
      elevation: 4,
      color: theme.colorScheme.surfaceContainer,
      child: InkWell(
        key: const Key('miniplayer-tap-area'),
        onTap: widget.onOpenPlayer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(
                TablerIcons.music,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      track.album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // Timeline compacta (paridade Player.vue footer): seek
                    // direto no miniplayer sem abrir tela cheia.
                    SizedBox(
                      height: 18,
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
                  ],
                ),
              ),
              IconButton(
                key: const Key('miniplayer-toggle'),
                icon: Icon(
                  playing ? TablerIcons.playerPause : TablerIcons.playerPlay,
                ),
                color: theme.colorScheme.primary,
                onPressed: _toggle,
                tooltip: playing ? 'common.pause'.tr() : 'common.play'.tr(),
              ),
              IconButton(
                key: const Key('miniplayer-stop'),
                icon: const Icon(TablerIcons.playerStop),
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: _stop,
                tooltip: 'common.stop'.tr(),
              ),
              // Controle remoto: comanda o player do desktop/web
              // conectado ao Palco (mesma sessão WS).
              IconButton(
                key: const Key('miniplayer-remote'),
                icon: const Icon(TablerIcons.deviceTv),
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const RemoteControlSheet(),
                ),
                tooltip: 'remote.title'.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
