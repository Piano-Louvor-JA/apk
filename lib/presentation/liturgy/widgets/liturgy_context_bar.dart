import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';

/// As avulsas e os dias usam o mesmo editor e as mesmas regras de domínio.
class LiturgyContextBar extends StatelessWidget {
  const LiturgyContextBar({super.key, required this.state});
  final LiturgyLoaded state;
  static Future<void> createCustom(BuildContext context) async {
    final state = context.read<LiturgyBloc>().state;
    if (state is LiturgyLoaded)
      await LiturgyContextBar(state: state)._name(context);
  }

  Future<void> _name(BuildContext context, {bool rename = false}) async {
    final bloc = context.read<LiturgyBloc>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CustomNameDialog(
        initial: rename ? state.customName ?? '' : '',
        rename: rename,
      ),
    );
    if (name != null && !bloc.isClosed)
      bloc.add(
        rename
            ? LiturgyCustomRenamed(state.customId!, name)
            : LiturgyCustomCreated(name),
      );
  }

  Future<void> _delete(BuildContext context) async {
    final bloc = context.read<LiturgyBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('liturgy.parity.deleteCustom'.tr()),
        content: Text(state.customName ?? ''),
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
      bloc.add(LiturgyCustomDeleted(state.customId!));
  }

  Future<void> _clone(BuildContext context) async {
    final bloc = context.read<LiturgyBloc>();
    final sources = <String, String>{
      for (final day in liturgyDayTabOrder)
        if (day.name != state.contextKey &&
            bloc.repository.loadItems(day).isNotEmpty)
          day.name: 'liturgy.days.${day.name}'.tr(),
      for (final custom in bloc.repository.loadCustomLiturgies())
        if ('custom:${custom.id}' != state.contextKey &&
            custom.items.isNotEmpty)
          'custom:${custom.id}': custom.name,
    };
    final key = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text('liturgy.parity.cloneFrom'.tr())),
            for (final source in sources.entries)
              ListTile(
                title: Text(source.value),
                trailing: const Icon(TablerIcons.copy),
                onTap: () => Navigator.pop(ctx, source.key),
              ),
          ],
        ),
      ),
    );
    if (key != null && !bloc.isClosed) bloc.add(LiturgyCloneSource(key));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: DropdownButton<String>(
            key: const Key('liturgy-custom-select'),
            value: state.customId,
            isExpanded: true,
            hint: Text('liturgy.avulsa.title'.tr()),
            items: [
              for (final custom in state.customLiturgies)
                DropdownMenuItem(
                  value: custom.id,
                  child: Text(custom.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) {
              if (id != null)
                context.read<LiturgyBloc>().add(LiturgyCustomSelected(id));
            },
          ),
        ),
        IconButton(
          key: const Key('liturgy-custom-create'),
          tooltip: 'liturgy.parity.newCustom'.tr(),
          icon: const Icon(TablerIcons.plus),
          onPressed: () => _name(context),
        ),
        if (state.customId != null) ...[
          IconButton(
            tooltip: 'liturgy.parity.renameCustom'.tr(),
            icon: const Icon(TablerIcons.pencil),
            onPressed: () => _name(context, rename: true),
          ),
          IconButton(
            tooltip: 'liturgy.parity.deleteCustom'.tr(),
            icon: const Icon(TablerIcons.trash),
            onPressed: () => _delete(context),
          ),
        ],
        if (state.items.isEmpty)
          IconButton(
            key: const Key('liturgy-clone-source'),
            tooltip: 'liturgy.parity.cloneFrom'.tr(),
            icon: const Icon(TablerIcons.copy),
            onPressed: () => _clone(context),
          ),
      ],
    ),
  );
}

class _CustomNameDialog extends StatefulWidget {
  const _CustomNameDialog({required this.initial, required this.rename});
  final String initial;
  final bool rename;
  @override
  State<_CustomNameDialog> createState() => _CustomNameDialogState();
}

class _CustomNameDialogState extends State<_CustomNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      (widget.rename
              ? 'liturgy.parity.renameCustom'
              : 'liturgy.parity.newCustom')
          .tr(),
    ),
    content: TextField(
      key: const Key('liturgy-custom-name'),
      controller: _controller,
      autofocus: true,
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('common.cancel'.tr()),
      ),
      FilledButton(onPressed: _save, child: Text('liturgy.actions.save'.tr())),
    ],
  );
}
