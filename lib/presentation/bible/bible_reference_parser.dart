library;

/// Resultado do parse de uma referência bíblica digitada.
class BibleReference {
  /// Texto usado pra casar o livro (nome completo, abreviação ou prefixo).
  final String bookQuery;

  /// Capítulo (sempre presente num parse válido).
  final int chapter;

  /// Versículos selecionados, ordenados e sem duplicatas.
  /// Vazio = capítulo inteiro.
  final List<int> verses;

  const BibleReference({
    required this.bookQuery,
    required this.chapter,
    required this.verses,
  });
}

/// Parser de referências bíblicas no input de localização.
///
/// Formatos aceitos:
/// - `gn 1`           → capítulo inteiro
/// - `gn 1:1`         → verso único
/// - `gn 1:1-3`       → range (1,2,3)
/// - `gn 1:3,5`       → avulsos
/// - `gn 1:1,3-5`     → misto (1,3,4,5)
/// - `Gênesis 1:1-3`  → nome com acento (normalizado)
class BibleReferenceParser {
  static BibleReference? parse(String input) {
    final text = _normalize(input);
    if (text.isEmpty) return null;

    final m = RegExp(
      r'^([a-z]+)\s+(\d+)(?::\s*([\d,\-\s]+))?$',
    ).firstMatch(text);
    if (m == null) return null;

    final book = m.group(1)!;
    final chapter = int.parse(m.group(2)!);
    if (chapter < 1) return null;

    final versesSpec = m.group(3);
    final verses = versesSpec == null
        ? const <int>[]
        : _parseVerses(versesSpec);
    if (versesSpec != null && verses.isEmpty) return null;

    return BibleReference(bookQuery: book, chapter: chapter, verses: verses);
  }

  /// Minúsculas, sem acento, espaços extras colapsados.
  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// `1-3,5` → [1,2,3,5]; devolve vazio se nada válido.
  /// Formata seleção: [1,2,3] → `1-3`; [1,3,4,5] → `1,3-5`.
  static String formatVerses(Iterable<int> input) {
    final verses = input.where((v) => v > 0).toSet().toList()..sort();
    if (verses.isEmpty) return '';
    final parts = <String>[];
    var start = verses.first;
    var previous = start;
    for (final verse in verses.skip(1)) {
      if (verse == previous + 1) {
        previous = verse;
        continue;
      }
      parts.add(start == previous ? '$start' : '$start-$previous');
      start = previous = verse;
    }
    parts.add(start == previous ? '$start' : '$start-$previous');
    return parts.join(',');
  }

  static List<int> _parseVerses(String spec) {
    final out = <int>{};
    for (final part in spec.split(',')) {
      final p = part.trim();
      if (p.isEmpty) continue;
      final range = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(p);
      if (range != null) {
        final a = int.parse(range.group(1)!);
        final b = int.parse(range.group(2)!);
        final lo = a <= b ? a : b;
        final hi = a <= b ? b : a;
        if (lo < 1) return const [];
        for (var v = lo; v <= hi; v++) {
          out.add(v);
        }
        continue;
      }
      final single = int.tryParse(p);
      if (single == null || single < 1) return const [];
      out.add(single);
    }
    final list = out.toList()..sort();
    return list;
  }
}
