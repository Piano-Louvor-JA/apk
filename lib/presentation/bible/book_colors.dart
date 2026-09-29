library;

import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';

/// Cores do tile de livro biblico.
///
/// Paridade com a versao web: quando a API fornece `book.color`
/// (hex canonico, ex. #ff6766 evangelhos), ela e usada em AMBOS os
/// temas (light e dark) — o web pinta direto pela cor da API.
/// O fallback por [BibleBookTone] so entra quando a API nao manda cor.
class BookColors {
  const BookColors._();

  static Color parseHex(String value) {
    final hex = value.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  static Color tone(BibleBook book, ThemeData theme, {bool selected = false}) {
    final isLight = theme.brightness == Brightness.light;
    if (selected) {
      return isLight ? const Color(0xFF78350F) : const Color(0xFFFEF08A);
    }
    if (book.color != null) return parseHex(book.color!);
    switch (book.tone) {
      case BibleBookTone.law:
        return isLight ? const Color(0xFF1D4ED8) : const Color(0xFF93C5FD);
      case BibleBookTone.history:
        return isLight ? const Color(0xFF15803D) : const Color(0xFF86EFAC);
      case BibleBookTone.prophets:
        return isLight ? const Color(0xFFA16207) : const Color(0xFFFDE68A);
      case BibleBookTone.gospels:
        return isLight ? const Color(0xFF7E22CE) : const Color(0xFFD8B4FE);
      case BibleBookTone.letters:
      case BibleBookTone.neutral:
        return theme.colorScheme.onSurface;
    }
  }

  static Color background(
    BibleBook book,
    ThemeData theme, {
    bool selected = false,
  }) {
    final isLight = theme.brightness == Brightness.light;
    if (selected) {
      return const Color(0xFFCA8A04).withValues(alpha: isLight ? 0.25 : 0.4);
    }
    if (book.color != null) {
      return parseHex(book.color!).withValues(alpha: isLight ? 0.16 : 0.22);
    }
    switch (book.tone) {
      case BibleBookTone.law:
        return const Color(0xFF3B82F6).withValues(alpha: isLight ? 0.15 : 0.18);
      case BibleBookTone.history:
        return const Color(0xFF22C55E).withValues(alpha: isLight ? 0.15 : 0.12);
      case BibleBookTone.prophets:
        return const Color(0xFFCA8A04).withValues(alpha: isLight ? 0.18 : 0.14);
      case BibleBookTone.gospels:
        return const Color(0xFFA855F7).withValues(alpha: isLight ? 0.15 : 0.12);
      case BibleBookTone.letters:
      case BibleBookTone.neutral:
        return isLight
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerHighest;
    }
  }
}
