import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_link_info.dart';

void main() {
  test('extrai título, origem e descrição sem executar HTML', () {
    final info = LiturgyLinkInfo.fromHtml(
      '<title>Título &amp; teste</title><meta property="og:site_name" content="Fonte"><meta name="description" content="Descrição">',
    );
    expect(info.title, 'Título & teste');
    expect(info.source, 'Fonte');
    expect(info.description, 'Descrição');
  });
  test(
    'autopreenchimento respeita edição manual e substitui valor anterior automático',
    () {
      const info = LiturgyLinkInfo(
        title: 'Novo',
        source: 'Canal',
        description: 'Texto\nhttps://x.com\n#tag',
        durationMs: 42000,
      );
      final patch = info.patch(
        name: 'Manual',
        subtitle: 'Anterior',
        autoSubtitle: 'Anterior',
      );
      expect(patch.containsKey('name'), isFalse);
      expect(patch['subtitle'], 'Canal\n\nTexto');
      expect(patch['durationMs'], 42000);
    },
  );
}
