// Testes do ScheduledRepository: import Delphi, consulta por data, persist.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';

void main() {
  late ScheduledRepository repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    repo = ScheduledRepository(await SharedPreferences.getInstance());
  });

  test('import: categorias + itens com datas, merge por id', () async {
    final changed = await repo.importFromDelphi(
      categories: [
        {'ID': 'c1', 'NOME': 'Provai e Vede'},
      ],
      items: [
        {
          'ID': 'i1',
          'CATEGORIA': 'c1',
          'DATA': '12/10/2026',
          'NOME': 'Sermão Provai',
          'ARQUIVO': 'C:\\Users\\sermao.pptx',
          'ARQUIVO_INFO': '',
        },
        {
          'ID': 'i2',
          'CATEGORIA': 'c1',
          'DATA': '2026-10-19T00:00:00.000',
          'NOME': 'Provai 2',
          'ARQUIVO': 'videos\\clipe.mp4',
          'ARQUIVO_INFO': 'I',
        },
      ],
    );
    expect(changed, 2);

    final cats = repo.loadCategories();
    expect(cats.single.name, 'Provai e Vede');

    final items = repo.loadItems();
    expect(items, hasLength(2));
    expect(items[0].date, DateTime(2026, 10, 12));
    expect(items[1].isRelativePath, isTrue);
    expect(items[1].filePath, 'videos\\clipe.mp4');

    // itemsOn por data
    expect(repo.itemsOn(DateTime(2026, 10, 12)), hasLength(1));
    expect(repo.itemsOn(DateTime(2026, 10, 19)), hasLength(1));
    expect(repo.itemsOn(DateTime(2026, 10, 20)), isEmpty);

    // merge: mesmo id substitui
    await repo.importFromDelphi(
      categories: [],
      items: [
        {
          'ID': 'i1',
          'CATEGORIA': 'c1',
          'DATA': '12/10/2026',
          'NOME': 'Atualizado',
        },
      ],
    );
    expect(repo.loadItems(), hasLength(2));
    expect(repo.loadItems().firstWhere((i) => i.id == 'i1').name, 'Atualizado');
  });

  test('item com DATA inválida é pulado', () async {
    final changed = await repo.importFromDelphi(
      categories: [],
      items: [
        {'ID': 'x', 'DATA': 'não-data', 'NOME': 'sem data'},
      ],
    );
    expect(changed, 0);
    expect(repo.loadItems(), isEmpty);
  });
  test('datas TDateTime float (serial Delphi) também parseiam', () async {
    await repo.importFromDelphi(
      categories: [],
      items: [
        {'ID': 'f1', 'DATA': '46023', 'NOME': 'float date'}, // ~2026-01-17
        {'ID': 'f2', 'DATA': '46023.5', 'NOME': 'float com hora'},
      ],
    );
    final items = repo.loadItems();
    expect(items, hasLength(2));
    // 46023 dias desde 1899-12-30 — só valida que virou data válida
    expect(items[0].date.year, greaterThan(2025));
    expect(items[1].date.year, greaterThan(2025));
  });

  test('volume: 5000 itens sem quebrar', () async {
    final items = List.generate(
      5000,
      (i) => {
        'ID': 'v' + i.toString(),
        'CATEGORIA': 'c1',
        'DATA': '12/10/2026',
        'NOME': 'Item número \$i com nome razoavelmente longo para volume',
        'ARQUIVO': 'C:\\Users\\arquivo\$i.mp4',
      },
    );
    final changed = await repo.importFromDelphi(
      categories: [
        {'ID': 'c1', 'NOME': 'Volume'},
      ],
      items: items,
    );
    expect(changed, 5000);
    expect(repo.loadItems(), hasLength(5000));
    expect(repo.itemsOn(DateTime(2026, 10, 12)), hasLength(5000));
  });
}
