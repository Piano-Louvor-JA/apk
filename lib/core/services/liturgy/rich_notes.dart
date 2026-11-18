import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;

/// Mesmas tags, estilos e paleta do rich-notes.ts do desktop.
abstract final class RichNotes {
  static const colors = [
    '#ffffff',
    '#bdbdbd',
    '#ffee58',
    '#ffb74d',
    '#ff6d00',
    '#ef5350',
    '#f06292',
    '#ab47bc',
    '#42a5f5',
    '#26c6da',
    '#66bb6a',
  ];
  static const _tags = {
    'p',
    'div',
    'br',
    'span',
    'b',
    'strong',
    'i',
    'em',
    'u',
    'ul',
    'ol',
    'li',
  };
  static const _blocks = {'p', 'div', 'ul', 'ol', 'li'};
  static const _drop = {
    'script',
    'style',
    'iframe',
    'object',
    'embed',
    'svg',
    'math',
    'template',
  };
  static const _escape = HtmlEscape(HtmlEscapeMode.element);
  static String titleColor(String? raw) {
    final color = (raw ?? '').trim().toLowerCase();
    return RegExp(r'^#[\da-f]{6}$').hasMatch(color) ? color : '';
  }

  static bool _color(String value) => RegExp(
    r'^(#[\da-f]{3,8}|rgba?\(\s*[\d.]+%?\s*,\s*[\d.]+%?\s*,\s*[\d.]+%?\s*(,\s*[\d.]+%?\s*)?\)|transparent)$',
    caseSensitive: false,
  ).hasMatch(value);
  static String filterStyle(String raw) {
    final kept = <String>[];
    for (final declaration in raw.split(';')) {
      final colon = declaration.indexOf(':');
      if (colon < 0) continue;
      final prop = declaration.substring(0, colon).trim().toLowerCase();
      final value = declaration
          .substring(colon + 1)
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ');
      final valid = switch (prop) {
        'color' || 'background-color' => _color(value),
        'font-size' => RegExp(
          r'^(x-small|small|medium|large|x-large|xx-large|xxx-large)$',
        ).hasMatch(value),
        'font-weight' => RegExp(
          r'^(bold|bolder|normal|[1-9]00)$',
        ).hasMatch(value),
        'font-style' => value == 'italic' || value == 'normal',
        'text-decoration' || 'text-decoration-line' => [
          'underline',
          'line-through',
          'none',
        ].contains(value),
        'text-align' => [
          'left',
          'center',
          'right',
          'justify',
          'start',
          'end',
        ].contains(value),
        _ => false,
      };
      if (valid) kept.add('$prop: $value;');
    }
    return kept.join(' ');
  }

  static String _clean(dom.Node node) {
    if (node is dom.Text) return _escape.convert(node.data);
    if (node is! dom.Element) return node.nodes.map(_clean).join();
    final tag = node.localName!;
    if (_drop.contains(tag)) return '';
    final inner = node.nodes.map(_clean).join();
    if (!_tags.contains(tag)) return inner;
    if (tag == 'br') return '<br>';
    final style = filterStyle(node.attributes['style'] ?? '');
    return '<$tag${style.isEmpty ? '' : ' style="${const HtmlEscape(HtmlEscapeMode.attribute).convert(style)}"'}>$inner</$tag>';
  }

  static String sanitize(String? html) {
    final clean = parser
        .parseFragment(html ?? '')
        .nodes
        .map(_clean)
        .join()
        .trim();
    return plainText(clean).isEmpty ? '' : clean;
  }

  static String _text(dom.Node node) {
    var text = '';
    void newline() {
      if (text.isNotEmpty && !text.endsWith('\n')) text += '\n';
    }

    for (final child in node.nodes) {
      if (child is dom.Text) {
        text += child.data;
        continue;
      }
      if (child is! dom.Element) continue;
      final tag = child.localName;
      if (_drop.contains(tag)) continue;
      if (tag == 'br') {
        text += '\n';
        continue;
      }
      final inner = _text(child);
      if (tag == 'li') {
        newline();
        final parent = child.parent;
        final index = parent?.children.indexOf(child) ?? 0;
        final marker = parent?.localName == 'ol' ? '${index + 1}.' : '•';
        text += '$marker ${inner.replaceAll(RegExp(r'\n+$'), '')}\n';
      } else if (_blocks.contains(tag)) {
        newline();
        text += inner;
        newline();
      } else {
        text += inner;
      }
    }
    return text;
  }

  static String plainText(String html) => _text(parser.parseFragment(html))
      .replaceAll('\u00a0', ' ')
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  /// Corpo de uma anotação/aviso como o desktop: texto formatado; sem ele,
  /// o subtítulo; sem subtítulo, as notas.
  static String bodyOf({
    required String? notesHtml,
    required String subtitle,
    required String? notes,
  }) {
    final rich = sanitize(notesHtml);
    if (rich.isNotEmpty) return rich;
    return fromPlainText(subtitle.trim().isNotEmpty ? subtitle : (notes ?? ''));
  }

  static String fromPlainText(String text) => text.trim().isEmpty
      ? ''
      : text
            .split(RegExp(r'\r?\n'))
            .map(
              (line) => line.trim().isEmpty
                  ? '<div><br></div>'
                  : '<div>${_escape.convert(line)}</div>',
            )
            .join();
}
