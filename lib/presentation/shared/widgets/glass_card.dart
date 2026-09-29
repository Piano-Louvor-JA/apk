/// GlassCard — card com efeito de vidro (glass morphism).
///
/// Fonte: pianolouvorja/app/src/design-system/components/glass/GlassCard.vue
///
/// Usa BackdropFilter com sigma baseado na intensidade configurável.
/// A assimetria de borda (TL+BR) é aplicada via AppRadius.lg.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/theme/app_blur.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blurIntensity;
  final EdgeInsets? padding;
  final BorderRadius? radius;

  const GlassCard({
    super.key,
    required this.child,
    this.blurIntensity = AppBlur.defaultIntensity,
    this.padding,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sigma = AppBlur.blurSigma(blurIntensity);
    final fillAlpha = AppBlur.fillAlpha(blurIntensity);
    final borderRadius = radius ?? AppRadius.lg;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: fillAlpha),
            borderRadius: borderRadius,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
          child: child,
        ),
      ),
    );
  }
}
