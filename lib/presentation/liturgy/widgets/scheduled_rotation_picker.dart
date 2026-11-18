import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/scheduled/scheduled_page.dart';

class ScheduledRotationPicker extends StatefulWidget {
  const ScheduledRotationPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String? value;
  final ValueChanged<String?> onChanged;
  @override
  State<ScheduledRotationPicker> createState() =>
      _ScheduledRotationPickerState();
}

class _ScheduledRotationPickerState extends State<ScheduledRotationPicker> {
  late Future<List<ScheduledCategory>> _categories;
  Future<List<ScheduledCategory>> _load() async => ScheduledRepository(
    await SharedPreferences.getInstance(),
  ).loadCategories();
  @override
  void initState() {
    super.initState();
    _categories = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ScheduledCategory>>(
    future: _categories,
    builder: (context, snapshot) {
      final categories = snapshot.data ?? const <ScheduledCategory>[];
      final selected = categories.any((e) => e.id == widget.value)
          ? widget.value
          : null;
      return Column(
        children: [
          DropdownButtonFormField<String>(
            key: const Key('liturgy-scheduled-rotation'),
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'liturgy.parity.rotation'.tr(),
            ),
            items: [
              for (final category in categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: widget.onChanged,
          ),
          TextButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ScheduledPage()),
              );
              if (mounted)
                setState(() {
                  _categories = _load();
                });
            },
            icon: const Icon(TablerIcons.calendarTime),
            label: Text('liturgy.parity.manageScheduled'.tr()),
          ),
        ],
      );
    },
  );
}
