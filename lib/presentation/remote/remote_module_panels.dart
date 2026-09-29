// coverage:ignore-file
// UI dos módulos v2 do controle remoto (bible/timer/countdown) — widget
// tree pura sobre RemoteSession.send, sem lógica testável isolada.
library;

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';

typedef RemoteSend =
    Future<void> Function(
      RemoteAction action, {
      int? numberMin,
      int? numberMax,
      String? namesText,
      int? index,
      int? volume,
      int? versionId,
      int? bookId,
      int? chapter,
      int? verse,
      int? durationMs,
      String? name,
      String? style,
      bool? showSeconds,
      bool? format24h,
      int? musicId,
      String? mode,
      String? query,
    });

RemoteSend _defaultSend =
    (
      action, {
      index,
      volume,
      versionId,
      bookId,
      chapter,
      verse,
      durationMs,
      name,
      style,
      showSeconds,
      format24h,
      musicId,
      mode,
      query,
      numberMin,
      numberMax,
      namesText,
    }) {
      return RemoteSession.instance.send(
        RemoteCommand(
          id: 'm${DateTime.now().microsecondsSinceEpoch}',
          action: action,
          numberMin: numberMin,
          numberMax: numberMax,
          namesText: namesText,
          index: index,
          volume: volume,
          versionId: versionId,
          bookId: bookId,
          chapter: chapter,
          verse: verse,
          durationMs: durationMs,
          name: name,
          style: style,
          showSeconds: showSeconds,
          format24h: format24h,
          musicId: musicId,
          mode: mode,
          query: query,
        ),
      );
    };

/// Painel Bíblia: seleção de versão, livro por NOME (dropdown), navegação
/// de capítulo/versículo por chevron — dados do catálogo do desktop.
class RemoteBiblePanel extends StatelessWidget {
  const RemoteBiblePanel({super.key, this.send, this.state});

  final RemoteSend? send;
  final RemotePlayerState? state;

  RemoteSend get _send => send ?? _defaultSend;

  void _open(RemoteBibleState bible, {int? bookId, int? chapter, int? verse}) {
    _send(
      RemoteAction.bibleOpen,
      versionId: bible.versionId ?? 1,
      bookId: bookId ?? bible.bookId ?? 1,
      chapter: chapter ?? bible.chapter ?? 1,
      verse: verse,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bible = state?.bibleModule;
    if (bible == null) {
      return Center(
        child: Text(
          'remote.bible.waiting'.tr(),
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    final books = bible.books;
    final versions = bible.versions;
    RemoteBibleBook? selectedBook;
    for (final b in books) {
      if (b.id == bible.bookId) {
        selectedBook = b;
        break;
      }
    }
    final chapter = bible.chapter ?? 1;
    final maxChapters = selectedBook?.chapters ?? 150;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      children: [
        if (versions.length > 1)
          DropdownButtonFormField<int>(
            key: const Key('remote-bible-version'),
            initialValue: bible.versionId,
            decoration: InputDecoration(
              labelText: 'remote.bible.version'.tr(),
              isDense: true,
            ),
            items: [
              for (final v in versions)
                DropdownMenuItem(value: v.id, child: Text(v.abbreviation)),
            ],
            onChanged: (id) {
              if (id != null) {
                _send(
                  RemoteAction.bibleOpen,
                  versionId: id,
                  bookId: bible.bookId ?? 1,
                  chapter: chapter,
                );
              }
            },
          ),
        if (versions.length > 1) const SizedBox(height: AppSpacing.s3),
        DropdownButtonFormField<int>(
          key: const Key('remote-bible-book-select'),
          initialValue: bible.bookId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'remote.bible.book'.tr(),
            isDense: true,
          ),
          items: [
            for (final b in books)
              DropdownMenuItem(
                value: b.id,
                child: Text(b.number > 0 ? '${b.number}. ${b.name}' : b.name),
              ),
          ],
          onChanged: (id) {
            if (id != null) _open(bible, bookId: id, chapter: 1, verse: 1);
          },
        ),
        const SizedBox(height: AppSpacing.s3),
        _ChevronField(
          label: 'remote.bible.chapter'.tr(),
          value: chapter,
          min: 1,
          max: maxChapters,
          keyPrefix: 'chapter',
          onChanged: (c) => _open(bible, chapter: c, verse: 1),
        ),
        const SizedBox(height: AppSpacing.s3),
        _ChevronField(
          label: 'remote.bible.verse'.tr(),
          value: (bible.selectedVerses.isNotEmpty
              ? bible.selectedVerses.last
              : 1),
          min: 1,
          max: 200,
          keyPrefix: 'verse',
          onChanged: (v) => _send(RemoteAction.bibleSelectVerse, verse: v),
        ),
        const SizedBox(height: AppSpacing.s4),
        FilledButton.icon(
          key: const Key('remote-bible-project'),
          // Sem seleção no estado: usa o primeiro livro do catálogo (não
          // desabilita — operador espera que "abrir" sempre abra algo).
          onPressed: () => _open(
            bible,
            bookId: bible.bookId ?? (books.isNotEmpty ? books.first.id : 1),
            chapter: bible.chapter ?? 1,
            verse: bible.selectedVerses.isNotEmpty
                ? bible.selectedVerses.last
                : 1,
          ),
          icon: const Icon(TablerIcons.book),
          label: Text('remote.bible.open'.tr()),
        ),
        const SizedBox(height: AppSpacing.s2),
        OutlinedButton.icon(
          onPressed: () => _send(RemoteAction.bibleClose),
          icon: const Icon(TablerIcons.squareX),
          label: Text('remote.bible.close'.tr()),
        ),
      ],
    );
  }
}

/// Campo numérico híbrido: dropdown (select) + navegação por chevron (±).
class _ChevronField extends StatelessWidget {
  const _ChevronField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.keyPrefix,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            key: Key('remote-bible-$keyPrefix-select'),
            initialValue: value.clamp(min, max),
            isExpanded: true,
            decoration: InputDecoration(labelText: label, isDense: true),
            items: [
              for (var n = min; n <= max; n++)
                DropdownMenuItem(value: n, child: Text('$n')),
            ],
            onChanged: (n) {
              if (n != null) onChanged(n);
            },
          ),
        ),
        IconButton(
          key: Key('remote-bible-$keyPrefix-minus'),
          icon: const Icon(TablerIcons.chevronLeft),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        IconButton(
          key: Key('remote-bible-$keyPrefix-plus'),
          icon: const Icon(TablerIcons.chevronRight),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

/// Painel Tempo: timer + countdown lado a lado, espelhando o estado v2.
class RemoteTimePanel extends StatelessWidget {
  const RemoteTimePanel({super.key, this.send, this.state});

  final RemoteSend? send;
  final RemotePlayerState? state;

  RemoteSend get _send => send ?? _defaultSend;

  @override
  Widget build(BuildContext context) {
    final timer = state?.timerModule;
    final countdown = state?.countdownModule;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      children: [
        _TimeCard(
          key: const Key('remote-timer-card'),
          title: 'remote.timer.title'.tr(),
          status: timer?.status,
          elapsedMs: timer?.accumulatedMs ?? 0,
          marks: timer?.savedTimesMs ?? const [],
          isProjecting: timer?.isProjecting ?? false,
          onStart: () => _send(RemoteAction.timerStart),
          onPause: () => _send(RemoteAction.timerPause),
          onReset: () => _send(RemoteAction.timerReset),
          onSaveMark: () => _send(RemoteAction.timerSaveMark),
          onToggleProjection: () => _send(RemoteAction.timerToggleProjection),
        ),
        const SizedBox(height: AppSpacing.s4),
        _CountdownCard(
          key: const Key('remote-countdown-card'),
          countdown: countdown,
          send: _send,
        ),
      ],
    );
  }
}

/// Card countdown com edição de duração (min:seg) e controle de projeção.
class _CountdownCard extends StatefulWidget {
  const _CountdownCard({super.key, required this.countdown, this.send});

  final RemoteCountdownState? countdown;
  final RemoteSend? send;

  @override
  State<_CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<_CountdownCard> {
  final _minCtrl = TextEditingController();
  final _secCtrl = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _minCtrl.dispose();
    _secCtrl.dispose();
    super.dispose();
  }

  void _applyDuration() {
    final min = int.tryParse(_minCtrl.text.trim()) ?? 0;
    final sec = int.tryParse(_secCtrl.text.trim()) ?? 0;
    final ms = (min * 60 + sec) * 1000;
    if (ms <= 0) return;
    (widget.send ?? _defaultSend)(
      RemoteAction.countdownSetDuration,
      durationMs: ms,
    );
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cd = widget.countdown;
    return _TimeCard(
      title: 'remote.countdown.title'.tr(),
      status: cd?.status,
      elapsedMs: cd?.accumulatedMs ?? 0,
      totalMs: cd?.durationMs,
      marks: cd?.savedTimesMs ?? const [],
      finished: cd?.finished ?? false,
      tag: 'countdown',
      isProjecting: cd?.isProjecting ?? false,
      onStart: () => (widget.send ?? _defaultSend)(RemoteAction.countdownStart),
      onPause: () => (widget.send ?? _defaultSend)(RemoteAction.countdownPause),
      onReset: () => (widget.send ?? _defaultSend)(RemoteAction.countdownReset),
      onSaveMark: () =>
          (widget.send ?? _defaultSend)(RemoteAction.countdownSaveMark),
      onToggleProjection: () =>
          (widget.send ?? _defaultSend)(RemoteAction.countdownToggleProjection),
      // edição de duração + botão projetar/parar
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_editing) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('remote-countdown-min'),
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'remote.countdown.minutes'.tr(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: TextField(
                    key: const Key('remote-countdown-sec'),
                    controller: _secCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'remote.countdown.seconds'.tr(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            FilledButton(
              key: const Key('remote-countdown-apply'),
              onPressed: _applyDuration,
              child: Text('remote.countdown.apply'.tr()),
            ),
          ] else
            TextButton.icon(
              key: const Key('remote-countdown-edit'),
              onPressed: () {
                final cur = (cd?.durationMs ?? 0) ~/ 1000;
                _minCtrl.text = '${cur ~/ 60}';
                _secCtrl.text = '${cur % 60}';
                setState(() => _editing = true);
              },
              icon: const Icon(TablerIcons.pencil, size: 18),
              label: Text('remote.countdown.edit'.tr()),
            ),
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    super.key,
    required this.title,
    required this.status,
    required this.elapsedMs,
    required this.marks,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onSaveMark,
    this.totalMs,
    this.finished = false,
    this.tag = 'timer',
    this.isProjecting = false,
    this.onToggleProjection,
    this.extra,
  });

  final String title;
  final String? status;

  final int elapsedMs;
  final int? totalMs;
  final List<int> marks;
  final bool finished;
  final String tag; // sufixo de key (timer/countdown)
  final bool isProjecting;
  final VoidCallback? onToggleProjection;
  final Widget? extra;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onSaveMark;

  String _fmt(int ms) {
    final total = ms ~/ 1000;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = status == 'running';
    final remaining = totalMs != null
        ? (totalMs! - elapsedMs).clamp(0, totalMs!)
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                if (finished)
                  Icon(TablerIcons.alertCircle, color: theme.colorScheme.error),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              remaining != null ? _fmt(remaining) : _fmt(elapsedMs),
              style: theme.textTheme.displaySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (marks.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                '${'remote.marks'.tr()}: ${marks.map(_fmt).join(' · ')}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (onToggleProjection != null) ...[
              const SizedBox(height: AppSpacing.s2),
              OutlinedButton.icon(
                key: Key('remote-$tag-projection'),
                onPressed: onToggleProjection,
                icon: Icon(
                  isProjecting ? TablerIcons.square : TablerIcons.deviceTv,
                  size: 18,
                ),
                label: Text(
                  isProjecting
                      ? 'remote.stopProjection'.tr()
                      : 'remote.project'.tr(),
                ),
              ),
            ],
            if (extra != null) ...[
              const SizedBox(height: AppSpacing.s2),
              extra!,
            ],
            const SizedBox(height: AppSpacing.s3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filled(
                  key: Key('remote-$tag-toggle'),
                  tooltip: running ? 'remote.pause'.tr() : 'remote.play'.tr(),
                  onPressed: running ? onPause : onStart,
                  icon: Icon(
                    running ? TablerIcons.playerPause : TablerIcons.playerPlay,
                  ),
                ),
                IconButton(
                  tooltip: 'remote.mark'.tr(),
                  onPressed: onSaveMark,
                  icon: const Icon(TablerIcons.flag),
                ),
                IconButton(
                  tooltip: 'remote.reset'.tr(),
                  onPressed: onReset,
                  icon: const Icon(TablerIcons.rotate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RemoteClockRandomPanel extends StatelessWidget {
  const RemoteClockRandomPanel({super.key, this.clock, this.random});

  final RemoteClockState? clock;
  final RemoteRandomState? random;

  RemoteSend get _send => _defaultSend;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      children: [
        _ClockCard(clock: clock, send: _send),
        const SizedBox(height: AppSpacing.s4),
        _RandomCard(random: random, send: _send),
      ],
    );
  }
}

class _ClockCard extends StatelessWidget {
  const _ClockCard({required this.clock, required this.send});

  final RemoteClockState? clock;
  final RemoteSend send;

  @override
  Widget build(BuildContext context) {
    final c = clock;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(TablerIcons.clock),
                const SizedBox(width: AppSpacing.s2),
                Expanded(child: Text('remote.clock.title'.tr())),
                Text(c == null ? '—' : (c.format24h ? '24h' : '12h')),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            OutlinedButton.icon(
              key: const Key('remote-clock-projection'),
              onPressed: () => send(RemoteAction.clockToggleProjection),
              icon: Icon(
                c?.isProjecting == true
                    ? TablerIcons.square
                    : TablerIcons.deviceTv,
              ),
              label: Text(
                c?.isProjecting == true
                    ? 'remote.stopProjection'.tr()
                    : 'remote.project'.tr(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sorteio completo: modos (números/nomes), intervalo, importar nomes,
/// sortear, sorteados com devolver — espelho do app desktop.
class _RandomCard extends StatefulWidget {
  const _RandomCard({required this.random, required this.send});

  final RemoteRandomState? random;
  final RemoteSend send;

  @override
  State<_RandomCard> createState() => _RandomCardState();
}

class _RandomCardState extends State<_RandomCard> {
  final _namesCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void dispose() {
    _namesCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.random;
    final mode = r?.mode ?? 'numbers';
    final isNames = mode == 'names';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(TablerIcons.dice),
                const SizedBox(width: AppSpacing.s2),
                Expanded(child: Text('remote.random.title'.tr())),
                Text('${r?.drawnCount ?? 0} / ${r?.availableCount ?? 0}'),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            SegmentedButton<String>(
              key: const Key('remote-random-mode'),
              segments: [
                ButtonSegment(
                  value: 'numbers',
                  label: Text('remote.random.numbers'.tr()),
                  icon: const Icon(TablerIcons.numbers),
                ),
                ButtonSegment(
                  value: 'names',
                  label: Text('remote.random.names'.tr()),
                  icon: const Icon(TablerIcons.users),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (sel) =>
                  widget.send(RemoteAction.randomSetMode, mode: sel.first),
            ),
            const SizedBox(height: AppSpacing.s3),
            if (!isNames) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('remote-random-min'),
                      controller: _minCtrl..text = '${r?.numberMin ?? 1}',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'remote.random.min'.tr(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: TextField(
                      key: const Key('remote-random-max'),
                      controller: _maxCtrl..text = '${r?.numberMax ?? 100}',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'remote.random.max'.tr(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              OutlinedButton.icon(
                key: const Key('remote-random-apply-range'),
                onPressed: () {
                  final min = int.tryParse(_minCtrl.text) ?? 1;
                  final max = int.tryParse(_maxCtrl.text) ?? 100;
                  widget.send(
                    RemoteAction.randomSetNumberRange,
                    numberMin: min,
                    numberMax: max,
                  );
                },
                icon: const Icon(TablerIcons.check),
                label: Text('remote.random.applyRange'.tr()),
              ),
            ],
            if (isNames) ...[
              TextField(
                key: const Key('remote-random-names'),
                controller: _namesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'remote.random.namesHint'.tr(),
                  hintText: 'Maria\nJoão\nAna',
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              OutlinedButton.icon(
                key: const Key('remote-random-import'),
                onPressed: () {
                  final text = _namesCtrl.text.trim();
                  if (text.isEmpty) return;
                  widget.send(RemoteAction.randomImportNames, namesText: text);
                  _namesCtrl.clear();
                },
                icon: const Icon(TablerIcons.userPlus),
                label: Text('remote.random.importNames'.tr()),
              ),
            ],
            const SizedBox(height: AppSpacing.s3),
            if ((r?.currentDisplay ?? '').isNotEmpty)
              Text(
                r!.currentDisplay!,
                key: const Key('remote-random-display'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            const SizedBox(height: AppSpacing.s2),
            FilledButton.icon(
              key: const Key('remote-random-draw'),
              onPressed: r?.isDrawing == true
                  ? null
                  : () => widget.send(RemoteAction.randomStartDraw),
              icon: const Icon(TablerIcons.dice),
              label: Text(
                r?.isDrawing == true
                    ? 'remote.random.drawing'.tr()
                    : 'remote.draw'.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('remote-random-projection'),
                    onPressed: () =>
                        widget.send(RemoteAction.randomToggleProjection),
                    icon: Icon(
                      r?.isProjecting == true
                          ? TablerIcons.square
                          : TablerIcons.deviceTv,
                    ),
                    label: Text(
                      r?.isProjecting == true
                          ? 'remote.stopProjection'.tr()
                          : 'remote.project'.tr(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('remote-random-stop'),
                    onPressed: () => widget.send(RemoteAction.randomCancelDraw),
                    icon: const Icon(TablerIcons.playerStop),
                    label: Text('remote.stop'.tr()),
                  ),
                ),
              ],
            ),
            if ((r?.drawn ?? const []).isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s3),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'remote.random.drawnList'.tr(),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              for (var i = 0; i < r!.drawn.length; i++)
                ListTile(
                  dense: true,
                  key: Key('remote-random-drawn-$i'),
                  title: Text(r.drawn[i]),
                  trailing: IconButton(
                    key: Key('remote-random-undraw-$i'),
                    icon: const Icon(TablerIcons.arrowBackUp),
                    tooltip: 'remote.random.returnName'.tr(),
                    onPressed: () =>
                        widget.send(RemoteAction.randomRemoveDrawn, index: i),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Painel Hinos: busca REMOTA no catálogo do alvo (ids corretos do
/// desktop — a API pública tem ids distintos e media.open falhava com
/// trackMissing). O resultado escolhido vira media.open {musicId, mode}.
class RemoteHymnsPanel extends StatefulWidget {
  const RemoteHymnsPanel({super.key, this.send, this.state});

  final RemoteSend? send;
  final RemotePlayerState? state;

  @override
  State<RemoteHymnsPanel> createState() => _RemoteHymnsPanelState();
}

class _RemoteHymnsPanelState extends State<RemoteHymnsPanel> {
  final _queryCtrl = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  String _mode = 'audio';

  static const _modes = [
    ('audio', 'Cantado'),
    ('instrumental', 'Playback'),
    ('no_audio', 'Só slides'),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  String _lastQuery = '';

  void _onQuery(String q) {
    _debounce?.cancel();
    final query = q.trim();
    if (query.isEmpty) {
      setState(() => _searching = false);
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query == _lastQuery) return; // já buscou esse termo
      _lastQuery = query;
      (widget.send ?? _defaultSend)(RemoteAction.mediaSearch, query: query);
      // Resultados chegam no próximo state (media.searchResults).
      if (mounted) setState(() => _searching = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = widget.state?.mediaModule;
    var hits = media?.searchResults ?? const [];
    // Casa a lista com a query que a gerou: se o usuário já digitou mais,
    // resultados de query antiga não são exibidos (evita lista "congelada").
    if (media?.query != null &&
        _queryCtrl.text.trim() != media!.query &&
        media.query!.isNotEmpty) {
      hits = const [];
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: TextField(
            key: const Key('remote-hymns-query'),
            controller: _queryCtrl,
            autofocus: false,
            onChanged: _onQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(TablerIcons.search),
              labelText: 'remote.hymns.search'.tr(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Wrap(
            spacing: AppSpacing.s2,
            children: [
              for (final (m, label) in _modes)
                ChoiceChip(
                  key: Key('remote-hymns-mode-$m'),
                  label: Text(label),
                  selected: _mode == m,
                  onSelected: (_) => setState(() => _mode = m),
                ),
            ],
          ),
        ),
        if (_searching) const LinearProgressIndicator(),
        Expanded(
          child: hits.isEmpty
              ? Center(
                  child: Text(
                    'remote.hymns.empty'.tr(),
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : ListView.builder(
                  itemCount: hits.length,
                  itemBuilder: (_, i) {
                    final h = hits[i];
                    return ListTile(
                      key: Key('remote-hymns-result-$i'),
                      dense: true,
                      title: Text(
                        h.track != null ? '${h.track} — ${h.name}' : h.name,
                      ),
                      onTap: () => (widget.send ?? _defaultSend)(
                        RemoteAction.mediaOpen,
                        musicId: h.musicId,
                        mode: _mode,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
