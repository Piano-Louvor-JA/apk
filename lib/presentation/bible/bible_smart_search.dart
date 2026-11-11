library;

import '../../domain/entities/bible_book.dart';
import 'bible_reference_parser.dart';

/// O que uma sugestão da busca da Bíblia faz ao ser tocada.
enum BibleSuggestionKind {
  /// Livro (sem capítulo ainda): completa o campo e mostra os capítulos.
  book,

  /// Passagem pronta: abre livro + capítulo (+ versículos).
  reference,

  /// Busca a palavra/frase no texto dos versículos.
  text,
}

class BibleSuggestion {
  final BibleSuggestionKind kind;
  final BibleBook? book;
  final int? chapter;
  final List<int> verses;

  /// Texto buscado (kind == text).
  final String query;

  const BibleSuggestion._(
    this.kind, {
    this.book,
    this.chapter,
    this.verses = const [],
    this.query = '',
  });

  /// "João", "João 3", "João 3:16-18" ou o texto buscado.
  String get label {
    switch (kind) {
      case BibleSuggestionKind.book:
        return book!.name;
      case BibleSuggestionKind.reference:
        final v = BibleReferenceParser.formatVerses(verses);
        return v.isEmpty
            ? '${book!.name} $chapter'
            : '${book!.name} $chapter:$v';
      case BibleSuggestionKind.text:
        return query;
    }
  }
}

/// Busca "que entende" o que a pessoa digita: livro, capítulo, versículos
/// ou texto livre — em qualquer jeito comum de escrever:
/// `jo 3:16`, `jo 3.16`, `jo 3,16`, `jo 3 16`, `jo3:16`, `1 co 13:4-7`,
/// `i coríntios 13`, `primeira coríntios 13`, `salmo 23`, `cantares 2`.
/// Devolve sugestões ordenadas (a primeira é a ação do Enter).
class BibleSmartSearch {
  static const _maxBooks = 6;
  static const _maxReferences = 3;
  static const _minTextLength = 3;

  /// Apelidos comuns que não saem do nome/abreviação do catálogo.
  /// Chave = abreviação dobrada; valores já dobrados e sem espaço.
  static const _aliases = <String, List<String>>{
    'sl': ['salmo', 'salmos'],
    'cn': [
      'ct',
      'cantico',
      'canticos',
      'canticodoscanticos',
      'cantaresdoscantares',
    ],
  };

  static final _reference = RegExp(
    r'^([1-3]?\s*[a-z][a-z ]*?)\s*' // livro
    r'(?:(\d+)' // capítulo
    r'(?:\s*[:.,\s]\s*(\d[\d,\-\s]*)?)?)?$', // versículos (opcional)
  );

  static List<BibleSuggestion> suggest(String input, List<BibleBook> books) {
    final raw = _basic(input);
    if (raw.isEmpty) return const [];
    final folded = fold(raw);
    final m = _reference.firstMatch(folded);
    final hasLetters = RegExp('[a-z]').hasMatch(folded);
    if (m == null) {
      return hasLetters && folded.length >= _minTextLength
          ? [BibleSuggestion._(BibleSuggestionKind.text, query: raw)]
          : const [];
    }

    final bookPart = m.group(1)!.trim();
    final rawBook = _rawBookKey(raw, bookPart.length);
    final ranked = _rank(rawBook, bookPart.replaceAll(' ', ''), books);
    final chapterText = m.group(2);

    if (chapterText == null) {
      return [
        for (final b in ranked.take(_maxBooks))
          BibleSuggestion._(BibleSuggestionKind.book, book: b),
        if (folded.length >= _minTextLength)
          BibleSuggestion._(BibleSuggestionKind.text, query: raw),
      ];
    }

    final chapter = int.parse(chapterText);
    final verses = _parseVerses(m.group(3) ?? '');
    final refs = [
      for (final b in ranked)
        if (chapter >= 1 && chapter <= b.chapters)
          BibleSuggestion._(
            BibleSuggestionKind.reference,
            book: b,
            chapter: chapter,
            verses: verses,
          ),
    ].take(_maxReferences).toList();
    if (refs.isNotEmpty) return refs;
    return [
      for (final b in ranked.take(_maxBooks))
        BibleSuggestion._(BibleSuggestionKind.book, book: b),
    ];
  }

  /// Minúsculas, sem acento, numeral por extenso/romano no início vira
  /// dígito ("i coríntios", "primeira coríntios" → "1 corintios").
  static String fold(String s) {
    var out = _stripAccents(_basic(s));
    out = out.replaceFirstMapped(
      RegExp(
        r'^(primeir[oa]|1[ºªoa]|iii|ii|i|segund[oa]|2[ºªoa]|terceir[oa]|3[ºªoa])\s+(?=[a-z])',
      ),
      (m) {
        final w = m.group(1)!;
        if (w == 'iii' || w.startsWith('terceir') || w.startsWith('3')) {
          return '3 ';
        }
        if (w == 'ii' || w.startsWith('segund') || w.startsWith('2')) {
          return '2 ';
        }
        return '1 ';
      },
    );
    return out;
  }

  /// Minúsculas, traços tipográficos como "-", espaços colapsados.
  static String _basic(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[‐-―−]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _stripAccents(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      b.write(i < 0 ? ch : to[i]);
    }
    return b.toString();
  }

  /// Parte do livro como foi digitada (com acento), sem espaços. Só serve
  /// para desempatar Jó/Jo; quando o numeral foi convertido, não vale.
  static String _rawBookKey(String raw, int foldedLength) {
    final folded = fold(raw);
    if (folded.length != raw.length) return '';
    return raw.substring(0, foldedLength).replaceAll(' ', '');
  }

  static List<BibleBook> _rank(
    String rawKey,
    String key,
    List<BibleBook> books,
  ) {
    if (key.isEmpty) return const [];
    final scored = <MapEntry<BibleBook, int>>[];
    for (final b in books) {
      final score = _score(b, rawKey, key);
      if (score > 0) scored.add(MapEntry(b, score));
    }
    scored.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      return byScore != 0
          ? byScore
          : a.key.bookNumber.compareTo(b.key.bookNumber);
    });
    return [for (final e in scored) e.key];
  }

  static int _score(BibleBook b, String rawKey, String key) {
    final abbr = fold(b.abbreviation).replaceAll(' ', '');
    final nameFolded = fold(b.name);
    final name = nameFolded.replaceAll(' ', '');
    final aliases = _aliases[abbr] ?? const <String>[];
    if (rawKey.isNotEmpty &&
        b.abbreviation.toLowerCase().replaceAll(' ', '') == rawKey) {
      return 100;
    }
    if (abbr == key) return 90;
    if (name == key || aliases.contains(key)) return 85;
    if (name.startsWith(key)) return 70;
    if (aliases.any((a) => a.startsWith(key))) return 60;
    if (abbr.startsWith(key)) return 50;
    // Palavra do meio do nome ("corintios", "salomao"), sem o numeral.
    final words = nameFolded
        .split(' ')
        .where((w) => !RegExp(r'^\d+$').hasMatch(w));
    if (key.length >= 3 && words.any((w) => w.startsWith(key))) return 30;
    return 0;
  }

  /// `16-18,20` → [16,17,18,20]. Tolera o que ainda está sendo digitado
  /// (`16-`, `16,`). Intervalo invertido é normalizado.
  static List<int> _parseVerses(String spec) {
    final out = <int>{};
    for (final part in spec.split(',')) {
      final p = part.trim().replaceAll(RegExp(r'[-\s]+$'), '');
      if (p.isEmpty) continue;
      final range = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(p);
      if (range != null) {
        final a = int.parse(range.group(1)!);
        final b = int.parse(range.group(2)!);
        final lo = a < b ? a : b;
        final hi = a < b ? b : a;
        for (var v = lo < 1 ? 1 : lo; v <= hi && v <= lo + 200; v++) {
          out.add(v);
        }
        continue;
      }
      final single = int.tryParse(p.replaceAll(' ', ''));
      if (single != null && single >= 1) out.add(single);
    }
    return out.toList()..sort();
  }
}
