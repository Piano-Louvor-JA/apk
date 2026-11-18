import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/app/theme/app_radius.dart';

/// Fundo de uma seção das configurações (Aparência, Geral, Sincronização…),
/// para cada grupo de cards ficar separado do seguinte.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Material (e não DecoratedBox) para o toque dos ListTiles aparecer.
    return Material(
      color: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.05),
        scheme.surfaceContainerLowest,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xl,
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}
