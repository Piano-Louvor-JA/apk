import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/playlist_storage.dart';
import 'package:louvorja_piano_mobile/presentation/playlists/playlists_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlaylistsPage — rename e delete via popup', () {
    testWidgets('renomeia playlist existente', (tester) async {
      final storage = PlaylistStorage();
      await storage.create('Antiga');

      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renomear'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Nova');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Nova'), findsOneWidget);
      expect(find.text('Antiga'), findsNothing);
    });

    testWidgets('exclui playlist após confirmar', (tester) async {
      final storage = PlaylistStorage();
      await storage.create('Temp');

      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir').last);
      await tester.pumpAndSettle();

      expect(find.text('Temp'), findsNothing);
      expect(find.textContaining('Nenhuma playlist'), findsOneWidget);
    });

    testWidgets('cancelar exclusão mantém playlist', (tester) async {
      final storage = PlaylistStorage();
      await storage.create('Fica');

      await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Fica'), findsOneWidget);
    });
  });

  group('PlaylistDetailPage', () {
    testWidgets('playlist inexistente mostra não encontrada', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PlaylistDetailPage(playlistId: 'ghost')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Playlist não encontrada.'), findsOneWidget);
    });

    testWidgets('playlist vazia mostra orientação', (tester) async {
      final storage = PlaylistStorage();
      final p = await storage.create('Vazia');

      await tester.pumpWidget(
        MaterialApp(home: PlaylistDetailPage(playlistId: p.id)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Playlist vazia'), findsOneWidget);
    });

    testWidgets('com itens lista hinos e remove ao tocar no ícone', (
      tester,
    ) async {
      final storage = PlaylistStorage();
      final p = await storage.create('Com itens');
      await storage.addItem(
        p.id,
        const PlaylistItem(musicId: 42, albumId: 7, title: 'Ao Pé da Cruz'),
      );

      await tester.pumpWidget(
        MaterialApp(home: PlaylistDetailPage(playlistId: p.id)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ao Pé da Cruz'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byTooltip('Remover da playlist'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Playlist vazia'), findsOneWidget);
    });
  });
}
