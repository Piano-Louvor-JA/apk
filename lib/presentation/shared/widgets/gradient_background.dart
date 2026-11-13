/// GradientBackground — fundo das telas, na cor base do tema.
///
/// Fonte: pianolouvorja/app/src/design-system/components/backgrounds/GradientBackground.vue
/// (mesma cor base `--ds-color-background`). Cor solida de proposito: um degrade
/// tao sutil vira faixas visiveis em tela de 8 bits, e o desktop so evita isso
/// com uma camada de dither.
library;

import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: child,
    );
  }
}
