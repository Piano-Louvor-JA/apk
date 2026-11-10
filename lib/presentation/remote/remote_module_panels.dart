// UI dos módulos v2 do controle remoto (bible/timer/countdown) —
// widget tree pura sobre RemoteSend injetável (testado em remote_module_panels_test).
library;

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/global_search_service.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_player_presence.dart';
import 'widgets/remote_bible_preview.dart';
import 'remote_announcements_panel.dart';
import 'remote_sabbath_panel.dart';

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

  void _open(RemoteBibleState bible, {int? bookId, int? chapter, int? verse, bool project = false}) {
    _send(
      project ? RemoteAction.bibleOpen : RemoteAction.bibleSelect,
      versionId: bible.versionId ?? 1,
      bookId: bookId ?? bible.bookId ?? 1,
      chapter: chapter ?? bible.chapter ?? 1,
      verse: verse,
    );
  }

  String _bookLabel(RemoteBibleBook book) =>
      book.number > 0 ? '${book.number}. ${book.name}' : book.name;

  Future<int?> _chooseBook(BuildContext context, RemoteBibleState bible) =>
      _showBiblePicker(
        context,
        title: 'remote.bible.book'.tr(),
        keyPrefix: 'book',
        entries: [for (final book in bible.books) (id: book.id, label: _bookLabel(book))],
        selectedId: bible.bookId,
      );

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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (versions.isNotEmpty)
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  key: const Key('remote-bible-version'),
                  isExpanded: true,
                  initialValue: bible.versionId,
                  decoration: InputDecoration(
                    labelText: 'remote.bible.version'.tr(),
                    isDense: true,
                  ),
                  items: [
                    for (final v in versions)
                      DropdownMenuItem(
                        value: v.id,
                        child: Text(v.abbreviation),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) {
                      _send(
                        RemoteAction.bibleSelect,
                        versionId: id,
                        bookId: bible.bookId ?? 1,
                        chapter: chapter,
                      );
                    }
                  },
                ),
              ),
            if (versions.isNotEmpty) const SizedBox(width: AppSpacing.s3),
            Expanded(
              flex: 3,
              child: InkWell(
                key: const Key('remote-bible-book-select'),
                onTap: () async {
                  final id = await _chooseBook(context, bible);
                  if (id != null) _open(bible, bookId: id, chapter: 1, verse: 1);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'remote.bible.book'.tr(),
                    isDense: true,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(
                        selectedBook == null ? '' : _bookLabel(selectedBook),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                      const Icon(TablerIcons.chevronDown, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: _ChevronField(
                label: 'remote.bible.chapter'.tr(),
                value: chapter,
                min: 1,
                max: maxChapters,
                keyPrefix: 'chapter',
                onChanged: (c) => _open(bible, chapter: c, verse: 1),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              flex: 1,
              child: _ChevronField(
                label: 'remote.bible.verse'.tr(),
                value: (bible.selectedVerses.isNotEmpty
                    ? bible.selectedVerses.last
                    : 1),
                min: 1,
                max: 200,
                keyPrefix: 'verse',
                onChanged: (v) =>
                    _send(RemoteAction.bibleSelectVerse, verse: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        FilledButton.icon(
          key: const Key('remote-bible-project'),
          // Sem seleção no estado: usa o primeiro livro do catálogo (não
          // desabilita — operador espera que "abrir" sempre abra algo).
          onPressed: bible.isProjecting
              ? () => _send(RemoteAction.bibleClose)
              : () => _open(
                  bible,
                  project: true,
                  bookId: bible.bookId ?? (books.isNotEmpty ? books.first.id : 1),
                  chapter: bible.chapter ?? 1,
                  verse: bible.selectedVerses.isNotEmpty
                      ? bible.selectedVerses.last
                      : 1,
                ),
          icon: Icon(bible.isProjecting ? TablerIcons.squareX : TablerIcons.book),
          label: Text(
            (bible.isProjecting ? 'remote.bible.close' : 'remote.bible.open').tr(),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        ValueListenableBuilder<bool>(
          valueListenable: remoteBibleMinimized,
          builder: (_, minimized, _) => minimized ? const SizedBox.shrink() : RemoteBiblePreview(
            bible: bible,
            bookName: selectedBook?.name ?? '',
            onMinimize: () => remoteBibleMinimized.value = true,
            onChanged: (verse) => _send(RemoteAction.bibleSelectVerse, verse: verse),
          ),
        ),
      ],
    );
  }
}

Future<int?> _showBiblePicker(
  BuildContext context, {
  required String title,
  required String keyPrefix,
  required List<({int id, String label})> entries,
  required int? selectedId,
}) {
    var query = '';
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final matches = entries.where((entry) =>
            GlobalSearchService.normalize(entry.label).contains(query),
          ).toList();
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.sizeOf(context).height * 0.4,
              child: Column(
                children: [
                  TextField(
                    key: Key('remote-bible-$keyPrefix-search'),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'common.search'.tr(),
                      prefixIcon: const Icon(TablerIcons.search),
                    ),
                    onChanged: (value) => update(() {
                      query = GlobalSearchService.normalize(value);
                    }),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Expanded(
                    child: matches.isEmpty
                        ? Center(child: Text('common.empty'.tr()))
                        : ListView.builder(
                            itemCount: matches.length,
                            itemBuilder: (context, index) {
                              final entry = matches[index];
                              return ListTile(
                                key: Key('remote-bible-$keyPrefix-${entry.id}'),
                                title: Text(entry.label),
                                selected: entry.id == selectedId,
                                onTap: () => Navigator.pop(dialogContext, entry.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('common.cancel'.tr()),
            )],
          );
        },
      ),
    );
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
          child: InkWell(
            key: Key('remote-bible-$keyPrefix-select'),
            onTap: () async {
              final selected = await _showBiblePicker(
                context,
                title: label,
                keyPrefix: keyPrefix,
                entries: [for (var n = min; n <= max; n++) (id: n, label: '$n')],
                selectedId: value.clamp(min, max),
              );
              if (selected != null) onChanged(selected);
            },
            child: InputDecorator(
              decoration: InputDecoration(labelText: label, isDense: true),
              child: Row(
                children: [
                  Expanded(child: Text('${value.clamp(min, max)}')),
                  const Icon(TablerIcons.chevronDown, size: 18),
                ],
              ),
            ),
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
  const RemoteTimePanel({super.key, this.send, this.state, this.embedded = false});

  final bool embedded;

  final RemoteSend? send;
  final RemotePlayerState? state;

  RemoteSend get _send => send ?? _defaultSend;

  @override
  Widget build(BuildContext context) {
    final timer = state?.timerModule;
    final countdown = state?.countdownModule;
    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
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
        const SizedBox(height: AppSpacing.s4),
        _ClockCard(clock: state?.clockModule, send: _send),
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
      child: ExpansionTile(
        key: Key('remote-$tag-expand'),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.all(AppSpacing.s4),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          remaining != null ? _fmt(remaining) : _fmt(elapsedMs),
          style: theme.textTheme.displaySmall?.copyWith(
            color: finished ? theme.colorScheme.error : null,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        children: [
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
    );
  }
}

/// Recursos complementares do controle remoto, agrupados por finalidade.
class RemoteMorePanel extends StatefulWidget {
  const RemoteMorePanel({super.key, this.state, this.send});
  final RemotePlayerState? state;
  final RemoteSend? send;

  @override
  State<RemoteMorePanel> createState() => _RemoteMorePanelState();
}

enum _MoreFeature { time, random, announcements, sabbath }

class _RemoteMorePanelState extends State<RemoteMorePanel> {
  _MoreFeature? _feature;

  @override
  Widget build(BuildContext context) {
    final feature = _feature;
    if (feature != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            IconButton(
              key: const Key('remote-more-back'),
              tooltip: 'remote.tabMore'.tr(),
              icon: const Icon(TablerIcons.arrowLeft),
              onPressed: () => setState(() => _feature = null),
            ),
            Expanded(child: Text(
              (switch (feature) { _MoreFeature.time => 'remote.tabTime', _MoreFeature.random => 'remote.random.title', _MoreFeature.announcements => 'remote.tabAnnouncements', _MoreFeature.sabbath => 'remote.sabbath.title' }).tr(),
              style: Theme.of(context).textTheme.titleMedium,
            )),
          ]),
          Expanded(child: switch (feature) {
            _MoreFeature.time => RemoteTimePanel(state: widget.state, send: widget.send),
            _MoreFeature.random => RemoteClockRandomPanel(random: widget.state?.randomModule, send: widget.send),
            _MoreFeature.announcements => RemoteAnnouncementsPanel(state: widget.state?.announcementsModule),
            _MoreFeature.sabbath => RemoteSabbathPanel(state: widget.state?.sabbathModule),
          }),
        ],
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(AppSpacing.s4),
      mainAxisSpacing: AppSpacing.s4,
      crossAxisSpacing: AppSpacing.s4,
      children: [
        _featureCard(context, _MoreFeature.time, TablerIcons.clock, 'remote.tabTime'),
        _featureCard(context, _MoreFeature.random, TablerIcons.dice, 'remote.random.title'),
        _featureCard(context, _MoreFeature.announcements, TablerIcons.speakerphone, 'remote.tabAnnouncements'),
        _featureCard(context, _MoreFeature.sabbath, TablerIcons.book2, 'remote.sabbath.title'),
      ],
    );
  }

  Widget _featureCard(BuildContext context, _MoreFeature feature, IconData icon, String label) {
    final theme = Theme.of(context);
    return Material(
      key: Key(switch (feature) { _MoreFeature.time => 'remote-more-time', _MoreFeature.random => 'remote-more-random', _MoreFeature.announcements => 'remote-more-announcements', _MoreFeature.sabbath => 'remote-more-sabbath' }),
      color: theme.colorScheme.surfaceContainer,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _feature = feature),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 26),
            ),
            const SizedBox(height: AppSpacing.s2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
              child: Text(label.tr(), textAlign: TextAlign.center, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class RemoteClockRandomPanel extends StatelessWidget {
  const RemoteClockRandomPanel({
    super.key,
    this.clock,
    this.random,
    this.send,
  });

  final RemoteClockState? clock;
  final RemoteRandomState? random;
  final RemoteSend? send;

  RemoteSend get _send => send ?? _defaultSend;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      children: [
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
      child: ExpansionTile(
        key: const Key('remote-clock-expand'),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text('remote.clock.title'.tr()),
        subtitle: Text(c == null ? '—' : (c.format24h ? '24h' : '12h')),
        childrenPadding: const EdgeInsets.all(AppSpacing.s3),
        children: [
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
  static const _nameRowHeight = 48.0;
  static const _visibleNames = 5;
  final _participantsScroll = ScrollController();
  String _importDraft = '';
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  Future<void> _confirmClearList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('remote.random.clearList'.tr()),
        content: Text('remote.random.clearListConfirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('common.cancel'.tr())),
          FilledButton(
            key: const Key('remote-random-clear-list-confirm'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
            onPressed: () => Navigator.pop(context, true),
            child: Text('remote.random.clearList'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.send(RemoteAction.randomClearAvailable);
  }

  Future<void> _importNames() async {
    final form = GlobalKey<FormState>();
    final names = await showDialog<String>(context: context, builder: (context) {
      void submit() {
        if (form.currentState!.validate()) Navigator.pop(context, _importDraft.trim());
      }
      return AlertDialog(
        title: Text('remote.random.importNames'.tr()),
        content: Form(key: form, child: TextFormField(
          key: const Key('remote-random-names'),
          initialValue: _importDraft,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'remote.random.namesHint'.tr(), hintText: 'Maria\nJoão\nAna', alignLabelWithHint: true),
          onChanged: (value) => _importDraft = value,
          validator: (value) => (value ?? '').trim().isEmpty ? 'remote.random.nameRequired'.tr() : null,
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('common.cancel'.tr())),
          FilledButton(key: const Key('remote-random-import-save'), onPressed: submit, child: Text('remote.random.importNames'.tr())),
        ],
      );
    });
    if (names == null || names.isEmpty) return;
    _importDraft = '';
    await widget.send(RemoteAction.randomImportNames, namesText: names);
  }

  Future<void> _addReceptionName() async {
    final form = GlobalKey<FormState>();
    var draft = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        void submit() {
          if (form.currentState!.validate()) Navigator.pop(context, draft.trim());
        }
        return AlertDialog(
          title: Text('remote.random.addName'.tr()),
          content: Form(
            key: form,
            child: TextFormField(
              key: const Key('remote-random-name-input'),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: 'remote.random.personName'.tr(), helperText: 'remote.random.receptionHint'.tr(), helperMaxLines: 3),
              onChanged: (value) => draft = value,
              validator: (value) => (value ?? '').trim().isEmpty ? 'remote.random.nameRequired'.tr() : null,
              onFieldSubmitted: (_) => submit(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('common.cancel'.tr())),
            FilledButton.icon(key: const Key('remote-random-name-save'), onPressed: submit, icon: const Icon(TablerIcons.userPlus), label: Text('remote.random.includeName'.tr())),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) await widget.send(RemoteAction.randomAddName, name: name);
  }

  @override
  void dispose() {
    _participantsScroll.dispose();
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
            if (r?.audioSupported == true) ...[
              const SizedBox(height: AppSpacing.s3),
              _RandomAudioControls(random: r!, send: widget.send),
            ],
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
              FilledButton.icon(
                key: const Key('remote-random-add-name'),
                onPressed: _addReceptionName,
                icon: const Icon(TablerIcons.userPlus),
                label: Text('remote.random.addName'.tr()),
              ),
              const SizedBox(height: AppSpacing.s2),
              OutlinedButton.icon(
                key: const Key('remote-random-import'),
                onPressed: _importNames,
                icon: const Icon(TablerIcons.userPlus),
                label: Text('remote.random.importNames'.tr()),
              ),
              const SizedBox(height: AppSpacing.s3),
              Column(
                key: const Key('remote-random-participants'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Text('${'remote.random.namesList'.tr()} (${r?.available.length ?? 0})', style: Theme.of(context).textTheme.titleSmall)),
                    TextButton.icon(
                      key: const Key('remote-random-clear-list'),
                      onPressed: (r?.available ?? const []).isEmpty ? null : _confirmClearList,
                      icon: const Icon(TablerIcons.trash, size: 18),
                      label: Text('remote.random.clearList'.tr()),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.s2),
                  if ((r?.available ?? const []).isEmpty)
                    Padding(padding: const EdgeInsets.all(AppSpacing.s3), child: Text('remote.random.noNames'.tr()))
                  else Container(
                    key: const Key('remote-random-participants-viewport'),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    height: (r!.available.length * _nameRowHeight).clamp(_nameRowHeight, _nameRowHeight * _visibleNames),
                    child: Scrollbar(
                      key: const Key('remote-random-participants-scrollbar'),
                      controller: _participantsScroll,
                      thumbVisibility: r.available.length > _visibleNames,
                      trackVisibility: r.available.length > _visibleNames,
                      interactive: true,
                      child: ListView.builder(
                      controller: _participantsScroll,
                      primary: false,
                      padding: EdgeInsets.zero,
                      itemExtent: _nameRowHeight,
                      itemCount: r.available.length,
                      itemBuilder: (context, index) {
                        final name = r.available[index];
                        final drawn = r.drawn.contains(name);
                        final theme = Theme.of(context);
                        final color = drawn ? theme.colorScheme.onSurface.withValues(alpha: 0.38) : null;
                        return ListTile(
                          key: Key('remote-random-participant-$index'),
                          dense: true,
                          enabled: !drawn,
                          leading: Icon(TablerIcons.user, color: drawn ? color : theme.colorScheme.primary, size: 18),
                          title: Text(name, style: TextStyle(color: color, decoration: drawn ? TextDecoration.lineThrough : TextDecoration.none)),
                          trailing: IconButton(
                            key: Key('remote-random-remove-name-$index'),
                            tooltip: 'common.delete'.tr(),
                            icon: const Icon(TablerIcons.x),
                            onPressed: () => widget.send(RemoteAction.randomRemoveAvailable, index: index),
                          ),
                        );
                      },
                      ),
                    ),
                  ),
                ],
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
              OutlinedButton.icon(
                key: const Key('remote-random-clear-history'),
                onPressed: () => widget.send(RemoteAction.randomClearHistory),
                icon: const Icon(TablerIcons.eraser),
                label: Text('remote.random.clearHistory'.tr()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hino escolhido na busca, aguardando o operador apertar play.
class RemoteHymnSelection {
  const RemoteHymnSelection({required this.musicId, required this.mode});

  final int musicId;
  final String mode;
}

/// Painel Hinos: busca REMOTA no catálogo do alvo (ids corretos do
/// desktop — a API pública tem ids distintos e media.open falhava com
/// trackMissing). Tocar na linha só seleciona, para evitar projeção por toque
/// acidental: quem envia media.open é o play da barra do player.
class RemoteHymnsPanel extends StatefulWidget {
  const RemoteHymnsPanel({
    super.key,
    this.send,
    this.state,
    this.selectedMusicId,
    this.onSelectionChanged,
  });

  final RemoteSend? send;
  final RemotePlayerState? state;
  final int? selectedMusicId;

  /// Null = selecao desfeita.
  final ValueChanged<RemoteHymnSelection?>? onSelectionChanged;

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

  void _clearQuery() {
    _queryCtrl.clear();
    _lastQuery = '';
    _onQuery('');
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    // A linha escolhida sai da tela: o play nao pode ficar pulsando por ela.
    if (widget.selectedMusicId != null) widget.onSelectionChanged?.call(null);
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
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
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
                    suffixIcon: _queryCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            key: const Key('remote-hymns-clear'),
                            tooltip: 'remote.hymns.clear'.tr(),
                            icon: const Icon(TablerIcons.x),
                            onPressed: _clearQuery,
                          ),
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
                        onSelected: (_) {
                          setState(() => _mode = m);
                          final selected = widget.selectedMusicId;
                          if (selected != null) {
                            widget.onSelectionChanged?.call(
                              RemoteHymnSelection(musicId: selected, mode: m),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
              if (_searching) const LinearProgressIndicator(),
            ],
          ),
        ),
        if (hits.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'remote.hymns.empty'.tr(),
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final h = hits[i];
              final selected = h.musicId == widget.selectedMusicId;
              return ListTile(
                key: Key('remote-hymns-result-$i'),
                dense: true,
                selected: selected,
                selectedTileColor: theme.colorScheme.primary.withValues(
                  alpha: 0.16,
                ),
                title: Text(
                  h.track != null ? '${h.track} — ${h.name}' : h.name,
                ),
                onTap: () => widget.onSelectionChanged?.call(
                  selected
                      ? null
                      : RemoteHymnSelection(musicId: h.musicId, mode: _mode),
                ),
              );
            }, childCount: hits.length),
          ),
      ],
    );
  }
}

/// Controles do áudio que toca no desktop durante o sorteio.
class _RandomAudioControls extends StatefulWidget {
  const _RandomAudioControls({required this.random, required this.send});
  final RemoteRandomState random;
  final RemoteSend send;
  @override
  State<_RandomAudioControls> createState() => _RandomAudioControlsState();
}

class _RandomAudioControlsState extends State<_RandomAudioControls> {
  double? _volume;
  @override
  void didUpdateWidget(covariant _RandomAudioControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.random.audioVolume != widget.random.audioVolume) _volume = null;
  }
  @override
  Widget build(BuildContext context) {
    final r = widget.random;
    final volume = _volume ?? r.audioVolume.toDouble();
    final custom = r.audioSource == 'custom' && r.customAudioFiles.contains(r.customAudioFile);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('remote.random.audioTitle'.tr(), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      InputDecorator(
        decoration: InputDecoration(labelText: 'remote.random.audioSource'.tr(), isDense: true),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          key: const Key('remote-random-audio-source'),
          value: custom ? 'custom:${r.customAudioFile}' : 'default',
          isExpanded: true, isDense: true,
          items: [
            DropdownMenuItem(value: 'default', child: Text('remote.random.audioDefault'.tr())),
            for (final file in r.customAudioFiles) DropdownMenuItem(value: 'custom:$file', child: Text(file, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (value) {
            if (value == 'default') { widget.send(RemoteAction.randomUseDefaultAudio); }
            else if (value != null && value.startsWith('custom:')) { widget.send(RemoteAction.randomUseCustomAudio, name: value.substring(7)); }
          },
        )),
      ),
      Row(children: [
        IconButton(
          key: const Key('remote-random-audio-play'),
          tooltip: (r.audioPlaying ? 'remote.pause' : 'remote.play').tr(),
          icon: Icon(r.audioPlaying ? TablerIcons.playerPause : TablerIcons.playerPlay),
          onPressed: () => widget.send(RemoteAction.randomToggleAudio),
        ),
        IconButton(
          key: const Key('remote-random-audio-mute'),
          tooltip: 'remote.random.audioMute'.tr(),
          isSelected: r.audioMuted,
          icon: Icon(r.audioMuted ? TablerIcons.volumeOff : TablerIcons.volume),
          onPressed: () => widget.send(RemoteAction.randomToggleAudioMute),
        ),
        Expanded(child: Slider(
          key: const Key('remote-random-audio-volume'),
          min: 0, max: 100, value: volume, label: '${volume.round()}%',
          onChanged: (value) => setState(() => _volume = value),
          onChangeEnd: (value) => widget.send(RemoteAction.randomSetAudioVolume, volume: value.round()),
        )),
        Text('${volume.round()}%'),
      ]),
    ]);
  }
}
