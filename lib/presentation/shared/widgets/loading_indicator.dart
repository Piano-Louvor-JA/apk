library;

import 'package:flutter/material.dart';

/// Indicador de carregamento padronizado do LouvorJA.
/// Usa a cor primary do tema ativo e pode exibir uma mensagem opcional.
class LoadingIndicator extends StatelessWidget {
  final String? label;
  final double size;

  const LoadingIndicator({super.key, this.label, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: theme.colorScheme.primary,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(
              label!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
