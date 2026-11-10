import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/presentation/remote/remote_site_browser_page.dart';

void main() {
  group('normalize', () {
    test('mantem http e https', () {
      expect(
        RemoteSiteBrowserPage.normalize(' https://www.adventistas.org/pt '),
        Uri.parse('https://www.adventistas.org/pt'),
      );
      expect(
        RemoteSiteBrowserPage.normalize('http://x.org'),
        Uri.parse('http://x.org'),
      );
    });

    test('sem esquema vira https', () {
      expect(
        RemoteSiteBrowserPage.normalize('adventistas.org'),
        Uri.parse('https://adventistas.org'),
      );
    });

    test('vazio, sem host ou esquema nao web e recusado', () {
      expect(RemoteSiteBrowserPage.normalize('  '), isNull);
      expect(RemoteSiteBrowserPage.normalize('https://'), isNull);
      expect(RemoteSiteBrowserPage.normalize('file:///etc/passwd'), isNull);
      expect(RemoteSiteBrowserPage.normalize('javascript://alert(1)'), isNull);
    });
  });
}
