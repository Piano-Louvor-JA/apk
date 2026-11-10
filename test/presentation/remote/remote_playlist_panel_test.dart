import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_playlist_panel.dart';

void main() {
  testWidgets('toca sequência, embaralha e seleciona linha sem tocar', (
    tester,
  ) async {
    final sent = <RemoteCommand>[];
    RemotePlaylistSelection? selection;
    const state = RemotePlaylistState(
      lists: [
        RemotePlaylist(
          id: 'p1',
          name: 'Culto',
          items: [
            RemotePlaylistItem(musicId: 1, title: 'Primeiro'),
            RemotePlaylistItem(musicId: 2, title: 'Segundo'),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemotePlaylistPanel(
            state: state,
            onSelectionChanged: (value) => selection = value,
            send: (command) async => sent.add(command),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('playlist-play')));
    expect(sent.last.action, RemoteAction.playlistPlay);
    expect(sent.last.targetId, 'p1');
    await tester.tap(find.byKey(const Key('playlist-shuffle')));
    expect(sent.last.action, RemoteAction.playlistShuffle);
    final count = sent.length;
    expect(find.byKey(const Key('playlist-track-1')), findsNothing);
    await tester.tap(find.byKey(const Key('playlist-item-1')));
    expect(sent.length, count);
    expect(selection!.index, 1);
    expect(selection!.musicId, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'seletor permanece fixo e acessível ao rolar uma playlist longa',
    (tester) async {
      final items = List.generate(
        30,
        (index) =>
            RemotePlaylistItem(musicId: index + 1, title: 'Faixa $index'),
      );
      final state = RemotePlaylistState(
        lists: [
          RemotePlaylist(id: 'p1', name: 'Culto', items: items),
          const RemotePlaylist(id: 'p2', name: 'Outra', items: []),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RemotePlaylistPanel(state: state)),
        ),
      );
      final selector = find.byType(DropdownButtonFormField<String>);
      final position = tester.getTopLeft(selector);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(selector, findsOneWidget);
      expect(tester.getTopLeft(selector), position);
      expect(selector.hitTestable(), findsOneWidget);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outra (0)').last);
      await tester.pumpAndSettle();
      expect(find.text('remote.playlist.emptyList'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('oculta fila atual mesmo com fila ativa no desktop', (
    tester,
  ) async {
    const state = RemotePlaylistState(
      lists: [
        RemotePlaylist(
          id: 'p1',
          name: 'Culto',
          items: [RemotePlaylistItem(musicId: 1, title: 'Hino da lista')],
        ),
      ],
      queue: [RemotePlaylistItem(musicId: 2, title: 'Faixa da fila')],
      queueIndex: 0,
      queueLabel: 'Fila do desktop',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RemotePlaylistPanel(state: state)),
      ),
    );
    expect(find.byKey(const Key('playlist-queue-0')), findsNothing);
    expect(find.byKey(const Key('playlist-next')), findsNothing);
    expect(find.text('Faixa da fila'), findsNothing);
    expect(find.text('Hino da lista'), findsOneWidget);
    expect(find.byKey(const Key('playlist-play')), findsOneWidget);
    expect(find.byKey(const Key('playlist-shuffle')), findsOneWidget);
  });
  testWidgets(
    'destaca a faixa real do desktop e acompanha a troca ou fechamento',
    (tester) async {
      const lists = [
        RemotePlaylist(
          id: 'p1',
          name: 'Culto',
          items: [
            RemotePlaylistItem(musicId: 1, title: 'Primeiro'),
            RemotePlaylistItem(musicId: 2, title: 'Segundo'),
          ],
        ),
      ];
      Future<void> show(int? musicId) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RemotePlaylistPanel(
                state: RemotePlaylistState(
                  lists: lists,
                  currentMusicId: musicId,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await show(2);
      expect(
        tester
            .widget<ListTile>(find.byKey(const Key('playlist-item-1')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ListTile>(find.byKey(const Key('playlist-item-0')))
            .selected,
        isFalse,
      );
      await show(1);
      expect(
        tester
            .widget<ListTile>(find.byKey(const Key('playlist-item-0')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ListTile>(find.byKey(const Key('playlist-item-1')))
            .selected,
        isFalse,
      );
      await show(null);
      expect(
        tester
            .widget<ListTile>(find.byKey(const Key('playlist-item-0')))
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<ListTile>(find.byKey(const Key('playlist-item-1')))
            .selected,
        isFalse,
      );
    },
  );
}
