// coverage:ignore-file
// UI de Timer/Countdown -- stopwatch + contagem regressiva
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/services/countdown_alert_service.dart';
import '../../core/services/dlna/stage_session.dart';
import '../../data/repositories/countdown_preset_repository.dart';
import '../../domain/entities/countdown_preset.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_cast_button.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/stage_customization_sheet.dart'
    show StageModule;
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_stop_video_button.dart';

class TimerPage extends StatefulWidget {
  final CountdownPresetRepository? presetRepository;
  final CountdownAlertService? alertService;

  const TimerPage({super.key, this.presetRepository, this.alertService});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final _stopwatch = Stopwatch();
  Duration _elapsed = Duration.zero;

  // ===== Cast do timer pro Palco (F3.3l) =====
  // Palco ligado = timer espelha na TV. Regressivo usa o renderer NATIVO
  // do receiver (conta sozinho, sem tick-a-tick); stopwatch manda o tempo
  // decorrido e a TV conta a partir dele (chrono).
  // F3.3 PERSONALIZAÇÃO: também projeta o texto do timer com as configs
  // do módulo (BG, cor, fonte, alinhamento, sombra, caixa) — além do
  // timer nativo. O receiver aplica os estilos no elemento timer.
  void _castCountdown() {
    final stage = StageSession.instance;
    if (!stage.isOn || !stage.isPalcoMode) return;
    if (!_countdownRunning) {
      stage.stopTimerStage();
      return;
    }
    // Timer nativo conta na TV; StageSession injeta settings do módulo.
    final label = 'timer.countdown'.tr();
    stage.startTimer(
      duration: _countdownRemaining.inSeconds,
      mode: 'countdown',
      label: label,
    );
  }

  void _castStopwatch() {
    final stage = StageSession.instance;
    if (!stage.isOn || !stage.isPalcoMode) return;
    if (!_stopwatch.isRunning) {
      stage.stopTimerStage();
      return;
    }
    // chrono: TV conta a partir do elapsed atual (renderer nativo).
    final label = 'timer.stopwatch'.tr();
    stage.startTimer(
      duration: _stopwatch.elapsed.inSeconds,
      mode: 'chrono',
      label: label,
    );
  }

  void _castStop() {
    StageSession.instance.stopTimerStage();
  }

  // Countdown
  int _countdownMinutes = 5;
  int _countdownSeconds = 0;
  Duration _countdownRemaining = Duration.zero;
  bool _countdownRunning = false;
  late final CountdownPresetRepository _presetRepository;
  late final CountdownAlertService _alertService;
  List<CountdownPreset> _presets = const [];

  @override
  void initState() {
    super.initState();
    _presetRepository = widget.presetRepository ?? CountdownPresetRepository();
    _alertService = widget.alertService ?? CountdownAlertService();
    _loadPresets();
    // F3.3l: palco ligado DEPOIS do start — re-espelha o timer corrente.
    StageSession.instance.addListener(_onStageChanged);
  }

  void _onStageChanged() {
    if (!mounted) return;
    if (_stopwatch.isRunning) {
      _castStopwatch();
    } else if (_countdownRunning) {
      _castCountdown();
    }
    setState(() {}); // badge aparece/some
  }

  Future<void> _loadPresets() async {
    final presets = await _presetRepository.load();
    if (mounted) setState(() => _presets = presets);
  }

  Future<void> _saveCurrentPreset() async {
    final duration = Duration(
      minutes: _countdownMinutes,
      seconds: _countdownSeconds,
    );
    if (duration == Duration.zero) return;
    final preset = CountdownPreset(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: _formatCountdown(duration),
      duration: duration,
    );
    final updated = [..._presets, preset];
    await _presetRepository.save(updated);
    if (mounted) setState(() => _presets = updated);
  }

  Future<void> _deletePreset(CountdownPreset preset) async {
    final updated = _presets.where((item) => item.id != preset.id).toList();
    await _presetRepository.save(updated);
    if (mounted) setState(() => _presets = updated);
  }

  void _applyPreset(CountdownPreset preset) {
    setState(() {
      _countdownMinutes = preset.duration.inMinutes;
      _countdownSeconds = preset.duration.inSeconds.remainder(60);
      _countdownRemaining = Duration.zero;
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatCountdown(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _toggleStopwatch() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _elapsed = _stopwatch.elapsed;
      } else {
        _stopwatch.start();
      }
    });
    if (_stopwatch.isRunning) {
      _tickStopwatch();
    }
    _castStopwatch(); // F3.3l
  }

  void _tickStopwatch() {
    if (!_stopwatch.isRunning) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_stopwatch.isRunning && mounted) {
        setState(() {});
        _tickStopwatch();
      }
    });
  }

  void _resetStopwatch() {
    setState(() {
      _stopwatch.reset();
      _elapsed = Duration.zero;
    });
    _castStop(); // F3.3l
  }

  void _startCountdown() {
    final total = Duration(
      minutes: _countdownMinutes,
      seconds: _countdownSeconds,
    );
    if (total == Duration.zero) return;
    setState(() {
      _countdownRemaining = total;
      _countdownRunning = true;
    });
    _tickCountdown();
    _castCountdown(); // F3.3l
  }

  void _tickCountdown() {
    if (!_countdownRunning || _countdownRemaining == Duration.zero) {
      if (_countdownRemaining == Duration.zero && _countdownRunning) {
        setState(() {
          _countdownRunning = false;
        });
      }
      return;
    }
    Future.delayed(const Duration(seconds: 1), () {
      if (_countdownRunning && mounted) {
        setState(() {
          _countdownRemaining =
              _countdownRemaining - const Duration(seconds: 1);
        });
        if (_countdownRemaining == Duration.zero) {
          _countdownRunning = false;
          unawaited(_alertService.notifyFinished());
        }
        _tickCountdown();
      }
    });
  }

  void _stopCountdown() {
    setState(() {
      _countdownRunning = false;
    });
    _castStop(); // F3.3l
  }

  void _resetCountdown() {
    setState(() {
      _countdownRunning = false;
      _countdownRemaining = Duration.zero;
    });
    _castStop(); // F3.3l
  }

  @override
  void dispose() {
    StageSession.instance.removeListener(_onStageChanged);
    _stopwatch.stop();
    _countdownRunning = false;
    _castStop(); // F3.3l: sair da tela tira o timer da TV
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casting = StageSession.instance.isOn; // F3.3l
    return Scaffold(
      appBar: AppBar(
        title: Text('timer.title'.tr()),
        actions: const [
          StageClearButton(),
          StageStopVideoButton(),
          StageCastButton(module: StageModule.timer),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // F3.3l: badge de espelhamento — timer vai pra TV com palco ligado.
            if (casting)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      TablerIcons.cast,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Espelhando no Palco',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            // --- Cronometro (Timer progressivo) ---
            _SectionCard(
              icon: TablerIcons.clock,
              title: 'timer.stopwatch'.tr(),
              child: Column(
                children: [
                  Text(
                    _formatDuration(
                      _stopwatch.isRunning ? _stopwatch.elapsed : _elapsed,
                    ),
                    key: const Key('stopwatch-display'),
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        key: const Key('stopwatch-toggle'),
                        onPressed: _toggleStopwatch,
                        icon: Icon(
                          _stopwatch.isRunning
                              ? TablerIcons.playerPauseFilled
                              : TablerIcons.playerPlayFilled,
                        ),
                        label: Text(
                          _stopwatch.isRunning
                              ? 'common.pause'.tr()
                              : 'common.start'.tr(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        key: const Key('stopwatch-reset'),
                        onPressed: _resetStopwatch,
                        icon: const Icon(TablerIcons.refresh),
                        label: Text('common.reset'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Countdown ---
            _SectionCard(
              icon: TablerIcons.hourglass,
              title: 'timer.countdown'.tr(),
              child: Column(
                children: [
                  Text(
                    _countdownRemaining > Duration.zero
                        ? _formatCountdown(_countdownRemaining)
                        : '--:--',
                    key: const Key('countdown-display'),
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color:
                          _countdownRemaining == Duration.zero &&
                              _countdownMinutes == 0 &&
                              _countdownSeconds == 0
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_countdownRunning) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _NumberStepper(
                          label: 'timer.minutes'.tr(),
                          value: _countdownMinutes,
                          onChanged: (v) =>
                              setState(() => _countdownMinutes = v),
                        ),
                        const SizedBox(width: 24),
                        _NumberStepper(
                          label: 'timer.seconds'.tr(),
                          value: _countdownSeconds,
                          max: 59,
                          onChanged: (v) =>
                              setState(() => _countdownSeconds = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          key: const Key('countdown-start'),
                          onPressed: _startCountdown,
                          icon: const Icon(TablerIcons.playerPlayFilled),
                          label: Text('common.start'.tr()),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          key: const Key('countdown-save-preset'),
                          onPressed:
                              _countdownMinutes == 0 && _countdownSeconds == 0
                              ? null
                              : _saveCurrentPreset,
                          icon: const Icon(TablerIcons.bookmark),
                          label: const Text('Salvar'),
                        ),
                      ],
                    ),
                    if (_presets.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Presets salvos',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _presets
                            .map(
                              (preset) => InputChip(
                                key: Key('countdown-preset-${preset.id}'),
                                label: Text(preset.label),
                                onPressed: () => _applyPreset(preset),
                                onDeleted: () => _deletePreset(preset),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          key: const Key('countdown-stop'),
                          onPressed: _stopCountdown,
                          icon: const Icon(TablerIcons.playerStopFilled),
                          label: Text('common.stop'.tr()),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          key: const Key('countdown-reset'),
                          onPressed: _resetCountdown,
                          icon: const Icon(TablerIcons.refresh),
                          label: Text('common.reset'.tr()),
                        ),
                      ],
                    ),
                  ],
                  if (_countdownRemaining == Duration.zero &&
                      !_countdownRunning &&
                      (_countdownMinutes > 0 || _countdownSeconds > 0))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'timer.finished'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ); // fecha Scaffold
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberStepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.max = 99,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'common.decrease'.tr(),
              icon: const Icon(TablerIcons.minus, size: 20),
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 48,
              child: Text(
                value.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'common.increase'.tr(),
              icon: const Icon(TablerIcons.plus, size: 20),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}
