// coverage:ignore-file
// UI de Timer/Countdown -- stopwatch + contagem regressiva
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/countdown_alert_service.dart';
import '../../core/services/dlna/stage_session.dart';
import '../../data/repositories/countdown_preset_repository.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_cast_button.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/stage_customization_sheet.dart'
    show StageModule;
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_stop_video_button.dart';

class TimerPage extends StatefulWidget {
  final CountdownPresetRepository? presetRepository;
  final CountdownAlertService? alertService;
  final VoidCallback? onBack;

  const TimerPage({
    super.key,
    this.presetRepository,
    this.alertService,
    this.onBack,
  });

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
  // Projetar: cada bloco tem seu botão; só um vai pra TV por vez.
  bool _projectStopwatch = false;
  bool _projectCountdown = false;

  /// Contagem na TV: rodando = renderer nativo do receiver; parada =
  /// mostra o valor fixo.
  void _castCountdown() {
    final stage = StageSession.instance;
    if (!stage.isOn || !_projectCountdown) return;
    if (_countdownRunning && stage.isPalcoMode) {
      stage.startTimer(
        duration: _countdownRemaining.inSeconds,
        mode: 'countdown',
        label: 'timer.countdown'.tr(),
      );
      return;
    }
    stage.stopTimerStage();
    unawaited(stage.project(title: _countdownText(), module: 'timer'));
  }

  /// Cronômetro na TV: rodando = chrono a partir do decorrido; parado =
  /// mostra o tempo fixo.
  void _castStopwatch() {
    final stage = StageSession.instance;
    if (!stage.isOn || !_projectStopwatch) return;
    if (_stopwatch.isRunning && stage.isPalcoMode) {
      stage.startTimer(
        duration: _stopwatch.elapsed.inSeconds,
        mode: 'chrono',
        label: 'timer.stopwatch'.tr(),
      );
      return;
    }
    stage.stopTimerStage();
    unawaited(
      stage.project(
        title: _formatDuration(
          _stopwatch.isRunning ? _stopwatch.elapsed : _elapsed,
          millis: false,
        ),
        module: 'timer',
      ),
    );
  }

  Future<void> _stopProjection() async {
    final stage = StageSession.instance;
    stage.stopTimerStage();
    await stage.clearContent();
  }

  Future<void> _toggleProjectStopwatch() async {
    if (_projectStopwatch) {
      setState(() => _projectStopwatch = false);
      await _stopProjection();
      return;
    }
    setState(() {
      _projectStopwatch = true;
      _projectCountdown = false;
    });
    _castStopwatch();
  }

  Future<void> _toggleProjectCountdown() async {
    if (_projectCountdown) {
      setState(() => _projectCountdown = false);
      await _stopProjection();
      return;
    }
    setState(() {
      _projectCountdown = true;
      _projectStopwatch = false;
    });
    _castCountdown();
  }

  String _countdownText() => _formatCountdown(
    _countdownRemaining > Duration.zero
        ? _countdownRemaining
        : Duration(minutes: _countdownMinutes, seconds: _countdownSeconds),
  );

  // Tempos salvos do cronômetro (paridade desktop: "Tempos Salvos").
  static const _savedTimesKey = 'timer_saved_times_ms';
  List<int> _savedTimesMs = const [];

  static const _countdownSavedKey = 'timer_countdown_saved_ms';
  List<int> _countdownSavedMs = const [];

  Future<void> _loadSavedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    List<int> read(String key) => [
      for (final e in prefs.getStringList(key) ?? const <String>[])
        if (int.tryParse(e) != null) int.parse(e),
    ];
    if (mounted) {
      setState(() {
        _savedTimesMs = read(_savedTimesKey);
        _countdownSavedMs = read(_countdownSavedKey);
      });
    }
  }

  Future<void> _persistSavedTimes(String key, List<int> next) async {
    setState(() {
      if (key == _savedTimesKey) {
        _savedTimesMs = next;
      } else {
        _countdownSavedMs = next;
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, [for (final e in next) '$e']);
  }

  void _saveStopwatchTime() {
    final elapsed = _stopwatch.isRunning ? _stopwatch.elapsed : _elapsed;
    if (elapsed == Duration.zero) return;
    unawaited(
      _persistSavedTimes(_savedTimesKey, [
        ..._savedTimesMs,
        elapsed.inMilliseconds,
      ]),
    );
  }

  /// Salvar da contagem = mesmo do cronômetro: guarda o tempo do momento
  /// (restante se iniciada; senão o tempo escolhido).
  void _saveCountdownTime() {
    final current = _countdownRemaining > Duration.zero
        ? _countdownRemaining
        : Duration(minutes: _countdownMinutes, seconds: _countdownSeconds);
    if (current == Duration.zero) return;
    unawaited(
      _persistSavedTimes(_countdownSavedKey, [
        ..._countdownSavedMs,
        current.inMilliseconds,
      ]),
    );
  }

  // Countdown
  int _countdownMinutes = 5;
  int _countdownSeconds = 0;
  Duration _countdownRemaining = Duration.zero;
  bool _countdownRunning = false;
  late final CountdownAlertService _alertService;

  @override
  void initState() {
    super.initState();
    _alertService = widget.alertService ?? CountdownAlertService();
    _loadSavedTimes();
    // F3.3l: palco ligado DEPOIS do start — re-espelha o timer corrente.
    StageSession.instance.addListener(_onStageChanged);
  }

  void _onStageChanged() {
    if (!mounted) return;
    if (!StageSession.instance.isOn) {
      _projectStopwatch = false;
      _projectCountdown = false;
    }
    if (_stopwatch.isRunning) {
      _castStopwatch();
    } else if (_countdownRunning) {
      _castCountdown();
    }
    setState(() {}); // badge aparece/some
  }


  String _formatDuration(Duration d, {bool millis = true}) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final base =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return millis ? '$base.${_ms(d)}' : base;
  }

  String _formatCountdown(Duration d, {bool millis = false}) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final base =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return millis ? '$base.${_ms(d)}' : base;
  }

  /// Centésimos (2 dígitos): 41.343 s → "34".
  static String _ms(Duration d) =>
      (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');

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
    Future.delayed(const Duration(milliseconds: 31), () {
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
    _castStopwatch();
  }

  // Contagem por prazo absoluto (Date.now), não por decremento: os
  // milissegundos ficam certos e não atrasa com a tela ocupada.
  Timer? _countdownTimer;
  DateTime? _countdownDeadline;

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
    _countdownDeadline = DateTime.now().add(total);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(milliseconds: 31),
      (_) => _tickCountdown(),
    );
    _castCountdown(); // F3.3l
  }

  void _tickCountdown() {
    final deadline = _countdownDeadline;
    if (!mounted || !_countdownRunning || deadline == null) {
      _countdownTimer?.cancel();
      return;
    }
    final left = deadline.difference(DateTime.now());
    if (left <= Duration.zero) {
      _countdownTimer?.cancel();
      setState(() {
        _countdownRemaining = Duration.zero;
        _countdownRunning = false;
      });
      unawaited(_alertService.notifyFinished());
      return;
    }
    setState(() => _countdownRemaining = left);
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdownRunning = false;
    });
    _castCountdown();
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdownRunning = false;
      _countdownRemaining = Duration.zero;
    });
    _castCountdown();
  }

  @override
  void dispose() {
    StageSession.instance.removeListener(_onStageChanged);
    _stopwatch.stop();
    _countdownRunning = false;
    _countdownTimer?.cancel();
    // Sair da tela tira o timer da TV.
    if (_projectStopwatch || _projectCountdown) {
      unawaited(_stopProjection());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casting = StageSession.instance.isOn; // F3.3l
    return Scaffold(
      appBar: AppBar(
        title: Text('timer.title'.tr()),
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(TablerIcons.arrowLeft),
                onPressed: widget.onBack,
              ),
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
              summary: Text(
                _formatDuration(
                  _stopwatch.isRunning ? _stopwatch.elapsed : _elapsed,
                ),
                key: const Key('stopwatch-display'),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    runSpacing: 8,
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
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        key: const Key('stopwatch-save'),
                        onPressed: _saveStopwatchTime,
                        icon: const Icon(TablerIcons.bookmark),
                        label: Text('timer.save'.tr()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ProjectButton(
                    key: const Key('stopwatch-project'),
                    projecting: _projectStopwatch,
                    onPressed: StageSession.instance.isOn
                        ? _toggleProjectStopwatch
                        : null,
                  ),
                  _SavedTimesList(
                    keyPrefix: 'stopwatch-saved',
                    items: _savedTimesMs,
                    format: (ms) => _formatDuration(Duration(milliseconds: ms)),
                    onChanged: (next) =>
                        _persistSavedTimes(_savedTimesKey, next),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Countdown ---
            _SectionCard(
              icon: TablerIcons.hourglass,
              title: 'timer.countdown'.tr(),
              summary: Text(
                _countdownRemaining > Duration.zero
                    ? _formatCountdown(_countdownRemaining, millis: true)
                    : _formatCountdown(
                        Duration(
                          minutes: _countdownMinutes,
                          seconds: _countdownSeconds,
                        ),
                        millis: true,
                      ),
                key: const Key('countdown-display'),
                style: theme.textTheme.displaySmall?.copyWith(
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
              child: Column(
                children: [
                  if (!_countdownRunning) ...[
                    Wrap(
                      alignment: WrapAlignment.center,
                      runSpacing: 8,
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
                    Wrap(
                      alignment: WrapAlignment.center,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const Key('countdown-start'),
                          onPressed: _startCountdown,
                          icon: const Icon(TablerIcons.playerPlayFilled),
                          label: Text('common.start'.tr()),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          key: const Key('countdown-save'),
                          onPressed:
                              _countdownMinutes == 0 && _countdownSeconds == 0
                              ? null
                              : _saveCountdownTime,
                          icon: const Icon(TablerIcons.bookmark),
                          label: Text('timer.save'.tr()),
                        ),
                      ],
                    ),
                  ] else ...[
                    Wrap(
                      alignment: WrapAlignment.center,
                      runSpacing: 8,
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
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          key: const Key('countdown-save-running'),
                          onPressed: _saveCountdownTime,
                          icon: const Icon(TablerIcons.bookmark),
                          label: Text('timer.save'.tr()),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  _ProjectButton(
                    key: const Key('countdown-project'),
                    projecting: _projectCountdown,
                    onPressed: StageSession.instance.isOn
                        ? _toggleProjectCountdown
                        : null,
                  ),
                  _SavedTimesList(
                    keyPrefix: 'countdown-saved',
                    items: _countdownSavedMs,
                    format: (ms) => _formatCountdown(
                      Duration(milliseconds: ms),
                      millis: true,
                    ),
                    onChanged: (next) =>
                        _persistSavedTimes(_countdownSavedKey, next),
                  ),
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
            const SizedBox(height: 16),
            const _LocalClockCard(),
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
  final Widget summary;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    required this.summary,
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
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: summary,
        ),
        children: [SizedBox(width: double.infinity, child: child)],
      ),
    );
  }
}

/// Relógio local continua atualizando mesmo com os controles recolhidos.
class _LocalClockCard extends StatefulWidget {
  const _LocalClockCard();
  @override
  State<_LocalClockCard> createState() => _LocalClockCardState();
}

class _LocalClockCardState extends State<_LocalClockCard> {
  Timer? _ticker;
  bool _format24h = true;
  bool _showSeconds = true;
  bool _projecting = false;

  String get _time {
    final now = DateTime.now();
    final hour = _format24h
        ? now.hour
        : (now.hour % 12 == 0 ? 12 : now.hour % 12);
    final parts = [hour, now.minute, if (_showSeconds) now.second];
    return '${parts.map((part) => part.toString().padLeft(2, '0')).join(':')}${_format24h ? '' : (now.hour < 12 ? ' AM' : ' PM')}';
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_projecting && StageSession.instance.isOn) {
        unawaited(StageSession.instance.project(title: _time, module: 'timer'));
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_projecting) StageSession.instance.clearContent();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SectionCard(
    icon: TablerIcons.clock,
    title: 'timer.clock'.tr(),
    summary: Text(
      _time,
      key: const Key('clock-display'),
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
    child: Column(
      children: [
        SwitchListTile(
          key: const Key('clock-format'),
          title: Text('timer.format24h'.tr()),
          value: _format24h,
          onChanged: (value) => setState(() => _format24h = value),
        ),
        SwitchListTile(
          title: Text('timer.showSeconds'.tr()),
          value: _showSeconds,
          onChanged: (value) => setState(() => _showSeconds = value),
        ),
        OutlinedButton.icon(
          onPressed: StageSession.instance.isOn
              ? () async {
                  if (_projecting) {
                    await StageSession.instance.clearContent();
                    if (mounted) setState(() => _projecting = false);
                  } else {
                    final ok = await StageSession.instance.project(
                      title: _time,
                      module: 'timer',
                    );
                    if (mounted) setState(() => _projecting = ok);
                  }
                }
              : null,
          icon: Icon(_projecting ? TablerIcons.square : TablerIcons.deviceTv),
          label: Text(
            (_projecting ? 'remote.stopProjection' : 'remote.project').tr(),
          ),
        ),
      ],
    ),
  );
}

/// Lista "Tempos salvos" (paridade desktop): nº, tempo, remover e limpar.
class _SavedTimesList extends StatelessWidget {
  final String keyPrefix;
  final List<int> items;
  final String Function(int ms) format;
  final ValueChanged<List<int>> onChanged;

  const _SavedTimesList({
    required this.keyPrefix,
    required this.items,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'timer.savedTimes'.tr(),
                style: theme.textTheme.labelLarge,
              ),
            ),
            TextButton(
              key: Key('$keyPrefix-clear'),
              onPressed: () => onChanged(const []),
              child: Text('timer.clearAll'.tr()),
            ),
          ],
        ),
        for (var i = 0; i < items.length; i++)
          ListTile(
            key: Key('$keyPrefix-$i'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text('${i + 1}.', style: theme.textTheme.labelLarge),
            title: Text(
              format(items[i]),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(TablerIcons.x, size: 18),
              onPressed: () => onChanged([
                for (var j = 0; j < items.length; j++)
                  if (j != i) items[j],
              ]),
            ),
          ),
      ],
    );
  }
}

/// Projetar/Parar projeção (desabilitado com o palco desligado).
class _ProjectButton extends StatelessWidget {
  final bool projecting;
  final VoidCallback? onPressed;

  const _ProjectButton({
    super.key,
    required this.projecting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(projecting ? TablerIcons.square : TablerIcons.deviceTv),
      label: Text(
        (projecting ? 'remote.stopProjection' : 'remote.project').tr(),
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
