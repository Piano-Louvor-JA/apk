import 'package:louvorja_piano_mobile/core/services/liturgy/ja_liturgy_parser.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/quarter_paste_parser.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/datapacket_parser.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/scheduled_resolver.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_item_dialog.dart';
import 'scheduled_bloc.dart';
import 'provai_panel.dart';

class ScheduledPage extends StatelessWidget {
  const ScheduledPage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<SharedPreferences>(
    future: SharedPreferences.getInstance(),
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return BlocProvider(
        create: (_) =>
            ScheduledBloc(ScheduledRepository(snapshot.data!))
              ..add(const ScheduledLoadRequested()),
        child: const _ScheduledView(),
      );
    },
  );
}

class _ScheduledView extends StatefulWidget {
  const _ScheduledView();
  @override
  State<_ScheduledView> createState() => _ScheduledViewState();
}

class _ScheduledViewState extends State<_ScheduledView> {
  final _paste = TextEditingController();
  final _mapping = <String, String>{};
  bool _autoCreate = false;
  List<String> get _slots =>
      QuarterPasteParser.parse(_paste.text, year: DateTime.now().year).groups
          .expand((group) => group.entries)
          .map((entry) => entry.slotKey)
          .toSet()
          .toList();
  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _category(ScheduledState state, {bool rename = false}) async {
    final bloc = context.read<ScheduledBloc>();
    final category = state.categories
        .where((e) => e.id == state.selectedId)
        .firstOrNull;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _NameDialog(
        initial: rename ? category?.name ?? '' : '',
        title:
            (rename
                    ? 'liturgy.parity.renameRotation'
                    : 'liturgy.parity.newRotation')
                .tr(),
      ),
    );
    if (name != null && !bloc.isClosed)
      bloc.add(ScheduledCategorySaved(name, id: rename ? category?.id : null));
  }

  Future<bool> _confirm(String name) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('liturgy.actions.delete'.tr()),
          content: Text(name),
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
      ) ??
      false;
  Future<void> _entry(ScheduledState state, {ScheduledItem? existing}) async {
    final bloc = context.read<ScheduledBloc>();
    if (state.categories.isEmpty) {
      final next = bloc.stream.firstWhere((s) => s.categories.isNotEmpty);
      bloc.add(const ScheduledCategorySaved('Provai e Vede'));
      state = await next;
    }
    if (!mounted) return;
    final result = await showDialog<ScheduledItem>(
      context: context,
      builder: (ctx) => _EntryDialog(state: state, existing: existing),
    );
    if (result != null && !bloc.isClosed) bloc.add(ScheduledEntrySaved(result));
  }

  Future<void> _importXml() async {
    final bloc = context.read<ScheduledBloc>();
    try {
      final cats = await FilePicker.pickFile(type: FileType.any);
      if (cats == null) return;
      final categoryRows = DataPacketParser.parse(
        decodeJaFile(await cats.readAsBytes()),
      );
      final entries = await FilePicker.pickFile(type: FileType.any);
      final itemRows = entries == null
          ? <Map<String, String>>[]
          : DataPacketParser.parse(decodeJaFile(await entries.readAsBytes()));
      if (!bloc.isClosed)
        bloc.add(ScheduledXmlImported(categoryRows, itemRows));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('liturgy.scheduled.invalidXml'.tr())),
        );
    }
  }

  Future<void> _duplicate(ScheduledState state) async {
    if (state.selectedId == null) return;
    final bloc = context.read<ScheduledBloc>();
    final weeks = await showDialog<String>(
      context: context,
      builder: (ctx) => _NameDialog(
        initial: '13',
        title: 'liturgy.parity.duplicateWeeks'.tr(),
        numeric: true,
      ),
    );
    final count = int.tryParse(weeks ?? '');
    if (count == null || count <= 0 || bloc.isClosed) return;
    bloc.add(
      ScheduledQuarterDuplicated(
        state.selectedId!,
        from: DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        ),
        weeks: count,
      ),
    );
  }

  Widget _entries(ScheduledState state, List<ScheduledItem> items) => ListView(
    children: [
      for (final entry in items)
        Card(
          key: ValueKey(entry.id),
          child: ListTile(
            title: Text(entry.name),
            subtitle: Text(
              '${DateFormat('dd/MM/yyyy').format(entry.date)} · ${state.categories.where((e) => e.id == entry.categoryId).firstOrNull?.name ?? '—'}',
            ),
            onTap: () => _entry(state, existing: entry),
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'edit') {
                  _entry(state, existing: entry);
                } else if (await _confirm(entry.name) && mounted) {
                  context.read<ScheduledBloc>().add(
                    ScheduledEntryDeleted(entry.id),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('liturgy.actions.edit'.tr()),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('liturgy.actions.delete'.tr()),
                ),
              ],
            ),
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: Text('liturgy.scheduled.title'.tr()),
        actions: [
          IconButton(
            tooltip: 'liturgy.scheduled.import'.tr(),
            onPressed: _importXml,
            icon: const Icon(TablerIcons.fileImport),
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'liturgy.parity.rotations'.tr()),
            Tab(text: 'liturgy.parity.pasteQuarter'.tr()),
            Tab(text: 'liturgy.parity.calendar'.tr()),
            const Tab(text: 'Provai / Probad'),
          ],
        ),
      ),
      body: BlocBuilder<ScheduledBloc, ScheduledState>(
        builder: (context, state) => Column(
          children: [
            if (state.report != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'liturgy.parity.pasteReport'.tr(
                    namedArgs: {
                      'created': '${state.report!.created}',
                      'errors': '${state.report!.errors.length}',
                      'unmapped': '${state.report!.unmappedSlots.length}',
                    },
                  ),
                ),
              ),
            if (state.error) Text('liturgy.parity.saveFailed'.tr()),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: state.selectedId,
                                hint: Text('liturgy.parity.rotations'.tr()),
                                items: [
                                  for (final category in state.categories)
                                    DropdownMenuItem(
                                      value: category.id,
                                      child: Text(
                                        category.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (id) {
                                  if (id != null)
                                    context.read<ScheduledBloc>().add(
                                      ScheduledRotationSelected(id),
                                    );
                                },
                              ),
                            ),
                            IconButton(
                              key: const Key('scheduled-new-rotation'),
                              tooltip: 'liturgy.parity.newRotation'.tr(),
                              onPressed: () => _category(state),
                              icon: const Icon(TablerIcons.plus),
                            ),
                            if (state.selectedId != null) ...[
                              IconButton(
                                tooltip: 'liturgy.parity.renameRotation'.tr(),
                                onPressed: () => _category(state, rename: true),
                                icon: const Icon(TablerIcons.pencil),
                              ),
                              IconButton(
                                tooltip: 'liturgy.actions.delete'.tr(),
                                onPressed: () async {
                                  final bloc = context.read<ScheduledBloc>();
                                  if (await _confirm(
                                        state.categories
                                            .firstWhere(
                                              (e) => e.id == state.selectedId,
                                            )
                                            .name,
                                      ) &&
                                      !bloc.isClosed)
                                    bloc.add(
                                      ScheduledCategoryDeleted(
                                        state.selectedId!,
                                      ),
                                    );
                                },
                                icon: const Icon(TablerIcons.trash),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _entry(state),
                            icon: const Icon(TablerIcons.plus),
                            label: Text('liturgy.parity.newScheduled'.tr()),
                          ),
                          OutlinedButton.icon(
                            onPressed: state.selectedId == null
                                ? null
                                : () => _duplicate(state),
                            icon: const Icon(TablerIcons.copy),
                            label: Text('liturgy.parity.duplicateQuarter'.tr()),
                          ),
                        ],
                      ),
                      Expanded(
                        child: _entries(
                          state,
                          state.items
                              .where((e) => e.categoryId == state.selectedId)
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('liturgy.parity.pasteHint'.tr()),
                        Expanded(
                          child: TextField(
                            key: const Key('scheduled-quarter-text'),
                            controller: _paste,
                            onChanged: (_) => setState(() {}),
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                          ),
                        ),
                        if (_slots.isNotEmpty)
                          SizedBox(
                            height: 140,
                            child: ListView(
                              children: [
                                for (final slot in _slots)
                                  DropdownButtonFormField<String>(
                                    key: ValueKey(slot),
                                    initialValue: _mapping[slot],
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: slot,
                                    ),
                                    hint: Text(
                                      'liturgy.parity.slotMapping'.tr(),
                                    ),
                                    items: [
                                      for (final category in state.categories)
                                        DropdownMenuItem(
                                          value: category.id,
                                          child: Text(category.name),
                                        ),
                                    ],
                                    onChanged: (id) {
                                      if (id != null)
                                        setState(() => _mapping[slot] = id);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        CheckboxListTile(
                          title: Text('liturgy.parity.autoCreate'.tr()),
                          value: _autoCreate,
                          onChanged: (value) =>
                              setState(() => _autoCreate = value ?? false),
                        ),
                        FilledButton(
                          onPressed: () => context.read<ScheduledBloc>().add(
                            ScheduledQuarterPasted(
                              _paste.text,
                              year: DateTime.now().year,
                              mapping: Map.of(_mapping),
                              autoCreate: _autoCreate,
                            ),
                          ),
                          child: Text('liturgy.parity.applyQuarter'.tr()),
                        ),
                      ],
                    ),
                  ),
                  _entries(state, state.items),
                  ProvaiPanel(state: state),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.initial,
    required this.title,
    this.numeric = false,
  });
  final String initial;
  final String title;
  final bool numeric;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: widget.numeric ? TextInputType.number : TextInputType.text,
      onSubmitted: (v) {
        if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('common.cancel'.tr()),
      ),
      FilledButton(
        onPressed: () {
          if (_controller.text.trim().isNotEmpty)
            Navigator.pop(context, _controller.text.trim());
        },
        child: Text('liturgy.actions.save'.tr()),
      ),
    ],
  );
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({required this.state, this.existing});
  final ScheduledState state;
  final ScheduledItem? existing;
  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late String _categoryId =
      widget.existing?.categoryId ??
      widget.state.selectedId ??
      widget.state.categories.first.id;
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  LiturgyItem? _content;
  @override
  void initState() {
    super.initState();
    final entry = widget.existing;
    if (entry != null)
      _content = ScheduledResolver.resolve(
        LiturgyItem(
          id: entry.id,
          type: LiturgyItemType.scheduled,
          name: entry.name,
          scheduledRotationId: entry.categoryId,
        ),
        entry.date,
        widget.state.categories,
        [entry],
      );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _choose() => showLiturgyItemDialog(
    context,
    existing: _content,
    allowedTypes: const {
      LiturgyItemType.music,
      LiturgyItemType.annotation,
      LiturgyItemType.verse,
      LiturgyItemType.audio,
      LiturgyItemType.video,
      LiturgyItemType.images,
      LiturgyItemType.pdf,
      LiturgyItemType.presentation,
      LiturgyItemType.otherFiles,
      LiturgyItemType.onlineVideo,
    },
    onSubmit: (item) => setState(() {
      _content = item;
      if (_name.text.isEmpty) _name.text = item.name;
    }),
  );
  void _save() {
    final content = _content;
    if (content == null || _name.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      ScheduledItem(
        id: widget.existing?.id ?? 'sch-${ScheduledRepository.newId()}',
        categoryId: _categoryId,
        date: DateTime(_date.year, _date.month, _date.day),
        name: _name.text.trim(),
        notes: widget.existing?.notes ?? '',
        filePath: content.filePath ?? '',
        content: ScheduledResolver.toContent(content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('liturgy.parity.newScheduled'.tr()),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            isExpanded: true,
            items: [
              for (final category in widget.state.categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: (id) {
              if (id != null) setState(() => _categoryId = id);
            },
          ),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: 'liturgy.dialog.momentName'.tr(),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null && mounted) setState(() => _date = date);
            },
            icon: const Icon(TablerIcons.calendar),
            label: Text(DateFormat('dd/MM/yyyy').format(_date)),
          ),
          OutlinedButton.icon(
            onPressed: _choose,
            icon: const Icon(TablerIcons.edit),
            label: Text(_content?.name ?? 'liturgy.parity.chooseContent'.tr()),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('common.cancel'.tr()),
      ),
      FilledButton(
        onPressed: _content == null ? null : _save,
        child: Text('liturgy.actions.save'.tr()),
      ),
    ],
  );
}
