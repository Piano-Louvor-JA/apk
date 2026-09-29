/// Perfis de animação.
///
/// Fonte: pianolouvorja/app/src/design-system/animations/page.ts
library;

import 'package:flutter/animation.dart';

/// Perfil de interação escolhido pelo usuário. Default: soft.
enum InteractionProfile {
  /// 280ms, easeOutBack.
  dynamic,

  /// 450ms, easeInOutCubic. (padrão)
  soft,

  /// 520ms, easeOutQuart.
  mist,
}

extension InteractionProfileX on InteractionProfile {
  Duration get duration {
    return switch (this) {
      InteractionProfile.dynamic => const Duration(milliseconds: 280),
      InteractionProfile.soft => const Duration(milliseconds: 450),
      InteractionProfile.mist => const Duration(milliseconds: 520),
    };
  }

  Curve get curve {
    return switch (this) {
      InteractionProfile.dynamic => Curves.easeOutBack,
      InteractionProfile.soft => Curves.easeInOutCubic,
      InteractionProfile.mist => Curves.easeOutQuart,
    };
  }
}

/// Tokens de animação do dock (macOS-style).
abstract final class DockAnimation {
  static const double hoverScale = 1.25;
  static const double hoverLift = -4;
  static const Duration duration = Duration(milliseconds: 300);
}
