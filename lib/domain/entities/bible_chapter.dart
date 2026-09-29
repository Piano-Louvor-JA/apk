library;

import 'package:flutter/foundation.dart';

/// Entrada de versículo ordenada.
class BibleVerseEntry {
  final int number;
  final String text;

  const BibleVerseEntry({required this.number, required this.text});
}

/// Versículos de um capítulo: numero → texto.
@immutable
class BibleChapter {
  final Map<String, String> verses;

  const BibleChapter({this.verses = const {}});

  /// Entradas ordenadas por numero do versículo.
  List<BibleVerseEntry> get sortedVerseEntries {
    final entries =
        verses.entries
            .map((e) => MapEntry(int.tryParse(e.key) ?? 0, e.value))
            .where((e) => e.key > 0)
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((e) => BibleVerseEntry(number: e.key, text: e.value))
        .toList();
  }

  bool get isEmpty => verses.isEmpty;
  bool get isNotEmpty => verses.isNotEmpty;
}
