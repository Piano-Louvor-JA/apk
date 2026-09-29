/// Acentos de cor selecionáveis pelo usuário.
///
/// Fonte: pianolouvorja/app/src/design-system/themes/accents.ts
/// Paleta atual — tons mais suaves e convencionais.
library;

import 'package:flutter/material.dart';

/// Representa um acento de cor.
class AccentColor {
  final String id;
  final String label;
  final Color primary;
  final Color soft;

  const AccentColor({
    required this.id,
    required this.label,
    required this.primary,
    required this.soft,
  });
}

/// Todos os acentos disponíveis.
abstract final class AppAccents {
  static const AccentColor defaultAccent = orange;

  static const AccentColor azure = AccentColor(
    id: 'azure',
    label: 'Azul',
    primary: Color(0xFF5B9BD5),
    soft: Color(0xFFB4D4F0),
  );

  static const AccentColor sky = AccentColor(
    id: 'sky',
    label: 'Céu',
    primary: Color(0xFF5BA4C9),
    soft: Color(0xFFB5D8E8),
  );

  static const AccentColor teal = AccentColor(
    id: 'teal',
    label: 'Verde-água',
    primary: Color(0xFF4DB6AC),
    soft: Color(0xFFB2DFDB),
  );

  static const AccentColor emerald = AccentColor(
    id: 'emerald',
    label: 'Verde',
    primary: Color(0xFF6BAA7A),
    soft: Color(0xFFB8D9C0),
  );

  static const AccentColor apricot = AccentColor(
    id: 'apricot',
    label: 'Âmbar',
    primary: Color(0xFFE0A84A),
    soft: Color(0xFFF0D9A8),
  );

  static const AccentColor orange = AccentColor(
    id: 'orange',
    label: 'Laranja',
    primary: Color(0xFFE0895A),
    soft: Color(0xFFF0C4A8),
  );

  static const AccentColor coral = AccentColor(
    id: 'coral',
    label: 'Coral',
    primary: Color(0xFFD4847A),
    soft: Color(0xFFF0C0B8),
  );

  static const AccentColor rose = AccentColor(
    id: 'rose',
    label: 'Rosa',
    primary: Color(0xFFC97B8F),
    soft: Color(0xFFE8C4CE),
  );

  static const AccentColor violet = AccentColor(
    id: 'violet',
    label: 'Violeta',
    primary: Color(0xFF8B7BB8),
    soft: Color(0xFFCDC4E0),
  );

  static const AccentColor slate = AccentColor(
    id: 'slate',
    label: 'Ardósia',
    primary: Color(0xFF7A8FA3),
    soft: Color(0xFFC5D0DA),
  );

  /// Lista de todos os acentos na ordem exata do Electron.
  static const List<AccentColor> all = [
    azure,
    sky,
    teal,
    emerald,
    apricot,
    orange,
    coral,
    rose,
    violet,
    slate,
  ];

  /// Busca acento por ID.
  static AccentColor byId(String id) {
    return all.firstWhere((a) => a.id == id, orElse: () => defaultAccent);
  }
}
