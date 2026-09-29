library;

import 'dart:async';

import 'package:flutter/material.dart';

/// Timeline de reprodução: posição atual, seek tocável e duração.
///
/// Espelha o v-progress-linear do Player.vue (desktop): clique/toque
/// move a reprodução. Tempos formatados mm:ss nas extremidades.
class PlayerTimeline extends StatefulWidget {
  final Stream<Duration> positionStream;
  final Stream<Duration> durationStream;
  final Future<void> Function(Duration) onSeek;

  /// Duração do catálogo. Fallback para MP3s cujo decoder Android toca,
  /// mas não emite onDurationChanged (caso dos hinários legados).
  final Duration fallbackDuration;

  const PlayerTimeline({
    super.key,
    required this.positionStream,
    required this.durationStream,
    required this.onSeek,
    this.fallbackDuration = Duration.zero,
  });

  @override
  State<PlayerTimeline> createState() => _PlayerTimelineState();
}

class _PlayerTimelineState extends State<PlayerTimeline> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _dragging = false;
  double? _dragValue;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  @override
  void initState() {
    super.initState();
    _duration = widget.fallbackDuration;
    _posSub = widget.positionStream.listen((p) {
      if (mounted && !_dragging) setState(() => _position = p);
    });
    _durSub = widget.durationStream.listen((d) {
      // Alguns MP3s legados emitem Duration.zero após abrir. Não pode
      // apagar duração do catálogo usada como fallback.
      if (mounted && d > Duration.zero) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = _duration.inMilliseconds;
    final value = _dragging
        ? _dragValue!
        : (totalMs > 0 ? _position.inMilliseconds / totalMs : 0.0);

    return Row(
      children: [
        Text(_fmt(_position), style: theme.textTheme.labelSmall),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: (v) {
                setState(() {
                  _dragging = true;
                  _dragValue = v;
                });
              },
              onChangeEnd: (v) {
                setState(() => _dragging = false);
                if (totalMs > 0) {
                  widget.onSeek(Duration(milliseconds: (v * totalMs).round()));
                }
              },
            ),
          ),
        ),
        Text(_fmt(_duration), style: theme.textTheme.labelSmall),
      ],
    );
  }
}
