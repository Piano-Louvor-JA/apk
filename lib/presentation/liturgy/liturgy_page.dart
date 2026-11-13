// coverage:ignore-file
// ignore_for_file: deprecated_member_use
// UI de Liturgia
library;

import 'dart:async';
import 'player/local_liturgy_session.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/scheduled_resolver.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'player/local_liturgy_player_bar.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/scheduled_item_preview.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_timing.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/scheduled/scheduled_page.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_context_bar.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_session_summary.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_item_rules.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_cast_button.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_stop_video_button.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/ja_liturgy_parser.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/media_duration_reader.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_catalog_repository.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/weekday_math.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/services/liturgy_item_executor.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_item_dialog.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_site_browser_page.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_player_bar.dart';

/// Converte LiturgyItemType enum para a chave snake_case do i18n.
String _typeToKey(dynamic type) {
  final name = type.toString().split('.').last;
  // camelCase -> snake_case
  final snake = name.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );
  return snake;
}

class LiturgyPage extends StatefulWidget {
  final LiturgyBloc? testBloc;

  const LiturgyPage({super.key, this.testBloc});

  @override
  State<LiturgyPage> createState() => _LiturgyPageState();
}

/// O bloc nasce UMA vez por página e fecha ao sair. Antes ele era criado
/// dentro do build: qualquer reconstrução (tela pai, hot reload) trocava de
/// bloc, o item adicionado ia para um e a tela escutava outro (só aparecia
/// ao sair e voltar), e os antigos nunca fechavam.
class _LiturgyPageState extends State<LiturgyPage> {
  LiturgyBloc? _bloc;

  StreamSubscription<String>? _repositoryChanges;
  String? _language;
  int _generation = 0;
  static final _startedLanguages = <String>{};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.testBloc != null) return;
    final language = EasyLocalization.of(context)?.locale.languageCode ?? 'pt';
    if (_language == language) return;
    _language = language;
    final generation = ++_generation;
    SharedPreferences.getInstance().then((prefs) async {
      if (!mounted || generation != _generation) return;
      _repositoryChanges?.cancel();
      _bloc?.close();
      final repo = LiturgyRepository(prefs, locale: language);
      if (_startedLanguages.add(language)) await repo.resetCompletion();
      if (!mounted || generation != _generation) return;
      final bloc = LiturgyBloc(repo)
        ..add(LiturgyLoadRequested(_todayWeekday()));
      _repositoryChanges = LiturgyRepository.changes
          .where((lang) => lang == language)
          .listen((_) {
            if (!bloc.isClosed) bloc.add(LiturgyReloadRequested());
          });
      setState(() => _bloc = bloc);
    });
  }

  @override
  void dispose() {
    _generation++;
    _repositoryChanges?.cancel();
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = widget.testBloc ?? _bloc;
    if (bloc == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('liturgy.title'.tr()),
          actions: const [StageClearButton(), StageStopVideoButton()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return BlocProvider<LiturgyBloc>.value(
      value: bloc,
      child: const _LiturgyView(),
    );
  }

  LiturgyWeekday _todayWeekday() => weekdayFromDart(DateTime.now().weekday);
}

class _LiturgyView extends StatefulWidget {
  const _LiturgyView();

  @override
  State<_LiturgyView> createState() => _LiturgyViewState();
}

/// Liturgia NATIVA do apk: sempre a local, com ou sem Controle Remoto
/// conectado. A liturgia do desktop fica no Controle Remoto
/// (RemoteLiturgyPage), são coisas diferentes.
class _LiturgyViewState extends State<_LiturgyView> {
  /// Importa liturgia exportada pelo LouvorJA Delphi (arquivo .ja).
  ///
  /// Merge por dia: itens com mesmo (tipo+nome+musicaId/filePath) não
  /// duplicam; o restante é adicionado ao fim do dia correspondente.
  Future<void> _importJaFile(BuildContext context) async {
    // FileType.custom com extensão .ja não é selecionável no Android SAF
    // (mime desconhecido) — aceita qualquer arquivo e valida a extensão.
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;
    if (!file.name.toLowerCase().endsWith('.ja')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('liturgy.importJaInvalid'.tr())));
      return;
    }
    final Uint8List data;
    try {
      data = await file.readAsBytes();
    } catch (_) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final JaLiturgy imported;
    try {
      imported = JaLiturgyParser.parse(decodeJaFile(data));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('liturgy.importJaInvalid'.tr())),
      );
      return;
    }

    // Duração automática: música do catálogo; vídeo/áudio local do arquivo.
    await _enrichDurations(
      imported,
      EasyLocalization.of(context)?.locale.languageCode ?? 'pt',
    );

    final bloc = context.read<LiturgyBloc>();

    bool isDup(a, b) =>
        a.type == b.type &&
        a.name == b.name &&
        a.musicId == b.musicId &&
        a.filePath == b.filePath;

    // Pré-checa duplicados em TODOS os dias (sem alterar nada).
    var duplicates = 0;
    for (final day in imported.keys) {
      final target = LiturgyWeekdayJa.fromJaDay(day);
      if (target == null) continue;
      final existing = bloc.repository.loadItems(target);
      duplicates += imported[day]!
          .where((i) => existing.any((e) => isDup(e, i)))
          .length;
    }

    // Duplicados? Pergunta: sobrescrever dias afetados ou só adicionar novos.
    var overwrite = false;
    if (duplicates > 0 && context.mounted) {
      overwrite =
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('liturgy.importJaOverwriteTitle'.tr()),
              content: Text(
                'liturgy.importJaOverwriteAsk'.tr(
                  namedArgs: {'count': '$duplicates'},
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('liturgy.importJaKeep'.tr()),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('liturgy.importJaOverwrite'.tr()),
                ),
              ],
            ),
          ) ??
          false;
    }

    var added = 0;
    var skipped = 0;
    // Escrita DIRETA no repository — determinística, sem corrida de eventos
    // do bloc (bug real: DayChanged/ClearDay/AddItem na fila podiam limpar o
    // dia recém-importado ou ler estado parcial).
    for (final day in imported.keys) {
      final target = LiturgyWeekdayJa.fromJaDay(day);
      if (target == null) continue;
      final incoming = imported[day]!;
      final existing = bloc.repository.loadItems(target);
      final next = overwrite ? <LiturgyItem>[] : [...existing];
      for (final item in incoming) {
        if (next.any((e) => isDup(e, item))) {
          skipped++;
          continue;
        }
        next.add(item);
        added++;
      }
      await bloc.repository.saveItems(target, next);
    }
    // Recarrega o dia corrente pra UI refletir a importação.
    if (context.mounted) {
      final state = bloc.state;
      final current = state is LiturgyLoaded ? state.selectedDay : null;
      bloc.add(LiturgyDayChanged(current ?? LiturgyWeekday.saturday));
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          overwrite
              ? 'liturgy.importJaOverwritten'.tr(namedArgs: {'added': '$added'})
              : 'liturgy.importJaDone'.tr(
                  namedArgs: {'added': '$added', 'skipped': '$skipped'},
                ),
        ),
      ),
    );
  }

  /// Preenche durationMs: música via índice da API; vídeo/áudio via
  /// leitura do MP4 local (caminho existente no dispositivo).
  Future<void> _enrichDurations(JaLiturgy imported, String locale) async {
    final musicIds = <int>{};
    final localPaths = <String>{};
    for (final items in imported.values) {
      for (final item in items) {
        if (item.type == LiturgyItemType.music && item.musicId != null) {
          musicIds.add(item.musicId!);
        } else if (item.durationMs == 0 &&
            item.filePath != null &&
            (item.type == LiturgyItemType.video ||
                item.type == LiturgyItemType.otherFiles)) {
          localPaths.add(item.filePath!);
        }
      }
    }
    if (musicIds.isEmpty && localPaths.isEmpty) return;

    // Música: duração do índice (offline-first: cache da API).
    Map<int, int> durationsById = {};
    if (musicIds.isNotEmpty) {
      try {
        final catalog = await LiturgyCatalogRepository.open(locale);
        final index = await catalog.musicIndex();
        durationsById = {
          for (final h in index)
            if (h.durationMs != null) h.id: h.durationMs!,
        };
      } catch (_) {
        // sem rede: durações ficam 0
      }
    }

    // Vídeo/áudio local: parse MP4.
    final probedPaths = <String, int>{};
    for (final path in localPaths) {
      final ms = await MediaDurationReader.readMs(path);
      if (ms > 0) probedPaths[path] = ms;
    }

    for (final day in imported.keys) {
      final items = imported[day]!;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item.type == LiturgyItemType.music &&
            item.musicId != null &&
            item.durationMs == 0) {
          final d = durationsById[item.musicId!];
          if (d != null) items[i] = item.copyWith(durationMs: d);
        } else if (item.filePath != null &&
            probedPaths.containsKey(item.filePath)) {
          items[i] = item.copyWith(durationMs: probedPaths[item.filePath!]!);
        }
      }
    }
  }

  Future<void> _confirmDeleteDay(
    BuildContext context,
    LiturgyLoaded state,
  ) async {
    final l10nDay = 'liturgy.days.${state.selectedDay.name}'.tr();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('liturgy.deleteDayTitle'.tr()),
        content: Text(
          'liturgy.deleteDayConfirm'.tr(namedArgs: {'count': l10nDay}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('liturgy.deleteDay'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<LiturgyBloc>().add(LiturgyClearDay());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('liturgy.title'.tr()),
        actions: [
          IconButton(
            key: const Key('liturgy-import-ja'),
            tooltip: 'liturgy.importJa'.tr(),
            icon: const Icon(TablerIcons.fileImport, size: 22),
            onPressed: () => _importJaFile(context),
          ),
          IconButton(
            key: const Key('liturgy-scheduled-manage'),
            tooltip: 'liturgy.scheduled.title'.tr(),
            icon: const Icon(TablerIcons.calendarTime),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ScheduledPage()),
            ),
          ),
          IconButton(
            key: const Key('liturgy-avulsa-btn'),
            tooltip: 'liturgy.avulsa.openAvulsa'.tr(),
            icon: const Icon(TablerIcons.calendarPlus, size: 22),
            onPressed: () => LiturgyContextBar.createCustom(context),
          ),
          BlocBuilder<LiturgyBloc, LiturgyState>(
            builder: (context, state) {
              final locked = state is LiturgyLoaded && state.locked;
              return IconButton(
                key: const Key('liturgy-lock-toggle'),
                tooltip: locked ? 'liturgy.unlock'.tr() : 'liturgy.lock'.tr(),
                icon: Icon(
                  locked ? TablerIcons.lock : TablerIcons.lockOpen,
                  size: 22,
                  color: locked ? theme.colorScheme.primary : null,
                ),
                onPressed: state is LiturgyLoaded
                    ? () =>
                          context.read<LiturgyBloc>().add(LiturgyLockToggled())
                    : null,
              );
            },
          ),
          BlocBuilder<LiturgyBloc, LiturgyState>(
            builder: (context, state) {
              final loaded = state is LiturgyLoaded;
              final hasItems = loaded && state.items.isNotEmpty;
              final locked = loaded && state.locked;
              return IconButton(
                key: const Key('liturgy-delete-day'),
                tooltip: 'liturgy.deleteDay'.tr(),
                icon: const Icon(TablerIcons.trash, size: 22),
                onPressed: hasItems && !locked
                    ? () => _confirmDeleteDay(context, state)
                    : null,
              );
            },
          ),
          const StageClearButton(),
        ],
      ),
      floatingActionButton: StreamBuilder<RemotePlayerState>(
        stream: localLiturgyPlayer.stream,
        initialData: localLiturgyPlayer.state,
        builder: (context, snapshot) {
          if (localLiturgyPlayer.pending != null ||
              localLiturgyPlayer.busy ||
              snapshot.data?.hasOpenMedia == true)
            return const SizedBox.shrink();
          return BlocBuilder<LiturgyBloc, LiturgyState>(
            builder: (context, state) {
              if (state is LiturgyLoaded) {
                return FloatingActionButton(
                  key: const Key('liturgy-add-moment'),
                  tooltip: 'liturgy.actions.add'.tr(),
                  onPressed: () => showLiturgyItemDialog(context),
                  child: const Icon(TablerIcons.plus, size: 24),
                );
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
      body: BlocBuilder<LiturgyBloc, LiturgyState>(
        builder: (context, state) {
          if (state is! LiturgyLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return _Body(state: state);
        },
      ),
    );
  }
}

/// Lista espelhada da liturgia do desktop com os controles no rodapé.
///
/// Tocar no item só escolhe; quem executa no desktop (liturgy.select) é o play.
/// Item concluído não executa, igual ao botão play da linha no desktop.
class RemoteLiturgyMirror extends StatefulWidget {
  final RemotePlayerState state;

  /// Injetável para testes; default = sessão global.
  final Future<void> Function(RemoteCommand command)? send;

  /// Abre o navegador do celular para um item de site. Injetável para testes.
  final Future<void> Function(BuildContext context, RemoteSiteBrowserPage page)?
  openSite;

  const RemoteLiturgyMirror({
    super.key,
    required this.state,
    this.send,
    this.openSite,
  });

  @override
  State<RemoteLiturgyMirror> createState() => _RemoteLiturgyMirrorState();
}

class _RemoteLiturgyMirrorState extends State<RemoteLiturgyMirror> {
  int? _chosenIndex;

  RemotePlayerState get state => widget.state;

  Future<void> _select(int index, {bool toggleDone = false}) {
    return (widget.send ?? RemoteSession.instance.send)(
      RemoteCommand(
        id: 'l${DateTime.now().microsecondsSinceEpoch}',
        action: toggleDone
            ? RemoteAction.liturgyToggleDone
            : RemoteAction.liturgySelect,
        index: index,
      ),
    );
  }

  /// A escolha só vale enquanto o item existe e não foi concluído.
  int? get _validChosen {
    if (state.hasOpenMedia) return null;
    final chosen = _chosenIndex;
    if (chosen == null) return null;
    for (final item in state.liturgyItems) {
      if (item.index == chosen) return item.done ? null : chosen;
    }
    return null;
  }

  void _toggleChosen(int index) {
    setState(() => _chosenIndex = _validChosen == index ? null : index);
  }

  Future<void> _sendCommand(RemoteCommand command) =>
      (widget.send ?? RemoteSession.instance.send)(command);

  String _commandId() => 's${DateTime.now().microsecondsSinceEpoch}';

  /// Link de site navegável no celular, ou null para seguir o fluxo normal.
  String? _siteUrlOf(int index) {
    for (final item in state.liturgyItems) {
      if (item.index != index) continue;
      final url = item.type == 'site' ? item.url?.trim() : null;
      if (url == null || RemoteSiteBrowserPage.normalize(url) == null) {
        return null;
      }
      return url;
    }
    return null;
  }

  /// Play no site: abre o site no desktop (sem projetar) e o navegador do
  /// celular, que espelha página e rolagem; a seta de lá projeta.
  Future<void> _openSite(int index, String url) {
    final item = state.liturgyItems.firstWhere((e) => e.index == index);
    _sendCommand(
      RemoteCommand(
        id: _commandId(),
        action: RemoteAction.liturgyOpen,
        index: index,
      ),
    );
    final page = RemoteSiteBrowserPage(
      url: url,
      title: item.title ?? url,
      onToggleScreens: () => _sendCommand(
        RemoteCommand(
          id: _commandId(),
          action: RemoteAction.videoToggleProjection,
        ),
      ),
      onNavigate: (url) => _sendCommand(
        RemoteCommand(
          id: _commandId(),
          action: RemoteAction.siteNavigate,
          url: url,
        ),
      ),
      onScroll: (ratio) => _sendCommand(
        RemoteCommand(
          id: _commandId(),
          action: RemoteAction.siteScroll,
          ratio: ratio,
        ),
      ),
    );
    return (widget.openSite ?? RemoteSiteBrowserPage.open)(context, page);
  }

  void _executeChosen(int index) {
    setState(() => _chosenIndex = null);
    final siteUrl = _siteUrlOf(index);
    if (siteUrl != null && state.liturgyCanOpen) {
      _openSite(index, siteUrl);
      return;
    }
    if (!state.liturgyCanOpen) {
      _select(index);
      return;
    }
    (widget.send ?? RemoteSession.instance.send)(
      RemoteCommand(
        id: 'l${DateTime.now().microsecondsSinceEpoch}',
        action: RemoteAction.liturgyOpen,
        index: index,
      ),
    );
  }

  /// Converte item remoto em LiturgyItem para renderizar o MESMO card do
  /// módulo (visual idêntico: accent por tipo, ícone, colapso).
  LiturgyItem _toItem(RemoteLiturgyItem e) {
    final type = LiturgyItemType.values.firstWhere(
      (t) => t.name == e.type,
      orElse: () => LiturgyItemType.category,
    );
    return LiturgyItem(
      id: 'remote-${e.index}',
      type: type,
      name: e.title ?? e.type,
      subtitle: e.subtitle ?? '',
      done: e.done,
      accentColor: e.accentColor ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Agrupa categorias + filhos como a timeline do módulo (flat remote
    // list não traz categoryId — usa isCategory + ordem).
    final children = <Widget>[];
    final items = state.liturgyItems;
    final chosen = _validChosen;
    // Com mídia aberta, um toque acidental iniciaria outro item junto.
    final locked = state.hasOpenMedia;
    for (final e in items) {
      final item = _toItem(e);
      // Com escolha pendente, só ela fica destacada.
      final isSel = e.index == (chosen ?? state.liturgySelectedIndex);
      final isCat = e.isCategory;
      children.add(
        Padding(
          key: Key('mirror-liturgy-${e.index}'),
          padding: EdgeInsets.only(left: isCat ? 0 : 32, bottom: isCat ? 0 : 4),
          child: _MirrorItemCard(
            key: Key('mirror-liturgy-tap-${e.index}'),
            item: item,
            isCategory: isCat,
            theme: theme,
            selected: isSel,
            onTap: isCat || e.done || locked
                ? null
                : () => _toggleChosen(e.index),
            onToggleDone: locked
                ? null
                : () => _select(e.index, toggleDone: true),
          ),
        ),
      );
    }
    return Column(
      children: [
        // Banner de espelho
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Row(
            children: [
              Icon(
                TablerIcons.deviceTv,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'remote.mirroringLocked'.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                TablerIcons.lock,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
        Expanded(
          child: Opacity(
            opacity: locked ? 0.5 : 1,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s3),
              children: children,
            ),
          ),
        ),
        RemotePlayerBar(
          state: state,
          showTransport: true,
          send: widget.send,
          pendingOpen: chosen == null ? null : () => _executeChosen(chosen),
        ),
      ],
    );
  }
}

/// Card do espelho: mesmo visual do _ItemCard do módulo, mas ações apontam
/// pro desktop (select/toggleDone) — read-only localmente.
class _MirrorItemCard extends StatelessWidget {
  final LiturgyItem item;
  final bool isCategory;
  final ThemeData theme;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onToggleDone;

  const _MirrorItemCard({
    super.key,
    required this.item,
    required this.isCategory,
    required this.theme,
    required this.selected,
    required this.onTap,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    final typeMeta = LiturgyTypeRegistry.metaFor(item.type);
    final accent = item.accentColor.isNotEmpty
        ? _parseHexStatic(item.accentColor, theme)
        : typeMeta.color;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s1),
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : isCategory
          ? accent.withValues(alpha: 0.10)
          : theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCategory
            ? BorderSide(color: accent.withValues(alpha: 0.4), width: 1)
            : selected
            ? BorderSide(color: theme.colorScheme.primary, width: 1)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s1,
        ),
        leading: Container(
          width: isCategory ? 36 : 28,
          height: isCategory ? 36 : 28,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Icon(typeMeta.icon, size: isCategory ? 20 : 16, color: accent),
        ),
        title: Text(
          item.name.isEmpty
              ? 'liturgy.types.${_typeToKey(item.type)}'.tr()
              : [
                  item.complementaryTitle,
                  item.name,
                ].whereType<String>().where((s) => s.isNotEmpty).join(' — '),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isCategory ? FontWeight.w700 : FontWeight.w500,
            fontSize: isCategory ? null : 14,
            decoration: item.done ? TextDecoration.lineThrough : null,
            color: item.done ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: item.subtitle.isNotEmpty
            ? Text(
                item.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              )
            : null,
        trailing: GestureDetector(
          onTap: onToggleDone,
          child: Icon(
            item.done ? TablerIcons.circleCheck : TablerIcons.circle,
            size: 22,
            color: item.done
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

Color _parseHexStatic(String hex, ThemeData theme) {
  final cleaned = hex.replaceAll('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  if (cleaned.length == 8) {
    return Color(int.parse(cleaned, radix: 16));
  }
  return theme.colorScheme.primary;
}

class _Body extends StatefulWidget {
  final LiturgyLoaded state;

  const _Body({required this.state});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final Set<String> _collapsedCategories = {};
  Widget _timeline() => widget.state.items.isEmpty
      ? _EmptyState()
      : _Timeline(
          items: widget.state.items,
          collapsedCategories: _collapsedCategories,
          onToggleCollapse: (id) => setState(() {
            if (!_collapsedCategories.add(id)) _collapsedCategories.remove(id);
          }),
          locked: widget.state.locked,
        );
  @override
  Widget build(BuildContext context) => StreamBuilder<RemotePlayerState>(
    stream: localLiturgyPlayer.stream,
    initialData: localLiturgyPlayer.state,
    builder: (context, snapshot) {
      final mediaOpen =
          snapshot.data?.hasOpenMedia == true || localLiturgyPlayer.busy;
      final showPlayer = mediaOpen || localLiturgyPlayer.pending != null;
      return LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            AbsorbPointer(
              absorbing: mediaOpen,
              child: _DayTabs(
                selectedDay: widget.state.customId == null
                    ? widget.state.selectedDay
                    : null,
              ),
            ),
            AbsorbPointer(
              absorbing: mediaOpen,
              child: LiturgyContextBar(state: widget.state),
            ),
            if (!showPlayer)
              LiturgySessionSummary(
                key: ValueKey('summary-${widget.state.contextKey}'),
                state: widget.state,
              ),
            Expanded(
              child: AbsorbPointer(
                absorbing: mediaOpen,
                child: mediaOpen
                    ? Opacity(opacity: .45, child: _timeline())
                    : _timeline(),
              ),
            ),
            if (!showPlayer)
              _NotesBar(
                key: ValueKey('notes-${widget.state.contextKey}'),
                notes: widget.state.notes,
              ),
            if (showPlayer)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .65,
                ),
                child: const SingleChildScrollView(
                  child: LocalLiturgyPlayerBar(),
                ),
              ),
          ],
        ),
      );
    },
  );
}

// --- Day Tabs ---

class _DayTabs extends StatelessWidget {
  final LiturgyWeekday? selectedDay;

  const _DayTabs({required this.selectedDay});

  String _label(LiturgyWeekday day) {
    const keys = {
      LiturgyWeekday.sunday: 'liturgy.days.sunday',
      LiturgyWeekday.monday: 'liturgy.days.monday',
      LiturgyWeekday.tuesday: 'liturgy.days.tuesday',
      LiturgyWeekday.wednesday: 'liturgy.days.wednesday',
      LiturgyWeekday.thursday: 'liturgy.days.thursday',
      LiturgyWeekday.friday: 'liturgy.days.friday',
      LiturgyWeekday.saturday: 'liturgy.days.saturday',
    };
    return keys[day]?.tr() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s1,
        vertical: AppSpacing.s2,
      ),
      child: Row(
        children: liturgyDayTabOrder.map((day) {
          final isSelected = day == selectedDay;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () {
                  context.read<LiturgyBloc>().add(LiturgyDayChanged(day));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _label(day),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// --- Timeline hierarquica ---

/// Segmento da timeline: ou uma categoria (com ou sem filhos) ou item avulso.
class _TimelineSegment {
  final LiturgyItem item;
  final int originalIndex;
  final List<_ChildEntry> children;

  _TimelineSegment({
    required this.item,
    required this.originalIndex,
    List<_ChildEntry>? children,
  }) : children = children ?? const [];
}

class _ChildEntry {
  final LiturgyItem item;
  final int originalIndex;

  const _ChildEntry({required this.item, required this.originalIndex});
}

List<_TimelineSegment> _buildSegments(List<LiturgyItem> items) {
  final segments = <_TimelineSegment>[];
  int i = 0;
  while (i < items.length) {
    final item = items[i];
    if (item.type == LiturgyItemType.category) {
      final catIndex = i;
      i++;
      final children = <_ChildEntry>[];
      while (i < items.length &&
          items[i].type != LiturgyItemType.category &&
          items[i].categoryId == item.id) {
        children.add(_ChildEntry(item: items[i], originalIndex: i));
        i++;
      }
      segments.add(
        _TimelineSegment(
          item: item,
          originalIndex: catIndex,
          children: children,
        ),
      );
    } else {
      segments.add(
        _TimelineSegment(item: item, originalIndex: i, children: const []),
      );
      i++;
    }
  }
  return segments;
}

class _Timeline extends StatelessWidget {
  final List<LiturgyItem> items;
  final Set<String> collapsedCategories;
  final ValueChanged<String> onToggleCollapse;
  final bool locked;

  const _Timeline({
    required this.items,
    required this.collapsedCategories,
    required this.onToggleCollapse,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = _buildSegments(items);

    void reorderSegments(int oldIndex, int newIndex) {
      final bloc = context.read<LiturgyBloc>();
      // Move bloco: categoria + seus filhos (ou item avulso)
      final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
      final seg = segments.removeAt(oldIndex);
      segments.insert(adjusted.clamp(0, segments.length), seg);
      // Reconstruir lista plana na nova ordem
      final flat = <LiturgyItem>[];
      for (final s in segments) {
        flat.add(s.item);
        flat.addAll(s.children.map((c) => c.item));
      }
      bloc.add(LiturgyItemsReordered(flat));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.s3),
      buildDefaultDragHandles: false,
      itemCount: segments.length,
      onReorder: reorderSegments,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final elevation = Tween<double>(
            begin: 0,
            end: 6,
          ).animate(animation).value;
          return Material(
            elevation: elevation,
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
            shadowColor: Colors.transparent,
            child: child,
          );
        },
        child: child,
      ),
      itemBuilder: (context, segIndex) {
        final seg = segments[segIndex];
        final isCategory = seg.item.type == LiturgyItemType.category;
        final isCollapsed =
            isCategory && collapsedCategories.contains(seg.item.id);

        return Column(
          key: ValueKey('seg-${seg.item.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ItemCard(
              item: seg.item,
              isCategory: isCategory,
              theme: theme,
              hasChildren: seg.children.isNotEmpty,
              categoryChildren: seg.children.map((e) => e.item).toList(),
              isCollapsed: isCollapsed,
              draggable: true,
              dragIndex: segIndex,
              onToggleCollapse: isCategory && seg.children.isNotEmpty
                  ? () => onToggleCollapse(seg.item.id)
                  : null,
            ),
            if (!isCollapsed && seg.children.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: seg.children.length,
                onReorder: (from, to) {
                  final adjusted = to > from ? to - 1 : to;
                  final children = seg.children.map((e) => e.item).toList();
                  final moved = children.removeAt(from);
                  children.insert(adjusted.clamp(0, children.length), moved);
                  final next = [...items];
                  for (var index = 0; index < seg.children.length; index++) {
                    next[seg.children[index].originalIndex] = children[index];
                  }
                  context.read<LiturgyBloc>().add(LiturgyItemsReordered(next));
                },
                itemBuilder: (context, index) {
                  final child = seg.children[index];
                  return Padding(
                    key: ValueKey('child-${child.item.id}'),
                    padding: const EdgeInsets.only(left: 32, bottom: 4),
                    child: _ItemCard(
                      item: child.item,
                      isCategory: false,
                      theme: theme,
                      isChild: true,
                      draggable: true,
                      dragIndex: index,
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

// --- Item Card ---

class _ItemCard extends StatelessWidget {
  final LiturgyItem item;
  final bool isCategory;
  final ThemeData theme;
  final bool isChild;
  final bool hasChildren;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final bool draggable;
  final int dragIndex;
  final List<LiturgyItem> categoryChildren;

  const _ItemCard({
    required this.item,
    required this.isCategory,
    required this.theme,
    this.isChild = false,
    this.hasChildren = false,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.draggable = false,
    this.dragIndex = 0,
    this.categoryChildren = const [],
  });

  @override
  Widget build(BuildContext context) {
    final currentState = context.watch<LiturgyBloc>().state;
    final deletionLocked = currentState is LiturgyLoaded && currentState.locked;
    final selected =
        localLiturgyPlayer.pending?.id == item.id ||
        (currentState is LiturgyLoaded &&
            currentState.selectedItemId == item.id);
    final date = currentState is LiturgyLoaded
        ? LiturgyTiming.activeDate(
            currentState.customId == null ? currentState.selectedDay : null,
          )
        : DateTime.now();
    final typeMeta = LiturgyTypeRegistry.metaFor(item.type);
    final accent = item.accentColor.isNotEmpty
        ? _parseHex(item.accentColor)
        : typeMeta.color;

    return Card(
      margin: EdgeInsets.only(
        bottom: isChild ? 2 : AppSpacing.s1,
        top: isChild ? 0 : 0,
      ),
      color: selected
          ? theme.colorScheme.primaryContainer
          : isCategory
          ? accent.withValues(alpha: 0.10)
          : isChild
          ? theme.colorScheme.surfaceContainerLow
          : theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        side: isCategory
            ? BorderSide(color: accent.withValues(alpha: 0.4), width: 1)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap:
            !isCategory &&
                (!item.done || LiturgyItemRules.keepsControls(item)) &&
                (LiturgyItemExecutor.isExecutable(item.type) ||
                    item.type == LiturgyItemType.notice ||
                    item.type == LiturgyItemType.prayer)
            ? () async {
                final bloc = context.read<LiturgyBloc>();
                final state = bloc.state;
                final language =
                    EasyLocalization.of(context)?.locale.languageCode ?? 'pt';
                final date = state is LiturgyLoaded
                    ? LiturgyTiming.activeDate(
                        state.customId == null ? state.selectedDay : null,
                      )
                    : DateTime.now();
                var selected = item;
                if (item.type == LiturgyItemType.scheduled) {
                  final repo = ScheduledRepository(
                    await SharedPreferences.getInstance(),
                  );
                  final resolved = ScheduledResolver.resolve(
                    item,
                    date,
                    repo.loadCategories(),
                    repo.loadItems(),
                  );
                  if (!context.mounted) return;
                  if (resolved == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('liturgy.parity.scheduledEmpty'.tr()),
                      ),
                    );
                    return;
                  }
                  selected = resolved;
                }
                final internal = LiturgyItemRules.playsInLocalPlayer(selected);
                void started(LiturgyItem _) {
                  if (!bloc.isClosed) {
                    bloc.add(LiturgySelectItem(item.id));
                    bloc.add(LiturgyMarkDone(item.id));
                  }
                }

                void changed(LiturgyItem value) {
                  if (!bloc.isClosed) bloc.add(LiturgyUpdateItem(value));
                }

                localLiturgyPlayer.choose(
                  selected,
                  language: language,
                  date: date,
                  onStarted: internal ? started : null,
                  onChanged: state is LiturgyLoaded && state.locked
                      ? null
                      : changed,
                  externalOpen: internal
                      ? null
                      : () async {
                          if (!context.mounted) return;
                          final message = await LiturgyItemExecutor.execute(
                            context,
                            selected,
                            date: date,
                            onStarted: () => started(selected),
                            onAnnotationChanged: changed,
                          );
                          if (message.isNotEmpty && context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          }
                        },
                );
              }
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s1,
        ),
        leading: Container(
          width: isChild ? 28 : 36,
          height: isChild ? 28 : 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Icon(typeMeta.icon, size: isChild ? 16 : 20, color: accent),
        ),
        title: Text(
          item.name.isEmpty
              ? 'liturgy.types.${_typeToKey(item.type)}'.tr()
              : [
                  item.complementaryTitle,
                  item.name,
                ].whereType<String>().where((s) => s.isNotEmpty).join(' — '),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isCategory ? FontWeight.w700 : FontWeight.w500,
            fontSize: isChild ? 14 : null,
            decoration: item.done ? TextDecoration.lineThrough : null,
            color: item.done ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCategory && item.startTime?.isNotEmpty == true)
              Text(
                item.endTime?.isNotEmpty == true
                    ? '${item.startTime} – ${item.endTime}'
                    : LiturgyTiming.categoryEnd(item, categoryChildren) == null
                    ? item.startTime!
                    : '${item.startTime} – ~${(categoryChildren.fold<int>(0, (sum, child) => sum + LiturgyItemRules.durationMs(child)) / 60000).round()} min · ${'liturgy.parity.estimated'.tr()}',
                style: theme.textTheme.bodySmall,
              ),
            if (item.type == LiturgyItemType.scheduled)
              ScheduledItemPreview(item: item, date: date),
            if (item.subtitle.isNotEmpty)
              Text(
                item.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            if (item.notes?.isNotEmpty == true)
              Text(item.notes!, style: theme.textTheme.bodySmall),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (draggable)
              ReorderableDragStartListener(
                key: Key('drag-${item.id}'),
                index: dragIndex,
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    TablerIcons.gripVertical,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (isCategory && hasChildren && onToggleCollapse != null)
              IconButton(
                icon: Icon(
                  isCollapsed
                      ? TablerIcons.chevronRight
                      : TablerIcons.chevronDown,
                  size: 20,
                ),
                tooltip: isCollapsed
                    ? 'liturgy.actions.expand'.tr()
                    : 'liturgy.actions.collapse'.tr(),
                onPressed: onToggleCollapse,
              ),
            if (isCategory)
              IconButton(
                icon: const Icon(TablerIcons.plus, size: 20),
                tooltip: 'liturgy.actions.addSubItem'.tr(),
                onPressed: () =>
                    showLiturgyItemDialog(context, parentCategoryId: item.id),
              ),
            if (LiturgyItemRules.durationMs(item) > 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s1),
                child: Text(
                  '${item.durationMs ~/ 60000}${'liturgy.durationMin'.tr()}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () {
                context.read<LiturgyBloc>().add(LiturgyToggleDone(item.id));
              },
              child: Icon(
                item.done ? TablerIcons.circleCheck : TablerIcons.circle,
                size: 22,
                color: item.done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(TablerIcons.dotsVertical, size: 20),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'edit',
                  enabled: !deletionLocked,
                  child: Row(
                    children: [
                      const Icon(TablerIcons.pencil, size: 18),
                      const SizedBox(width: 8),
                      Text('liturgy.actions.edit'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: !deletionLocked,
                  child: Row(
                    children: [
                      const Icon(
                        TablerIcons.trash,
                        size: 18,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text('liturgy.actions.delete'.tr()),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'edit') {
                  showLiturgyItemDialog(context, existing: item);
                } else if (value == 'delete') {
                  final bloc = context.read<LiturgyBloc>();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('liturgy.actions.delete'.tr()),
                      content: Text(
                        isCategory
                            ? 'liturgy.parity.deleteCategoryConfirm'.tr(
                                namedArgs: {'name': item.name},
                              )
                            : item.name,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('common.cancel'.tr()),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('liturgy.actions.delete'.tr()),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && !bloc.isClosed)
                    bloc.add(LiturgyDeleteItem(item.id));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return theme.colorScheme.primary;
  }
}

// --- Empty State ---

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TablerIcons.clipboardList,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'liturgy.emptyList'.tr(),
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s4),
            FilledButton.icon(
              onPressed: () => showLiturgyItemDialog(context, isCategory: true),
              icon: const Icon(TablerIcons.plus, size: 18),
              label: Text('liturgy.addItem'.tr()),
            ),
            const SizedBox(height: AppSpacing.s2),
            OutlinedButton.icon(
              key: const Key('liturgy-open-avulsa'),
              onPressed: () => LiturgyContextBar.createCustom(context),
              icon: const Icon(TablerIcons.calendarPlus, size: 18),
              label: Text('liturgy.avulsa.openAvulsa'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Notes Bar ---

class _NotesBar extends StatefulWidget {
  final String notes;

  const _NotesBar({super.key, required this.notes});
  @override
  State<_NotesBar> createState() => _NotesBarState();
}

class _NotesBarState extends State<_NotesBar> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.notes);
  }

  @override
  void didUpdateWidget(covariant _NotesBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notes != _controller.text && oldWidget.notes != widget.notes)
      _controller.text = widget.notes;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'liturgy.notesPlaceholder'.tr(),
          prefixIcon: const Icon(TablerIcons.notes, size: 20),
          isDense: true,
          border: InputBorder.none,
        ),
        style: theme.textTheme.bodySmall,
        controller: _controller,
        onChanged: (v) {
          context.read<LiturgyBloc>().add(LiturgyUpdateNotes(v));
        },
      ),
    );
  }
}

// --- Dialog de criar/editar item ---
