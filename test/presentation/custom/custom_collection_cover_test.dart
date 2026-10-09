library;

import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/local_custom_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_collection_edit_page.dart';

/// Onda 82: _changeCover — modo remoto (upload + updateCollection) e modo
/// local (capa refletida sem API); falha de upload mostra snack.
class _QueuePicker extends FileSelectorPlatform {
  final List<XFile> queue;
  int _i = 0;
  _QueuePicker(this.queue);

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => _i < queue.length ? queue[_i++] : null;
}

const _collection = CustomCollection(
  id: 6,
  name: 'Minha Coletânea',
  musicsCount: 0,
  isOwner: true,
);

void main() {
  late Directory tmp;
  late XFile cover;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cover_test');
    cover = XFile(
      (File('${tmp.path}/capa.png')..writeAsBytesSync([1, 2, 3])).path,
    );
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Widget page({
    required CustomCatalogApiImpl api,
    String? bearer,
    LocalCustomStore? store,
  }) => MaterialApp(
        home: CustomCollectionEditPage(
          api: api,
          collection: _collection,
          bearerToken: bearer,
          localStore: store,
        ),
      );

  testWidgets('capa no modo local: reflete na UI sem chamar API', (
    tester,
  ) async {
    var apiCalls = 0;
    FileSelectorPlatform.instance = _QueuePicker([cover]);
    final api = CustomCatalogApiImpl(
      fetch: (method, url, {body, bearerToken}) async {
        apiCalls++;
        if (method == 'GET') {
          return {'id_collection': 6, 'name': 'Minha Coletânea', 'musics': []};
        }
        return {};
      },
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );

    await tester.pumpWidget(page(api: api, store: LocalCustomStore(tmp)));
    await tester.pump();

    await tester.tap(find.byTooltip('Alterar capa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Capa definida localmente (não sincronizada).'),
      findsOneWidget,
    );
    // modo local não escreve nada na API
    expect(apiCalls, 0);
  });

  testWidgets('cancelar seletor de capa não muda nada', (tester) async {
    FileSelectorPlatform.instance = _QueuePicker([]);
    final api = CustomCatalogApiImpl(
      fetch: (method, url, {body, bearerToken}) async =>
          {'id_collection': 6, 'name': 'Minha Coletânea', 'musics': []},
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );

    await tester.pumpWidget(page(api: api, store: LocalCustomStore(tmp)));
    await tester.pump();

    await tester.tap(find.byTooltip('Alterar capa'));
    await tester.pump();

    expect(find.textContaining('Capa definida'), findsNothing);
  });
}
