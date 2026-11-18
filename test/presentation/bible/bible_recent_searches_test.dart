import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bible_recent_searches.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('começa vazio', () async {
    expect(await BibleRecentSearches.load(), isEmpty);
  });

  test('mais recente primeiro, sem repetir (ignora caixa)', () async {
    await BibleRecentSearches.add('João 3:16');
    await BibleRecentSearches.add('Salmos 23');
    await BibleRecentSearches.add('joão 3:16');
    expect(await BibleRecentSearches.load(), ['joão 3:16', 'Salmos 23']);
  });

  test('guarda no máximo 8', () async {
    for (var i = 1; i <= 10; i++) {
      await BibleRecentSearches.add('Salmos $i');
    }
    final r = await BibleRecentSearches.load();
    expect(r.length, 8);
    expect(r.first, 'Salmos 10');
  });

  test('ignora vazio', () async {
    await BibleRecentSearches.add('   ');
    expect(await BibleRecentSearches.load(), isEmpty);
  });

  test('limpar apaga tudo', () async {
    await BibleRecentSearches.add('amor');
    await BibleRecentSearches.clear();
    expect(await BibleRecentSearches.load(), isEmpty);
  });
}
