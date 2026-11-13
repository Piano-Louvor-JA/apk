import 'package:html/parser.dart' as html;

class LiturgyLinkInfo {
  const LiturgyLinkInfo({
    required this.title,
    this.source = '',
    this.description = '',
    this.durationMs = 0,
  });
  final String title, source, description;
  final int durationMs;
  factory LiturgyLinkInfo.fromHtml(String raw) {
    final doc = html.parse(raw);
    String meta(String key) =>
        doc
            .querySelector('meta[property="$key"],meta[name="$key"]')
            ?.attributes['content']
            ?.trim() ??
        '';
    return LiturgyLinkInfo(
      title: meta('og:title').isNotEmpty
          ? meta('og:title')
          : doc.querySelector('title')?.text.trim() ?? '',
      source: meta('og:site_name'),
      description: meta('og:description').isNotEmpty
          ? meta('og:description')
          : meta('description'),
    );
  }
  factory LiturgyLinkInfo.fromJson(Map<String, dynamic> raw) => LiturgyLinkInfo(
    title: raw['title'] as String? ?? '',
    source: raw['source'] as String? ?? '',
    description: raw['description'] as String? ?? '',
    durationMs: (raw['durationMs'] as num?)?.toInt() ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'title': title,
    'source': source,
    'description': description,
    'durationMs': durationMs,
  };
  String get excerpt {
    final lines = description
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty &&
              !RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(line) &&
              !line
                  .split(RegExp(r'\s+'))
                  .every((word) => word.startsWith('#') && word.length > 1),
        )
        .join('\n');
    if (lines.length <= 300) return lines;
    final cut = lines.substring(0, 299);
    final space = cut.lastIndexOf(RegExp(r'\s'));
    return '${(space > 180 ? cut.substring(0, space) : cut).trimRight()}…';
  }

  Map<String, dynamic> patch({
    required String name,
    required String subtitle,
    String autoName = '',
    String autoSubtitle = '',
  }) {
    bool canReplace(String current, String auto) =>
        current.trim().isEmpty || auto.isNotEmpty && current == auto;
    final notes = [
      if (source.isNotEmpty && source != excerpt) source,
      if (excerpt.isNotEmpty) excerpt,
    ].join('\n\n');
    return {
      if (canReplace(name, autoName)) 'name': title,
      if (notes.isNotEmpty && canReplace(subtitle, autoSubtitle))
        'subtitle': notes,
      if (durationMs > 0) 'durationMs': durationMs,
    };
  }
}
