import 'package:html/parser.dart' as parser;

class ProvaiSource {
  const ProvaiSource(this.language, this.year, this.quarter, this.url);
  final String language;
  final int year;
  final int quarter;
  final String url;
  String get rotationName =>
      language == 'es' ? 'Probad y Ved' : 'Provai e Vede';
}

class ProvaiEpisode {
  const ProvaiEpisode({
    required this.date,
    required this.title,
    required this.url,
  });
  final DateTime date;
  final String title;
  final String url;
  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'title': title,
    'url': url,
  };
  factory ProvaiEpisode.fromJson(Map<String, dynamic> value) => ProvaiEpisode(
    date: DateTime.parse(value['date'] as String),
    title: value['title'] as String,
    url: value['url'] as String,
  );
}

/// Registry fechado do provai-e-vede-catalog.ts. Nenhuma URL é adivinhada.
abstract final class ProvaiCatalog {
  static const sources = <ProvaiSource>[
    ProvaiSource(
      'pt',
      2026,
      1,
      'https://downloads.adventistas.org/pt/mordomia-crista/video/provai-e-vede-2026-1o-trimestre',
    ),
    ProvaiSource(
      'pt',
      2026,
      2,
      'https://downloads.adventistas.org/pt/mordomia-crista/video/provai-e-vede-2026-2o-trimestre',
    ),
    ProvaiSource(
      'pt',
      2026,
      3,
      'https://downloads.adventistas.org/pt/mordomia-crista/video/provai-e-vede-2026-3o-trimestre',
    ),
    ProvaiSource(
      'pt',
      2026,
      4,
      'https://downloads.adventistas.org/pt/mordomia-crista/video/provai-e-vede-2026-4o-trimestre',
    ),
    ProvaiSource(
      'es',
      2026,
      1,
      'https://downloads.adventistas.org/es/mayordomia-cristiana/video/probad-y-ved-2026-1er-trimestre/',
    ),
    ProvaiSource(
      'es',
      2026,
      2,
      'https://downloads.adventistas.org/es/mayordomia-cristiana/video/probad-y-ved-2026-2do-trimestre-2026/',
    ),
    ProvaiSource(
      'es',
      2026,
      3,
      'https://downloads.adventistas.org/es/mayordomia-cristiana/video/probad-y-ved-2026-3do-trimestre-2026/',
    ),
    ProvaiSource(
      'es',
      2026,
      4,
      'https://downloads.adventistas.org/es/mayordomia-cristiana/video/probad-y-ved-2026-4er-trimestre-2026/',
    ),
  ];
  static ProvaiSource? source(String language, int year, int quarter) => sources
      .where(
        (s) => s.language == language && s.year == year && s.quarter == quarter,
      )
      .firstOrNull;
  static List<ProvaiEpisode> episodes(String html) {
    final result = <ProvaiEpisode>[];
    final seen = <String>{};
    for (final anchor
        in parser.parseFragment(html).querySelectorAll('a[href]')) {
      final url = anchor.attributes['href']!;
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          !url.endsWith('.mp4') ||
          !seen.add(url))
        continue;
      final match = RegExp(
        r'/([0-9]{2})-([0-9]{2})-([0-9]{2})_?([^/]*)\.mp4$',
      ).firstMatch(url);
      if (match == null) continue;
      final month = int.parse(match[1]!);
      final day = int.parse(match[2]!);
      final year = 2000 + int.parse(match[3]!);
      final date = DateTime(year, month, day);
      if (date.month != month || date.day != day) continue;
      var slug = match[4]!;
      try {
        slug = Uri.decodeComponent(slug);
      } catch (_) {
        /* mantém o slug literal */
      }
      var title = slug
          .replaceAll(RegExp(r'[-_]+'), ' ')
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
      if (title.isNotEmpty)
        title = '${title[0].toUpperCase()}${title.substring(1)}';
      result.add(ProvaiEpisode(date: date, title: title, url: url));
    }
    return result..sort((a, b) => a.date.compareTo(b.date));
  }
}
