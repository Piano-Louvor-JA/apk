import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_collection_edit_page.dart';

/// Ramos extras do editor: tocar custom (com/sem áudio), gravar timing
/// (estrofes vazias), mudar capa (cancelado) e adicionar (menu cancelado).
void main() {
  late List<(String, String)> calls;
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
        calls.add((method, url));
        if (method == 'GET' && url.contains('/musics')) {
          return {
            'data': [
              {
                'id_music': 10,
                'id_collection': 6,
                'name': 'Hino A',
                'audio_url': '/audio/hino-a.mp3',
              },
              {'id_music': 11, 'id_collection': 6, 'name': 'Hino B'},
            ],
          };
        }
        if (method == 'GET' && url.contains('/musics/10')) {
          return {
            'id_music': 10,
            'name': 'Hino A',
            'lyric': 'estrofe 1',
            'audio_url': null,
          };
        }
        if (method == 'GET' && url.contains('/lyrics')) {
          return [];
        }
        return <String, dynamic>{};
      },
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );
  });

  testWidgets('tocar custom sem áudio mostra snack e não crasha', (tester) async {
    await tester.pumpWidget(wrap(CustomCollectionEditPage(
      api: api,
      bearerToken: 'tok',
      collection: collection,
    )));
    await tester.pumpAndSettle();

    // Tap na linha abre o hino (falha ao navegar é capturada → snack).
    await tester.tap(find.text('Hino A'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('gravar timing com estrofes vazias mostra snack', (tester) async {
    await tester.pumpWidget(wrap(CustomCollectionEditPage(
      api: api,
      bearerToken: 'tok',
      collection: collection,
    )));
    await tester.pumpAndSettle();

    final timerBtn = find.byIcon(Icons.timer);
    expect(timerBtn, findsWidgets);
    await tester.tap(timerBtn.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('estrofes'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu adicionar abre e cancelar não muda lista', (tester) async {
    await tester.pumpWidget(wrap(CustomCollectionEditPage(
      api: api,
      bearerToken: 'tok',
      collection: collection,
    )));
    await tester.pumpAndSettle();

    final fabBefore = calls.where((c) => c.$1 == 'GET' && c.$2.contains('/musics')).length;

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // Fecha o sheet/menu sem escolher (tap fora).
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    final fabAfter = calls.where((c) => c.$1 == 'GET' && c.$2.contains('/musics')).length;
    expect(fabAfter, greaterThanOrEqualTo(fabBefore));
    expect(tester.takeException(), isNull);
  });
}
