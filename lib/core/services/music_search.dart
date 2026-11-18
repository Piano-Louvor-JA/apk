library;

import '../../domain/entities/hymn.dart';

/// Busca de músicas com o MESMO critério do desktop
/// (app: src/modules/albums/services/album-music-search.ts e
/// src/shared/services/search-terms.ts):
/// - título, coletânea e letra, sem acento e sem diferenciar maiúsculas;
/// - trecho contíguo casa direto; senão TODOS os termos precisam aparecer
///   em algum campo ("jesus adoradores 5");
/// - número busca o nº do hinário (atual antes do 1996);
/// - texto: título igual > começa com > contém > só coletânea/letra;
/// - no máximo 50 resultados.
class MusicSearch {
  static const maxResults = 50;

  static String fold(String value) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final ch in value.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i < 0 ? ch : to[i]);
    }
    return b.toString();
  }

  static bool matchesAllTerms(
    String title,
    String album,
    String query,
    String lyrics,
  ) {
    final t = fold(title);
    final s = fold(album);
    final l = fold(lyrics.replaceAll(RegExp(r'\s+'), ' '));
    final q = fold(query.trim());
    if (q.isEmpty) return false;
    if (l.isNotEmpty && l.contains(q)) return true;
    if (t.contains(q) || s.contains(q)) return true;
    final terms = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (terms.length <= 1) return false;
    return terms.every(
      (term) => t.contains(term) || s.contains(term) || l.contains(term),
    );
  }

  static int _relevance(Hymn h, String query) {
    final title = fold(h.title ?? '');
    final q = fold(query);
    if (title == q) return 3;
    if (title.startsWith(q)) return 2;
    if (title.contains(q)) return 1;
    return 0;
  }

  /// Resultados com `number` = nº do hinário (quando a música tem).
  static List<Hymn> search(List<Hymn> index, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final numQuery = RegExp(r'^\d+$').hasMatch(trimmed)
        ? int.parse(trimmed)
        : null;

    final matched = <Hymn>[];
    for (final h in index) {
      final title = h.title ?? '';
      final album = h.albumNames ?? '';
      final lyrics = h.lyric ?? '';
      final byNumber = numQuery != null && h.hymnalTracks.contains(numQuery);
      if (byNumber || matchesAllTerms(title, album, trimmed, lyrics)) {
        final shown = byNumber
            ? numQuery
            : (h.hymnalTracks.isNotEmpty ? h.hymnalTracks.first : null);
        matched.add(h.withNumber(shown));
      }
    }

    if (numQuery != null) {
      int score(Hymn h) {
        if (!h.hymnalTracks.contains(numQuery)) return 0;
        // Nº no hinário atual (1º da lista) antes do 1996.
        return h.hymnalTracks.first == numQuery ? 2 : 1;
      }

      matched.sort((a, b) => score(b) - score(a));
    } else {
      // Estável: Dart sort não é estável, então desempata pela ordem.
      final order = {for (var i = 0; i < matched.length; i++) matched[i]: i};
      matched.sort((a, b) {
        final r = _relevance(b, trimmed) - _relevance(a, trimmed);
        return r != 0 ? r : order[a]! - order[b]!;
      });
    }
    return matched.take(maxResults).toList();
  }
}
