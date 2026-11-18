import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

/// Dias da liturgia do desktop: os que têm liturgia ficam em destaque.
/// Abaixo da Avulsa, cada liturgia avulsa aparece pelo nome.
class RemoteLiturgyDays extends StatelessWidget {
  const RemoteLiturgyDays({
    super.key,
    required this.days,
    required this.onSelect,
    this.customs = const [],
    this.onSelectCustom,
  });

  final List<RemoteLiturgyDay> days;
  final ValueChanged<RemoteLiturgyDay> onSelect;
  final List<RemoteLiturgyCustom> customs;
  final ValueChanged<RemoteLiturgyCustom>? onSelectCustom;

  @override
  Widget build(BuildContext context) {
    final week = days.where((d) => d.key != 'custom').toList();
    final custom = days.where((d) => d.key == 'custom');
    return LayoutBuilder(
      builder: (context, constraints) {
        double width(int columns) =>
            (constraints.maxWidth - AppSpacing.s2 * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            for (final day in week)
              SizedBox(
                width: width(4),
                child: _LiturgyTile(
                  id: day.key,
                  prefix: 'remote-liturgy-day',
                  label: 'liturgy.days.${day.key}'.tr(),
                  count: day.count,
                  selected: day.selected,
                  onTap: () => onSelect(day),
                ),
              ),
            for (final day in custom)
              SizedBox(
                width: constraints.maxWidth,
                child: _LiturgyTile(
                  id: day.key,
                  prefix: 'remote-liturgy-day',
                  label: 'remote.liturgyCustomDay'.tr(),
                  count: day.count,
                  selected: day.selected && customs.isEmpty,
                  // Com as avulsas listadas abaixo, o bloco é só o título.
                  enabled: customs.isEmpty,
                  onTap: () => onSelect(day),
                ),
              ),
            for (final item in customs)
              SizedBox(
                width: width(2),
                child: _LiturgyTile(
                  id: '${item.index}',
                  prefix: 'remote-liturgy-custom',
                  label: item.name,
                  count: item.count,
                  selected: item.selected,
                  onTap: () => onSelectCustom?.call(item),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LiturgyTile extends StatelessWidget {
  const _LiturgyTile({
    required this.id,
    required this.prefix,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String id;
  final String prefix;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = count > 0;
    final color = filled ? scheme.primary : scheme.onSurfaceVariant;
    return Material(
      key: filled ? Key('$prefix-filled-$id') : null,
      color: filled
          ? scheme.primary.withValues(alpha: 0.15)
          : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? scheme.primary
              : filled
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        key: Key('$prefix-$id'),
        borderRadius: BorderRadius.circular(12),
        // Sem liturgia não há o que abrir: o toque não faz nada.
        onTap: filled && enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s3,
            horizontal: AppSpacing.s2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dia aberto no desktop: só a borda mais forte, sem ícone.
              Text(
                label,
                key: selected ? Key('$prefix-open-$id') : null,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                filled
                    ? 'remote.liturgyDayItems'.tr(
                        namedArgs: {'count': '$count'},
                      )
                    : '—',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
