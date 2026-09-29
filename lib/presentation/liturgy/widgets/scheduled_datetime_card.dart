// coverage:ignore-file
// showDatePicker/showTimePicker sao platform dialogs; context.locale precisa EasyLocalization.
// Widget nao testavel em unit test sem platform channels.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Campo reutilizável para definir data e horário de um item agendado.
class ScheduledDateTimeCard extends StatelessWidget {
  final ValueNotifier<DateTime?> value;
  final VoidCallback onChanged;

  const ScheduledDateTimeCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final initial = value.value ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    value.value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<DateTime?>(
      valueListenable: value,
      builder: (context, scheduledAt, _) {
        final label = scheduledAt == null
            ? 'liturgy.fields.selectSchedule'.tr()
            : '${DateFormat.yMMMd(context.locale.toString()).format(scheduledAt)} · ${TimeOfDay.fromDateTime(scheduledAt).format(context)}';
        return Card(
          color: theme.colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    TablerIcons.calendarTime,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'liturgy.fields.scheduledFor'.tr(),
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(label, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Icon(
                    TablerIcons.chevronRight,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
