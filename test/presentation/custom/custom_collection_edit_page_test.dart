import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_collection_edit_page.dart';

class _Call {
  final String method;
  final String url;
  _Call(this.method, this.url);
}

void main() {
  late List<_Call> calls;
  late CustomCatalogApiImpl api;

  final collection = const CustomCollection(
    id: 6,
    name: 'Minha Coletânea',
    musicsCount: 2,
    isOwner: true,
  );

  Widget wrap(Widget child) => MaterialApp(home: child);

  setUp(() {
    calls = [];
    api = CustomCatalogApiImpl(
      fetch: (method, url, {body, bearerToken}) async {
        calls.add(_Call(method, url));
        if (method == 'GET' && url.contains('/musics')) {
          return {
            'data': [
              {'id_music': 10, 'id_collection': 6, 'name': 'Hino A'},
              {'id_music': 11, 'id_collection': 6, 'name': 'Hino B'},
            ],
          };
        }
        return <String, dynamic>{};
      },
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );
  });

  testWidgets('lista músicas da coletânea', (tester) async {
    await tester.pumpWidget(
      wrap(
        CustomCollectionEditPage(
          api: api,
          collection: collection,
          bearerToken: 'tok',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hino A'), findsOneWidget);
    expect(find.text('Hino B'), findsOneWidget);
    expect(find.text('Minha Coletânea'), findsOneWidget); // AppBar
  });

  testWidgets('vazio mostra orientação de adicionar', (tester) async {
    api = CustomCatalogApiImpl(
      fetch: (m, u, {body, bearerToken}) async => {'data': []},
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );
    await tester.pumpWidget(
      wrap(
        CustomCollectionEditPage(
          api: api,
          collection: collection,
          bearerToken: 'tok',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Coletânea vazia'), findsOneWidget);
  });

  testWidgets('remover: confirm + DELETE /musics/:id + recarrega', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        CustomCollectionEditPage(
          api: api,
          collection: collection,
          bearerToken: 'tok',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // dois botões de remover (trailing close)
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    // diálogo de confirmação
    expect(find.text('Remover música'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
    await tester.pumpAndSettle();

    expect(
      calls.any((c) => c.method == 'DELETE' && c.url.endsWith('/musics/10')),
      isTrue,
    );
    // recarregou a lista (2 GETs de musics: inicial + pós-remover)
    expect(
      calls.where((c) => c.method == 'GET' && c.url.contains('/musics')).length,
      2,
    );
  });

  testWidgets('renomear: PUT com novo nome e AppBar atualiza', (tester) async {
    await tester.pumpWidget(
      wrap(
        CustomCollectionEditPage(
          api: api,
          collection: collection,
          bearerToken: 'tok',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Nome Novo');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(
      calls.any((c) => c.method == 'PUT' && c.url.endsWith('/collections/6')),
      isTrue,
    );
    expect(find.text('Nome Novo'), findsOneWidget);
  });

  testWidgets('excluir coletânea: confirm + DELETE + pop(true)', (
    tester,
  ) async {
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final deleted = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => CustomCollectionEditPage(
                    api: api,
                    collection: collection,
                    bearerToken: 'tok',
                  ),
                ),
              );
              popped = deleted ?? false;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(
      calls.any(
        (c) => c.method == 'DELETE' && c.url.endsWith('/collections/6'),
      ),
      isTrue,
    );
    expect(popped, isTrue);
  });
}
