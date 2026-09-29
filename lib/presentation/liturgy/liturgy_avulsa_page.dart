// Liturgia Avulsa: liturgia de uma data específica (não recorrente semanal).
// Usa storage próprio (liturgy_avulsa_yyyyMMdd) — não afeta a liturgia semanal.
library;

import 'dart:io' show File;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/services/liturgy_item_executor.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_item_dialog.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/datapacket_parser.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

class LiturgyAvulsaPage extends StatefulWidget {
  const LiturgyAvulsaPage({super.key});

  @override
  State<LiturgyAvulsaPage> createState() => _LiturgyAvulsaPageState();
}

class _LiturgyAvulsaPageState extends State<LiturgyAvulsaPage> {
  LiturgyRepository? _repo;
  ScheduledRepository? _scheduled;
  DateTime _date = DateTime.now();
  List<LiturgyItem> _items = [];
  List<ScheduledItemOnDate> _scheduledToday = [];
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _repo = LiturgyRepository(prefs);
    _scheduled = ScheduledRepository(prefs);
    _load();
  }

  /// Importa itensAgendados(.xml) do Delphi: pede os 2 arquivos em sequência.
  Future<void> _importScheduled(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    var file = picked?.files.singleOrNull;
    if (file == null) return;
    final fname = file.name.toLowerCase();
    const notPorted = [
      'coletaneasusuario',
      'favoritos',
      'videosonusuario',
      'configpt',
    ];
    if (notPorted.any(fname.startsWith)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'liturgy.scheduled.notPorted'.tr(namedArgs: {'name': file.name}),
          ),
        ),
      );
      return;
    }
    if (!fname.endsWith('.xml')) {
      messenger.showSnackBar(
        SnackBar(content: Text('liturgy.scheduled.invalidXml'.tr())),
      );
      return;
    }
    var data = file.bytes;
    if (data == null && file.path != null) {
      try {
        data = await File(file.path!).readAsBytes();
      } catch (_) {}
    }
    if (data == null) return;
    final catsXml = String.fromCharCodes(data);

    // segundo arquivo: itens (se o usuário cancelar, importa só categorias)
    List<Map<String, String>> itemRows = [];
    final picked2 = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    final f2 = picked2?.files.singleOrNull;
    if (f2 != null && f2.name.toLowerCase().endsWith('.xml')) {
      var d2 = f2.bytes;
      if (d2 == null && f2.path != null) {
        try {
          d2 = await File(f2.path!).readAsBytes();
        } catch (_) {}
      }
      if (d2 != null) {
        itemRows = DataPacketParser.parse(String.fromCharCodes(d2));
      }
    }

    final catRows = DataPacketParser.parse(catsXml);
    final n = await _scheduled!.importFromDelphi(
      categories: catRows,
      items: itemRows,
    );
    if (!mounted) return;
    _load();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'liturgy.scheduled.imported'.tr(namedArgs: {'count': '$n'}),
        ),
      ),
    );
  }

  void _load() {
    if (_repo == null) return;
    setState(() {
      _items = _repo!.loadAvulsa(_date);
      _locked = false;
      _scheduledToday = (_scheduled?.itemsOn(_date) ?? [])
          .map(
            (s) => ScheduledItemOnDate(
              item: s,
              category: _scheduled!
                  .loadCategories()
                  .where((c) => c.id == s.categoryId)
                  .firstOrNull,
            ),
          )
          .toList();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
      _load();
    }
  }

  Future<void> _persist() async {
    await _repo?.saveAvulsa(_date, _items);
  }

  String get _dateLabel {
    final d = _date;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('liturgy.avulsa.title'.tr()),
        actions: [
          IconButton(
            key: const Key('avulsa-import-scheduled'),
            tooltip: 'liturgy.scheduled.import'.tr(),
            icon: const Icon(TablerIcons.calendarDown, size: 22),
            onPressed: () => _importScheduled(context),
          ),
          IconButton(
            key: const Key('avulsa-lock-toggle'),
            tooltip: _locked ? 'liturgy.unlock'.tr() : 'liturgy.lock'.tr(),
            icon: Icon(
              _locked ? TablerIcons.lock : TablerIcons.lockOpen,
              size: 22,
              color: _locked ? theme.colorScheme.primary : null,
            ),
            onPressed: () => setState(() => _locked = !_locked),
          ),
          IconButton(
            key: const Key('avulsa-delete'),
            tooltip: 'liturgy.deleteDay'.tr(),
            icon: const Icon(TablerIcons.trash, size: 22),
            onPressed: _items.isEmpty || _locked
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('liturgy.deleteDayTitle'.tr()),
                        content: Text('liturgy.avulsa.deleteConfirm'.tr()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('common.cancel'.tr()),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('liturgy.deleteDay'.tr()),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      await _repo?.clearAvulsa(_date);
                      _load();
                    }
                  },
          ),
        ],
      ),
      floatingActionButton: _locked
          ? null
          : FloatingActionButton(
              key: const Key('avulsa-add-item'),
              onPressed: _items.isEmpty
                  ? () => showLiturgyItemDialog(
                      context,
                      isCategory: true,
                      onSubmit: (item) {
                        setState(() => _items = [..._items, item]);
                        _persist();
                      },
                    )
                  : null,
              child: const Icon(TablerIcons.plus, size: 24),
            ),
      body: _repo == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Seletor de data
                InkWell(
                  key: const Key('avulsa-date-picker'),
                  onTap: _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4,
                      vertical: AppSpacing.s3,
                    ),
                    color: theme.colorScheme.surfaceContainer,
                    child: Row(
                      children: [
                        Icon(
                          TablerIcons.calendar,
                          size: 22,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Text(
                          _dateLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'liturgy.avulsa.changeDate'.tr(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Itens agendados desta data (importados do Delphi)
                if (_scheduledToday.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s3,
                      AppSpacing.s2,
                      AppSpacing.s3,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'liturgy.scheduled.title'.tr(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        for (final s in _scheduledToday)
                          Card(
                            margin: const EdgeInsets.only(top: AppSpacing.s1),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(
                                TablerIcons.calendarEvent,
                                size: 20,
                              ),
                              title: Text(s.item.name),
                              subtitle: Text(
                                s.category?.name ??
                                    'liturgy.scheduled.noCategory'.tr(),
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (s.item.notes.isNotEmpty)
                                    IconButton(
                                      tooltip: 'liturgy.scheduled.notes'.tr(),
                                      icon: const Icon(
                                        TablerIcons.messageCircle,
                                        size: 18,
                                      ),
                                      onPressed: () => showDialog<void>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(s.item.name),
                                          content: Text(s.item.notes),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: Text('common.cancel'.tr()),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  IconButton(
                                    tooltip: 'liturgy.scheduled.addToLiturgy'
                                        .tr(),
                                    icon: const Icon(
                                      TablerIcons.plus,
                                      size: 18,
                                    ),
                                    onPressed: _locked
                                        ? null
                                        : () {
                                            setState(() {
                                              _items = [
                                                ..._items,
                                                LiturgyItem(
                                                  id: 'sched_${s.item.id}',
                                                  type: LiturgyItemType
                                                      .otherFiles,
                                                  name: s.item.name,
                                                  subtitle:
                                                      s.category?.name ?? '',
                                                  filePath:
                                                      s.item.filePath.isNotEmpty
                                                      ? s.item.filePath
                                                      : null,
                                                ),
                                              ];
                                            });
                                            _persist();
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _items.isEmpty && _scheduledToday.isEmpty
                      ? Center(child: Text('liturgy.avulsa.empty'.tr()))
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.s3),
                          buildDefaultDragHandles: false,
                          itemCount: _items.length,
                          onReorder: _locked
                              ? (_, __) {}
                              : (oldIndex, newIndex) async {
                                  final adjusted = newIndex > oldIndex
                                      ? newIndex - 1
                                      : newIndex;
                                  setState(() {
                                    final it = _items.removeAt(oldIndex);
                                    _items.insert(
                                      adjusted.clamp(0, _items.length),
                                      it,
                                    );
                                  });
                                  await _persist();
                                },
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            return Card(
                              key: ValueKey('avulsa-${item.id}'),
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.s1,
                              ),
                              child: ListTile(
                                title: Text(
                                  item.name.isEmpty
                                      ? item.type.name
                                      : item.name,
                                ),
                                subtitle: item.subtitle.isEmpty
                                    ? null
                                    : Text(item.subtitle),
                                onTap:
                                    !_locked &&
                                        LiturgyItemExecutor.isExecutable(
                                          item.type,
                                        )
                                    ? () => LiturgyItemExecutor.execute(
                                        context,
                                        item,
                                      )
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!_locked)
                                      ReorderableDragStartListener(
                                        index: i,
                                        child: Icon(
                                          TablerIcons.gripVertical,
                                          size: 18,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    GestureDetector(
                                      onTap: _locked
                                          ? null
                                          : () => setState(() {
                                              _items = _items
                                                  .map(
                                                    (e) => e.id == item.id
                                                        ? e.copyWith(
                                                            done: !e.done,
                                                          )
                                                        : e,
                                                  )
                                                  .toList();
                                              _persist();
                                            }),
                                      child: Icon(
                                        item.done
                                            ? TablerIcons.circleCheck
                                            : TablerIcons.circle,
                                        size: 22,
                                        color: item.done
                                            ? theme.colorScheme.primary
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      ),
                                    ),
                                    if (!_locked)
                                      IconButton(
                                        icon: const Icon(
                                          TablerIcons.dotsVertical,
                                          size: 20,
                                        ),
                                        onPressed: () => showLiturgyItemDialog(
                                          context,
                                          existing: item,
                                          onSubmit: (updated) {
                                            setState(() {
                                              _items = _items
                                                  .map(
                                                    (e) => e.id == updated.id
                                                        ? updated
                                                        : e,
                                                  )
                                                  .toList();
                                            });
                                            _persist();
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

/// Item agendado + sua categoria (p/ exibição na data).
class ScheduledItemOnDate {
  const ScheduledItemOnDate({required this.item, this.category});
  final ScheduledItem item;
  final ScheduledCategory? category;
}
