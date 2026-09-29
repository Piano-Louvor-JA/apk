library;

import 'package:flutter/foundation.dart';

/// Definicao simples de versao para pickDefaultVersionId.
@immutable
class BibleVersionDef {
  final int id;
  final String abbreviation;
  final String name;

  const BibleVersionDef({
    required this.id,
    required this.abbreviation,
    required this.name,
  });
}

/// Utilidades de formatacao de escritura sagrada.
abstract final class ScriptureFormat {
  /// Agrupa numeros em intervalos legiveis (ex: [1,2,3,5] -> "1-3,5").
  static String formatVerseIntervals(List<int> verses) {
    if (verses.isEmpty) return '';

    final sorted = verses.toSet().toList()..sort();
    final parts = <String>[];
    var start = sorted.first;
    var end = sorted.first;

    for (var i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      if (current == end + 1) {
        end = current;
        continue;
      }
      parts.add(start == end ? '$start' : '$start-$end');
      start = current;
      end = current;
    }

    parts.add(start == end ? '$start' : '$start-$end');
    return parts.join(',');
  }

  /// Monta a referencia biblica (ex: "Joao 3:16-17 (ARA)").
  static String formatReference({
    required String bookName,
    required int chapter,
    List<int> verses = const [],
    String? versionAbbreviation,
  }) {
    if (bookName.isEmpty || chapter == 0) return '';

    final versePart = verses.isNotEmpty
        ? ':${formatVerseIntervals(verses)}'
        : '';
    final versionPart =
        versionAbbreviation != null && versionAbbreviation.isNotEmpty
        ? ' ($versionAbbreviation)'
        : '';

    return '$bookName $chapter$versePart$versionPart';
  }

  /// Interpreta busca por numeros/intervalos ("1", "1-3", "1,3-5").
  static List<int> parseVerseQuery(String query, Map<String, String> verses) {
    final selected = <int>{};
    final parts = query.split(',');

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.contains('-')) {
        final halves = trimmed.split('-');
        final start = int.tryParse(halves[0].trim());
        final end = int.tryParse(halves[1].trim());
        if (start == null || end == null) continue;

        final from = start < end ? start : end;
        final to = start < end ? end : start;
        for (var i = from; i <= to; i++) {
          if (verses[i.toString()] != null) selected.add(i);
        }
        continue;
      }

      final num = int.tryParse(trimmed);
      if (num != null && verses[num.toString()] != null) {
        selected.add(num);
      }
    }

    return selected.toList()..sort();
  }

  /// Concatena o texto dos versiculos selecionados.
  static String buildText(Map<String, String> verses, List<int> selected) {
    return selected
        .map((verseNum) => verses[verseNum.toString()])
        .whereType<String>()
        .where((text) => text.isNotEmpty)
        .join(' ');
  }

  /// Chave do endpoint de capitulo da API.
  static String chapterRecordKey(int versionId, int bookId, int chapter) {
    return 'bible_${versionId}_${bookId}_$chapter';
  }

  /// Escolhe a versao padrao: prefere ARA, senao a primeira.
  static int? pickDefaultVersionId(
    List<BibleVersionDef> versions,
    int? savedId,
  ) {
    if (versions.isEmpty) return null;

    if (savedId != null && versions.any((v) => v.id == savedId)) {
      return savedId;
    }

    final ara = versions.where((v) {
      final abbr = v.abbreviation.toUpperCase();
      final name = v.name.toUpperCase();
      return abbr == 'ARA' || name == 'ARA';
    }).firstOrNull;

    return ara?.id ?? versions.first.id;
  }
}
