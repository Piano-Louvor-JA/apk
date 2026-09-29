library;

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Item de lista de hino para o catálogo.
///
/// Preparado na Fase 1; a entidade Hymn e dados reais chegam na Fase 2.
class HymnListTile extends StatelessWidget {
  final String number;
  final String title;
  final String? subtitle;
  final bool isDownloaded;
  final Widget? trailing;
  final VoidCallback? onTap;

  const HymnListTile({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    this.isDownloaded = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Text(
          number,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ??
          (isDownloaded
              ? Icon(
                  TablerIcons.download,
                  size: 18,
                  color: theme.colorScheme.primary,
                )
              : Icon(
                  TablerIcons.chevronRight,
                  color: theme.colorScheme.onSurfaceVariant,
                )),
    );
  }
}
