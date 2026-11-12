import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/quarter_paste_parser.dart';

void main() {
  test('blocos por data, slots e linhas únicas mantêm datas e conteúdos', () {
    final result = QuarterPasteParser.parse(
      '03/10\ninicial: 15 - Adoração\nprovai: https://example.org/video.mp4\n11/10 — hino 400 — Meu Lugar',
      year: 2026,
    );
    expect(result.groups.length, 2);
    expect(result.groups.first.date, DateTime(2026, 10, 3));
    expect(result.groups.first.entries.first.slotKey, 'inicial');
    expect(result.groups.first.entries.first.musicId, 15);
    expect(
      result.groups.first.entries.last.filePath,
      'https://example.org/video.mp4',
    );
    expect(result.groups.last.entries.single.name, 'Meu Lugar');
    expect(result.errors, isEmpty);
  });
  test(
    'datas inválidas e linhas sem data são relatadas, sem contaminar outro bloco',
    () {
      final result = QuarterPasteParser.parse(
        'sem data\n31/02\n15 - Ignorado\n05/10/26\nML: 22 | Bassora',
        year: 2025,
      );
      expect(result.errors, contains('31/02'));
      expect(result.groups.single.date, DateTime(2026, 10, 5));
      expect(result.groups.single.entries.single.musicId, 22);
    },
  );
}
