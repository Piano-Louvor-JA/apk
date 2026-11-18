import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/provai_catalog.dart';

void main() {
  test(
    'registry usa apenas as oito fontes auditadas do desktop, com edições separadas',
    () {
      expect(ProvaiCatalog.sources.length, 8);
      expect(ProvaiCatalog.source('es', 2026, 4)?.rotationName, 'Probad y Ved');
      expect(ProvaiCatalog.source('pt', 2027, 1), isNull);
      expect(ProvaiCatalog.source('en', 2026, 1), isNull);
    },
  );
  test('extrai episódios PT/ES, decodifica título e elimina duplicados', () {
    const html =
        '<a href="https://bucket.example/11-14-26_Gratid%C3%A3o_a_Deus.mp4">a</a><a href="https://bucket.example/11-14-26_Gratid%C3%A3o_a_Deus.mp4">a</a><a href="https://bucket.example/11-07-26Fidelidad.mp4">b</a>';
    final episodes = ProvaiCatalog.episodes(html);
    expect(episodes.length, 2);
    expect(episodes.first.date, DateTime(2026, 11, 7));
    expect(episodes.last.title, 'Gratidão a Deus');
  });
}
