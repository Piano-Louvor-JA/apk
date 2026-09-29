library;

import '../../domain/entities/album_category.dart';
import '../../domain/entities/hymn.dart';

/// Referencia leve de um versiculo para busca global (sem acoplar a BibleChapter).
class BibleVerseRef {
  final int bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;

  const BibleVerseRef({
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  /// Referencia no formato "Joao 3:16".
  String get reference => '$bookName $chapter:$verse';
}

/// Item agregado de busca global: hino ou versiculo + score + snippet.
class GlobalSearchResult {
  final Object item; // Hymn | BibleVerseRef
  final int score;
  final String snippet;

  const GlobalSearchResult({
    required this.item,
    required this.score,
    required this.snippet,
  });

  /// Chave de agrupamento na UI ("hymns" | "bible").
  String get groupKey => item is Hymn ? 'hymns' : 'bible';
}

/// Servico de busca global (RF-08): hinos + biblia numa unica query.
///
/// Fuzzy score simples baseado em:
/// - match exato de string completa (peso maximo)
/// - prefixo do alvo (peso alto)
/// - substring (peso medio, ponderado pela posicao)
/// - normalizacao: lowercase + sem acentos.
class GlobalSearchService {
  final int maxResults;

  GlobalSearchService({this.maxResults = 20});

  static final _accentRegex = RegExp(r'[\u0300-\u036f]');

  /// Mapeamento direto de precompostos latinos (pt/es/en) para ASCII.
  static const _foldMap = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
    'ý': 'y',
    'ÿ': 'y',
  };

  /// Normaliza: lowercase + remove diacriticos (precompostos e combinantes).
  static String normalize(String input) {
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_foldMap[ch] ?? ch);
    }
    // Remove diacriticos combinantes remanescentes (casos raros NFD).
    return buffer.toString().replaceAll(_accentRegex, '').trim();
  }

  /// Pontua a similaridade entre [query] e [target] (0 = sem match).
  static int fuzzyScore(String query, String target) {
    final q = normalize(query);
    final t = normalize(target);
    if (q.isEmpty || t.isEmpty) return 0;

    if (t == q) return 1000;
    if (t.startsWith(q)) return 800 - (t.length - q.length);
    final idx = t.indexOf(q);
    if (idx >= 0) {
      // Quanto mais cedo aparece, maior o score.
      return 500 - idx;
    }
    return 0;
  }

  /// Busca hinos por numero, titulo ou trecho de letra.
  List<GlobalSearchResult> searchHymns(
    String query, {
    required List<Hymn> hymns,
  }) {
    final q = normalize(query);
    if (q.length < 3) return const [];
    final qNum = int.tryParse(q);

    final scored = <GlobalSearchResult>[];
    for (final hymn in hymns) {
      var best = 0;
      var snippet = '';

      if (hymn.number != null && qNum != null && hymn.number == qNum) {
        best = 1200;
        snippet = 'Nº ${hymn.number} — ${hymn.title ?? ''}';
      }

      final titleScore = fuzzyScore(query, hymn.title ?? '');
      if (titleScore > best) {
        best = titleScore;
        snippet = hymn.title ?? '';
      }

      final lyric = hymn.lyric;
      if (lyric != null && lyric.isNotEmpty) {
        final lyricScore = fuzzyScore(query, lyric);
        if (lyricScore > best) {
          best = lyricScore;
          snippet = _snippetAround(lyric, q);
        }
      }

      if (best > 0) {
        scored.add(
          GlobalSearchResult(item: hymn, score: best, snippet: snippet),
        );
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).toList();
  }

  /// Busca versiculos por texto.
  List<GlobalSearchResult> searchBible(
    String query, {
    required List<BibleVerseRef> verses,
  }) {
    final q = normalize(query);
    if (q.length < 3) return const [];

    final scored = <GlobalSearchResult>[];
    for (final verse in verses) {
      final score = fuzzyScore(query, verse.text);
      if (score > 0) {
        scored.add(
          GlobalSearchResult(
            item: verse,
            score: score,
            snippet: _snippetAround(verse.text, q),
          ),
        );
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).toList();
  }

  /// Extrai um trecho curto ao redor do primeiro match.
  static String _snippetAround(String text, String normalizedQuery) {
    final nText = normalize(text);
    final idx = nText.indexOf(normalizedQuery);
    if (idx < 0) return text.length <= 80 ? text : '${text.substring(0, 80)}…';

    const window = 34;
    final start = (idx - window).clamp(0, text.length);
    final end = (idx + normalizedQuery.length + window).clamp(0, text.length);
    final prefix = start > 0 ? '…' : '';
    final suffix = end < text.length ? '…' : '';
    return '$prefix${text.substring(start, end)}$suffix';
  }

  /// Filtra categorias/albuns pelo input de busca da aba Hinos.
  ///
  /// Usa a mesma normalizacao da busca global (acentos/caixa) sobre
  /// nome e subtitulo do album; categorias sem match somem.
  static List<AlbumCategory> filterAlbums(
    List<AlbumCategory> categories,
    String query,
  ) {
    final q = normalize(query);
    if (q.isEmpty) return categories;
    return categories
        .map((cat) {
          final filteredAlbums = cat.albums.where((album) {
            final name = normalize(album.name ?? '');
            final subtitle = normalize(album.subtitle ?? '');
            return name.contains(q) || subtitle.contains(q);
          }).toList();
          return AlbumCategory(
            id: cat.id,
            name: cat.name,
            albums: filteredAlbums,
          );
        })
        .where((cat) => cat.albums.isNotEmpty)
        .toList();
  }

  /// Filtra versículos do capítulo aberto.
  ///
  /// Aceita texto livre, número exato e seletores locais:
  /// `1-3`, `1,3,5`, `1,3-5`. Não exige livro/capítulo porque a tela
  /// já está naquele capítulo. Busca global fica em fluxo separado.
  static Map<String, String> filterVerses(
    Map<String, String> verses,
    String query,
  ) {
    final q = normalize(query);
    if (q.isEmpty) return verses;

    final selected = _parseVerseSelector(q);
    if (selected != null) {
      return Map.fromEntries(
        verses.entries.where((e) => selected.contains(int.tryParse(e.key))),
      );
    }

    return Map.fromEntries(
      verses.entries.where((e) {
        if (e.key == q) return true;
        return normalize(e.value).contains(q);
      }),
    );
  }

  /// `1,3-5` → {1,3,4,5}; null significa que é texto, não seletor.
  static Set<int>? _parseVerseSelector(String query) {
    if (!RegExp(r'^\d+(?:\s*(?:,|-)\s*\d+)*$').hasMatch(query)) {
      return null;
    }
    final out = <int>{};
    for (final part in query.split(',')) {
      final range = part.trim().split('-');
      final first = int.tryParse(range.first.trim());
      if (first == null || first < 1 || range.length > 2) return null;
      if (range.length == 1) {
        out.add(first);
        continue;
      }
      final last = int.tryParse(range.last.trim());
      if (last == null || last < 1) return null;
      final lo = first <= last ? first : last;
      final hi = first <= last ? last : first;
      for (var verse = lo; verse <= hi; verse++) {
        out.add(verse);
      }
    }
    return out;
  }
}
