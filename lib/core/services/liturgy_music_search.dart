library;

import '../../domain/entities/hymn.dart';

/// Busca de música da LITURGIA, port fiel do desktop
/// (app: src/modules/liturgy/services/liturgy-music-search.ts):
/// - ranking: título (todas as palavras, ordem livre) > número do hinário
///   ou coletânea > título com 1 erro de digitação por palavra > letra;
/// - número do hinário: atual antes do 1996;
/// - sem acento, pontuação ou maiúsculas; no máximo 50 resultados.
class LiturgyMusicSearch {
  static const maxResults = 50;
  static const _fuzzyEditDistance = 1;

  static const _from = 'áàâãäåéèêëíìîïóòôõöúùûüçñ';
  static const _to = 'aaaaaaeeeeiiiiooooouuuucn';
  static final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final _digits = RegExp(r'^\d+$');
  static final _trackQuery = RegExp(r'^(?:h(?:a|ino)?\s*)?0*(\d{1,4})$');

  static String normalize(String value) {
    final b = StringBuffer();
    for (final ch in value.toLowerCase().split('')) {
      final i = _from.indexOf(ch);
      b.write(i < 0 ? ch : _to[i]);
    }
    return b.toString().replaceAll(_nonWord, ' ').trim();
  }

  /// Distância de edição <= k, com saída antecipada por linha.
  static bool levenshteinWithin(String a, String b, int k) {
    if (a == b) return true;
    if ((a.length - b.length).abs() > k) return false;
    if (a.isEmpty || b.isEmpty) {
      return (a.length > b.length ? a.length : b.length) <= k;
    }
    var previous = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      var rowMin = current[0];
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final v = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
        current[j] = v;
        if (v < rowMin) rowMin = v;
      }
      if (rowMin > k) return false;
      previous = current;
    }
    return previous[b.length] <= k;
  }

  /// "424", "h 424", "hino 424" → 424.
  static int? _parseTrack(String normalizedQuery) {
    final m = _trackQuery.firstMatch(normalizedQuery);
    if (m == null) return null;
    final n = int.parse(m.group(1)!);
    return n > 0 ? n : null;
  }

  /// Número exige token exato: "1" não casa o "1996" no título.
  static bool _titleTokenMatches(String titleWord, String queryWord) =>
      _digits.hasMatch(queryWord)
      ? titleWord == queryWord
      : titleWord.contains(queryWord);

  static bool _wordsMatchFuzzy(
    List<String> queryWords,
    List<String> targetWords,
  ) {
    for (final q in queryWords) {
      if (targetWords.any((t) => t.contains(q))) continue;
      final ok = targetWords.any(
        (t) =>
            (t.length - q.length).abs() <= _fuzzyEditDistance &&
            levenshteinWithin(q, t, _fuzzyEditDistance),
      );
      if (!ok) return false;
    }
    return true;
  }

  static int? _score(Hymn h, List<String> words, String query, int? track) {
    final titleWords = normalize(
      h.title ?? '',
    ).split(' ').where((w) => w.isNotEmpty).toList();
    // 0 — título: todas as palavras da query (ordem livre).
    if (words.every((w) => titleWords.any((t) => _titleTokenMatches(t, w)))) {
      return 0;
    }
    // 1 — número do hinário ou coletânea.
    if ((track != null && h.hymnalTracks.contains(track)) ||
        normalize(h.albumNames ?? '').contains(query)) {
      return 1;
    }
    // 2 — título com erro de digitação (1ª letra de cada palavra presente).
    final letters = titleWords.join(' ').split('').toSet();
    if (words.every((w) => letters.contains(w[0])) &&
        _wordsMatchFuzzy(words, titleWords)) {
      return 2;
    }
    // 3 — trecho da letra.
    final lyric = normalize(h.lyric ?? '');
    if (lyric.isNotEmpty && words.every(lyric.contains)) return 3;
    return null;
  }

  /// Hinário atual (1º número) antes do 1996 quando o número buscado casa.
  static int _hymnalPreference(Hymn h, int? track) {
    if (track == null || !h.hymnalTracks.contains(track)) return 2;
    return h.hymnalTracks.first == track ? 0 : 1;
  }

  /// Resultados com `number` = nº do hinário (o buscado, quando casou).
  static List<Hymn> search(List<Hymn> index, String query) {
    final normalized = normalize(query);
    if (normalized.isEmpty) return const [];
    final words = normalized.split(' ').where((w) => w.isNotEmpty).toList();
    final track = _parseTrack(normalized);

    final scored = <({Hymn hymn, int score, int pos})>[];
    for (var i = 0; i < index.length; i++) {
      final s = _score(index[i], words, normalized, track);
      if (s != null) scored.add((hymn: index[i], score: s, pos: i));
    }
    int firstTrack(Hymn h) =>
        h.hymnalTracks.isEmpty ? 1 << 30 : h.hymnalTracks.first;
    scored.sort((a, b) {
      if (a.score != b.score) return a.score - b.score;
      final pa = _hymnalPreference(a.hymn, track);
      final pb = _hymnalPreference(b.hymn, track);
      if (pa != pb) return pa - pb;
      final ta = firstTrack(a.hymn);
      final tb = firstTrack(b.hymn);
      if (ta != tb) return ta - tb;
      return a.pos - b.pos;
    });
    return [
      for (final hit in scored.take(maxResults))
        hit.hymn.withNumber(
          track != null && hit.hymn.hymnalTracks.contains(track)
              ? track
              : (hit.hymn.hymnalTracks.isEmpty
                    ? null
                    : hit.hymn.hymnalTracks.first),
        ),
    ];
  }
}
