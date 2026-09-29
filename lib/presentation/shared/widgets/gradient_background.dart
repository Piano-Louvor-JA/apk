/// GradientBackground — fundo com gradiente sutil.
///
/// Fonte: pianolouvorja/app/src/design-system/components/backgrounds/GradientBackground.vue
library;

import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;

  const GradientBackground({super.key, required this.child, this.colors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gradientColors =
        colors ??
        (isDark
            ? [
                const Color(0xFF131313),
                const Color(0xFF1A1A1A),
                const Color(0xFF0D0D0D),
              ]
            : [
                const Color(0xFFF8F9FF),
                const Color(0xFFFFFFFF),
                const Color(0xFFEFF2F9),
              ]);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
      ),
      child: child,
    );
  }
}
