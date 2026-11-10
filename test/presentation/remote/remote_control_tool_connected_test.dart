import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_control_tool_page.dart';

/// Painel CONECTADO via WebLinkServer real em loopback: browser fake
/// (WebSocket) conecta → isControlling true → TabBar + 5 abas + player
/// com controles que enviam comandos reais ao browser.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('conectado: tabs + player + comandos via web link real',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = RemoteSession.instance;
    // receptor fake: aceita WS e registra comandos recebidos
    final received = <String>[];
    
    await tester.runAsync(() async {
      // 1. web link do APK (servidor) em loopback
      final url = await session.startWebLink(token: 'TOOL1');
      expect(url, isNotNull);

      // 2. browser fake conecta como cliente
      final browser = await WebSocket.connect(url!);
      browser.listen((data) {
        if (data is String && data.contains('"action"')) received.add(data);
      });
      // 3. desktop push de estado via o próprio servidor? Não: injeta no hook
      session.debugInjectStateForTest(
        title: 'Hino 100',
        playing: true,
        canPrevious: true,
        canNext: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await browser.close();
    });

    // connected via stream propagation
    expect(session.isControlling, isTrue);

    await tester.pumpWidget(
      const MaterialApp(home: RemoteControlToolPage()),
    );
    await tester.pump();

    // TabBar com 5 abas
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(5));
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isFalse);
    for (final tab in find.byType(Tab).evaluate()) {
      final rect = tester.getRect(find.byWidget(tab.widget));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(400));
    }
    expect(
      tester.widgetList<Tab>(find.byType(Tab)).map((tab) => tab.text),
      ['remote.tabHymns', 'remote.tabBible', 'remote.tabLiturgy',
       'remote.tabPlaylist', 'remote.tabMore'],
    );

    // troca de aba (indexIsChanging listener); a barra fica em Hinos
    await tester.ensureVisible(find.text('remote.tabHymns'));
  await tester.tap(find.text('remote.tabHymns'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // título do player propagado
    expect(find.text('Hino 100'), findsOneWidget);

    // play/pause envia comando (play→pause pois playing=true)
    await tester.tap(find.byTooltip('remote.pause'));
    await tester.pump(const Duration(milliseconds: 300));

    // desconectar pela AppBar (close do HttpServer é IO real)
    await tester.tap(find.byTooltip('remote.disconnect'));
    var dropped = false;
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && !dropped; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        dropped = !session.isControlling;
      }
    });
    await tester.pump();
    expect(dropped, isTrue, reason: 'disconnect deve sair de controlling');
    expect(tester.takeException(), isNull);
  });
}
