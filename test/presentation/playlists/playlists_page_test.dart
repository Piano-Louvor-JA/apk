import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/playlist_storage.dart';
import 'package:louvorja_piano_mobile/presentation/playlists/playlists_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlaylistsPage widget', () {
    testWidgets('vazio mostra orientação + campo inline de criação', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(const Key('playlists-new-name')), findsOneWidget);
      expect(find.byKey(const Key('playlists-create')), findsOneWidget);
      expect(find.byKey(const Key('playlists-import')), findsOneWidget);
      expect(find.byKey(const Key('playlists-export')), findsOneWidget);
      expect(
        find.textContaining('Nenhuma playlist criada ainda.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('coletâneas da comunidade'),
        findsOneWidget,
        reason: 'deixa claro que playlist ≠ coletânea',
      );
    });

    testWidgets('criar playlist pelo campo inline aparece na lista', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('playlists-new-name')),
        'Culto de sábado',
      );
      await tester.tap(find.byKey(const Key('playlists-create')));
      await tester.pumpAndSettle();

      expect(find.text('Culto de sábado'), findsOneWidget);
      expect(find.text('0 faixa(s)'), findsOneWidget);
      // campo limpo após criar
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('playlists-new-name')))
            .controller!
            .text,
        isEmpty,
      );

      // persistiu de verdade:
      final storage = PlaylistStorage();
      expect((await storage.list()).single.name, 'Culto de sábado');
    });

    testWidgets('nome vazio não cria playlist', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('playlists-new-name')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('playlists-create')));
      await tester.pumpAndSettle();

      expect(await PlaylistStorage().list(), isEmpty);
      expect(
        find.textContaining('Nenhuma playlist criada ainda.'),
        findsOneWidget,
      );
    });

    testWidgets('playlist com itens mostra contagem de faixas', (tester) async {
      final storage = PlaylistStorage();
      final p = await storage.create('Minha seleção');
      await storage.addItem(
        p.id,
        const PlaylistItem(musicId: 12, title: 'Hino 12'),
      );

      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Minha seleção'), findsOneWidget);
      expect(find.text('1 faixa(s)'), findsOneWidget);
    });
  });
}
