import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/local_custom_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_collection_edit_page.dart';

const _collection = CustomCollection(
  id: 3,
  name: 'Minha Coletânea',
  musicsCount: 0,
  isOwner: true,
);

Widget _editLocal(LocalCustomStore store) => MaterialApp(
  home: CustomCollectionEditPage(
    api: CustomCatalogApiImpl(
      fetch: (m, u, {body, bearerToken}) async => {'data': []},
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    ),
    collection: _collection,
    localStore: store,
  ),
);

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('coll_edit_cov');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  group('CustomCollectionEditPage — modo local', () {
    testWidgets('lista músicas do store do dispositivo (sem API)', (
      tester,
    ) async {
      final store = LocalCustomStore(tmp);
      store.saveLocalMusic(
        collectionId: 3,
        name: 'Local 1',
        lyric: 'estrofe',
        audioPath: '${tmp.path}/a.mp3',
      );
      store.saveLocalMusic(
        collectionId: 3,
        name: 'Local 2',
        lyric: 'estrofe',
        audioPath: '${tmp.path}/b.mp3',
      );

      await tester.pumpWidget(_editLocal(store));
      await tester.pumpAndSettle();

      expect(find.text('Local 1'), findsOneWidget);
      expect(find.text('Local 2'), findsOneWidget);
    });

    testWidgets('remover local: confirm apaga do store e recarrega', (
      tester,
    ) async {
      final store = LocalCustomStore(tmp);
      store.saveLocalMusic(
        collectionId: 3,
        name: 'Pra remover',
        lyric: 'x',
        audioPath: '${tmp.path}/c.mp3',
      );

      await tester.pumpWidget(_editLocal(store));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();

      expect(store.listLocalMusics(3), isEmpty);
      expect(find.text('Pra remover'), findsNothing);
    });

    testWidgets('renomear local: dialog → store + snackbar', (tester) async {
      final store = LocalCustomStore(tmp);
      final coll = store.createLocalCollection('Minha Coletânea');

      await tester.pumpWidget(
        MaterialApp(
          home: CustomCollectionEditPage(
            api: CustomCatalogApiImpl(
              fetch: (m, u, {body, bearerToken}) async => {'data': []},
              apiBaseUrl: 'https://api.test',
              filesBaseUrl: 'https://api.test/file',
            ),
            collection: CustomCollection(
              id: (coll['id'] as num).toInt(),
              name: 'Minha Coletânea',
              musicsCount: 0,
              isOwner: true,
            ),
            localStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Renomeada');
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Renomeada'), findsOneWidget);
      expect(find.text('Renomeada localmente.'), findsOneWidget);
      expect(
        store.listLocalCollections().any((c) => c['name'] == 'Renomeada'),
        isTrue,
      );
    });

    testWidgets('renomear com nome igual não faz nada', (tester) async {
      final store = LocalCustomStore(tmp);
      final coll = store.createLocalCollection('Minha Coletânea');

      await tester.pumpWidget(
        MaterialApp(
          home: CustomCollectionEditPage(
            api: CustomCatalogApiImpl(
              fetch: (m, u, {body, bearerToken}) async => {'data': []},
              apiBaseUrl: 'https://api.test',
              filesBaseUrl: 'https://api.test/file',
            ),
            collection: CustomCollection(
              id: (coll['id'] as num).toInt(),
              name: 'Minha Coletânea',
              musicsCount: 0,
              isOwner: true,
            ),
            localStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Renomeada localmente.'), findsNothing);
    });

    testWidgets('renomear cancelado não muda nada', (tester) async {
      final store = LocalCustomStore(tmp);
      store.createLocalCollection('Minha Coletânea');

      await tester.pumpWidget(_editLocal(store));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextButton).first);
      await tester.pumpAndSettle();

      expect(find.text('Minha Coletânea'), findsWidgets);
    });
  });

  group('CustomCollectionEditPage — modo API: falhas mostram snack', () {
    testWidgets('falha ao remover mostra snackbar e mantém item', (
      tester,
    ) async {
      final api = CustomCatalogApiImpl(
        fetch: (m, u, {body, bearerToken}) async {
          if (m == 'GET' && u.contains('/musics')) {
            return {
              'data': [
                {'id_music': 10, 'id_collection': 3, 'name': 'Hino A'},
              ],
            };
          }
          throw StateError('offline');
        },
        apiBaseUrl: 'https://api.test',
        filesBaseUrl: 'https://api.test/file',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomCollectionEditPage(
            api: api,
            collection: _collection,
            bearerToken: 'tok',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();

      expect(find.text('Falha ao remover. Tente novamente.'), findsOneWidget);
      expect(find.text('Hino A'), findsOneWidget);
    });

    testWidgets('falha ao renomear mostra snackbar e mantém nome', (
      tester,
    ) async {
      final api = CustomCatalogApiImpl(
        fetch: (m, u, {body, bearerToken}) async {
          if (m == 'GET' && u.contains('/musics')) return {'data': []};
          throw StateError('offline');
        },
        apiBaseUrl: 'https://api.test',
        filesBaseUrl: 'https://api.test/file',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomCollectionEditPage(
            api: api,
            collection: _collection,
            bearerToken: 'tok',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Novo Nome');
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Falha ao renomear. Tente novamente.'), findsOneWidget);
      expect(find.text('Minha Coletânea'), findsOneWidget);
    });
  });

  group('CustomCollectionEditPage — adicionar música', () {
    testWidgets('FAB de adicionar existe no modo dono', (tester) async {
      final store = LocalCustomStore(tmp);
      await tester.pumpWidget(_editLocal(store));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
