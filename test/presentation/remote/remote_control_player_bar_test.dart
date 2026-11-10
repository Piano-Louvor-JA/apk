import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_control_tool_page.dart';

const _barKey = Key('remote-player-bar');

/// Sessao conectada via web link real em loopback, com a pagina montada.
Future<void> _pumpConnected(WidgetTester tester) async {
  final session = RemoteSession.instance;
  await tester.runAsync(() async {
    final url = await session.startWebLink(token: 'BAR1');
    final browser = await WebSocket.connect(url!);
    session.debugInjectStateForTest(
      title: 'Hino 100',
      playing: true,
      canPrevious: true,
      canNext: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await browser.close();
  });
  await tester.pumpWidget(const MaterialApp(home: RemoteControlToolPage()));
  await tester.pump();
}

Future<void> _disconnect(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(RemoteSession.instance.disconnect);
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  // Inicia a animacao, avanca ate o fim e desenha a aba ja trocada.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('aba Liturgia so escolhe o dia: sem barra do player', (
    tester,
  ) async {
    await _pumpConnected(tester);

    expect(find.byKey(_barKey), findsNothing);
    await _disconnect(tester);
  });

  testWidgets('barra do player fica colada no rodape em Hinos', (
    tester,
  ) async {
    await _pumpConnected(tester);
    await _openTab(tester, 'remote.tabHymns');

    expect(find.byKey(_barKey), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byKey(_barKey)).dy,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
    await _disconnect(tester);
  });

  testWidgets('barra continua visivel na aba Hinos', (tester) async {
    await _pumpConnected(tester);

    await _openTab(tester, 'remote.tabHymns');

    expect(find.byKey(_barKey), findsOneWidget);
    expect(find.text('Hino 100'), findsOneWidget);
    await _disconnect(tester);
  });

  testWidgets('abas que nao usam o player nao mostram a barra', (tester) async {
    await _pumpConnected(tester);

    for (final tab in [
      'remote.tabBible',
      'remote.tabTime',
      'remote.tabMore',
    ]) {
      await _openTab(tester, tab);
      expect(find.byKey(_barKey), findsNothing, reason: tab);
    }
    await _disconnect(tester);
  });

  testWidgets('barra some com o teclado aberto e volta ao fechar', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);
    await _pumpConnected(tester);
    await _openTab(tester, 'remote.tabHymns');

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    expect(find.byKey(_barKey), findsNothing);

    tester.view.resetViewInsets();
    await tester.pump();
    expect(find.byKey(_barKey), findsOneWidget);
    await _disconnect(tester);
  });
}
