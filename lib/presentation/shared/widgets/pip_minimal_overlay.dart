library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_player_adapter.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';

/// SPEC 13 (apk#132): overlay minimalista do PiP pra QUALQUER rota.
///
/// Se o usuário fecha o NowPlaying dentro da janelinha, o PiP passa a
/// mostrar a rota de baixo (home etc.) — que não conhece PiP. Este overlay
/// substitui a árvore INTEIRA em modo PiP (MaterialApp.builder): layout
/// mínimo título + tempo + prev/play/next com os tokens do app.
class PipMinimalOverlay extends StatefulWidget {
  const PipMinimalOverlay({super.key});

  @override
  State<PipMinimalOverlay> createState() => _PipMinimalOverlayState();
}

class _PipMinimalOverlayState extends State<PipMinimalOverlay> {
  static final _player = HymnPlayerAdapter(HymnAudioPlayer.instance);
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  final ValueNotifier<Duration?> _pos = ValueNotifier<Duration?>(null);
  final ValueNotifier<Duration?> _dur = ValueNotifier<Duration?>(null);

  @override
  void initState() {
    super.initState();
    _posSub = _player.positionStream.listen((d) => _pos.value = d);
    _durSub = _player.durationStream.listen((d) {
      if (d.inMilliseconds > 0) _dur.value = d;
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _pos.dispose();
    _dur.dispose();
    super.dispose();
  }

  static String _fmt(Duration? d) {
    if (d == null) return '0:00';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Design tokens do TEMA ATIVO: accent escolhido pelo usuário + dark/light.
    final scheme = theme.colorScheme;
    final track = nowPlaying.track;
    final title = track?.detail?.title ?? 'hymns.nowPlaying'.tr();
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<Duration?>(
              valueListenable: _pos,
              builder: (context, pos, _) => Text(
                '${_fmt(pos)} / ${_fmt(_dur.value)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: _player.playingListenable,
              builder: (context, playing, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      TablerIcons.chevronLeft,
                      color: scheme.onSurface,
                    ),
                    onPressed: () => _skip(-15),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    iconSize: 44,
                    icon: Icon(
                      playing
                          ? TablerIcons.playerPause
                          : TablerIcons.playerPlay,
                      color: scheme.primary,
                    ),
                    onPressed: () async {
                      if (_player.isPlaying) {
                        await _player.pause();
                      } else {
                        await _player.resume();
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(
                      TablerIcons.chevronRight,
                      color: scheme.onSurface,
                    ),
                    onPressed: () => _skip(15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sem contexto de slides aqui (rota pode ser qualquer uma): prev/next
  /// viram ±15s — o mesmo comportamento da notificação de mídia.
  Future<void> _skip(int seconds) async {
    final dur = _dur.value;
    final pos = _pos.value ?? Duration.zero;
    var target = pos + Duration(seconds: seconds);
    if (dur != null && target > dur) target = dur;
    if (target < Duration.zero) target = Duration.zero;
    await _player.seek(target);
  }
}
