import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_control_tool_page.dart';

void main() {
  testWidgets('linha seleciona, play único abre faixa e seta de projeção pulsa', (tester) async {
    tester.view.physicalSize = const Size(440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = RemoteSession.instance;
    late WebSocket desktop;
    final received = <Map>[];
    const list = RemotePlaylist(id: 'p1', name: 'Culto', items: [RemotePlaylistItem(musicId: 42, title: 'Digno')]);
    RemotePlayerState snapshot({bool opened = false}) => RemotePlayerState(
      title: opened ? 'Digno' : null, playing: opened,
      position: Duration.zero, duration: opened ? const Duration(minutes: 3) : Duration.zero,
      slideIndex: 0, slideCount: opened ? 2 : 0, volume: 80, canPrevious: false, canNext: false,
      playlistModule: RemotePlaylistState(lists: const [list], currentMusicId: opened ? 42 : null),
      videoControls: opened ? const RemoteVideoControls(audioOutput: 'player', canProject: true, projecting: false, canControlCaptions: false, captionsHidden: false, monitors: [], tvs: []) : null,
    );
    await tester.runAsync(() async {
      final url = await session.startWebLink(token: 'PLSEL');
      desktop = await WebSocket.connect(url!);
      desktop.listen((raw) {
        final message = jsonDecode(raw as String) as Map;
        if (message['type'] == 'command') received.add(message);
      });
      session.debugEmitStateForTest(snapshot());
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    addTearDown(() async { await desktop.close(); await session.disconnect(); });
    await tester.pumpWidget(const MaterialApp(home: RemoteControlToolPage()));
    await tester.pump();
    await tester.tap(find.text('remote.tabPlaylist'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final play = find.byKey(const Key('remote-play-button'));
    expect(tester.widget<IconButton>(play).onPressed, isNull);
    expect(find.byKey(const Key('playlist-track-0')), findsNothing);
    await tester.tap(find.byKey(const Key('playlist-item-0')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    expect(received, isEmpty);
    expect(tester.widget<IconButton>(play).onPressed, isNotNull);
    await tester.runAsync(() async { tester.widget<IconButton>(play).onPressed!(); await Future<void>.delayed(const Duration(milliseconds: 100)); });
    expect(received.single['action'], 'playlist.track');
    expect(received.single['targetId'], 'p1');
    expect(received.single['value'], 0);
    session.debugEmitStateForTest(snapshot(opened: true));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('remote-project-pulse')), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(const Key('playlist-item-0'))).selected, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
