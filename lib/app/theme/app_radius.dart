/// Raios de borda — assimetria de marca.
///
/// Fonte: pianolouvorja/app/src/design-system/tokens/radius.ts
///
/// Identidade visual: TL (top-left) + BR (bottom-right) arredondados.
/// TR + BL retos (0). NUNCA usar BorderRadius.circular() simétrico.
library;

import 'package:flutter/material.dart';

abstract final class AppRadius {
  /// Inputs, botões, containers pequenos.
  static const BorderRadius sm = BorderRadius.only(
    topLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  /// Alias de sm (mesmo valor no Electron).
  static const BorderRadius eight = sm;

  /// Containers médios.
  static const BorderRadius md = BorderRadius.only(
    topLeft: Radius.circular(12),
    bottomRight: Radius.circular(12),
  );

  /// Cards / containers grandes.
  static const BorderRadius lg = BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  /// Containers extra grandes.
  static const BorderRadius xl = BorderRadius.only(
    topLeft: Radius.circular(24),
    bottomRight: Radius.circular(24),
  );

  /// Circular completo (avatars, chips, FAB).
  static final BorderRadius full = BorderRadius.circular(9999);
}
