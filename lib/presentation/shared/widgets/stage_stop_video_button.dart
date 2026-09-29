library;

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../core/services/dlna/stage_session.dart';

/// F3.3w: controles do vídeo projetado — aparece no AppBar somente
/// enquanto um vídeo (item de vídeo da liturgia) roda no Palco.
/// Pause/continua decide na TV (mesma tecla), parar devolve ao idle.
class StageStopVideoButton extends StatelessWidget {
  const StageStopVideoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StageSession.instance,
      builder: (context, _) {
        final stage = StageSession.instance;
        if (!stage.isVideoOnStage) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: stage.isStageVideoPaused
                  ? 'Continuar vídeo'
                  : 'Pausar vídeo',
              icon: Icon(
                stage.isStageVideoPaused
                    ? TablerIcons.playerPlay
                    : TablerIcons.playerPause,
              ),
              onPressed: () => stage.toggleStageVideoPause(),
            ),
            IconButton(
              tooltip: 'Parar vídeo no Palco',
              icon: Icon(
                TablerIcons.playerStop,
                color: theme.colorScheme.error,
              ),
              onPressed: () {
                stage.stopVideoOnStage();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vídeo interrompido — Palco em idle'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
