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
    testWidgets('vazio mostra orientação + FAB Nova playlist', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Nova playlist'), findsOneWidget);
      expect(find.textContaining('Nenhuma playlist'), findsOneWidget);
      expect(
        find.textContaining('coletâneas da comunidade'),
        findsOneWidget,
        reason: 'deixa claro que playlist ≠ coletânea',
      );
    });

    testWidgets('criar playlist pelo FAB aparece na lista', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nova playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Culto de sábado',
      );
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      expect(find.text('Culto de sábado'), findsOneWidget);
      expect(find.text('0 hinos'), findsOneWidget);

      // persistiu de verdade:
      final storage = PlaylistStorage();
      expect((await storage.list()).single.name, 'Culto de sábado');
    });

    testWidgets('playlist com itens mostra contagem de hinos', (tester) async {
      final storage = PlaylistStorage();
      final p = await storage.create('Minha seleção');
      await storage.addItem(
        p.id,
        const PlaylistItem(musicId: 12, title: 'Hino 12'),
      );

      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Minha seleção'), findsOneWidget);
      expect(find.text('1 hinos'), findsOneWidget);
    });
  });
}
