import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_control_tool_page.dart';

const _playKey = Key('remote-play-button');
const _pulseKey = Key('remote-play-pulse');
const _rowKey = Key('remote-hymns-result-0');

const _results = RemoteMediaState(
  searchResults: [RemoteMusicHit(musicId: 42, name: 'Ao Pe da Cruz')],
);

/// Conexao real em loopback; o browser fake fica aberto registrando comandos.
Future<_Peer> _pumpConnected(WidgetTester tester, {String? title}) async {
  final session = RemoteSession.instance;
  final received = <String>[];
  late WebSocket browser;
  await tester.runAsync(() async {
    final url = await session.startWebLink(token: 'SEL1');
    browser = await WebSocket.connect(url!);
    browser.listen((data) {
      if (data is String && data.contains('media.open')) received.add(data);
    });
    session.debugInjectStateForTest(
      title: title,
      playing: false,
      mediaModule: _results,
      duration: title == null ? Duration.zero : const Duration(minutes: 3),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  // Roda tambem quando o teste falha: socket aberto prenderia o processo.
  addTearDown(() async {
    await browser.close();
    await session.disconnect();
  });
  await tester.pumpWidget(const MaterialApp(home: RemoteControlToolPage()));
  await tester.pump();
  await tester.ensureVisible(find.text('remote.tabHymns'));
  await tester.tap(find.text('remote.tabHymns'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  return _Peer(browser, received);
}

class _Peer {
  _Peer(this.browser, this.received);
  final WebSocket browser;
  final List<String> received;

  Future<void> close(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());
}

IconButton _play(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(_playKey));

Future<void> _settleNetwork(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sem projecao e sem selecao, o play fica desativado', (
    tester,
  ) async {
    final peer = await _pumpConnected(tester);

    expect(_play(tester).onPressed, isNull);
    expect(find.byKey(_pulseKey), findsNothing);
    await peer.close(tester);
  });

  testWidgets('tocar na linha nao projeta: so seleciona e faz o play pulsar', (
    tester,
  ) async {
    final peer = await _pumpConnected(tester);

    await tester.tap(find.byKey(_rowKey));
    await tester.pump();
    await _settleNetwork(tester);

    expect(peer.received, isEmpty);
    expect(tester.widget<ListTile>(find.byKey(_rowKey)).selected, isTrue);
    expect(_play(tester).onPressed, isNotNull);
    expect(find.byKey(_pulseKey), findsOneWidget);
    await peer.close(tester);
  });

  testWidgets('play abre o hino selecionado e para de pulsar', (tester) async {
    final peer = await _pumpConnected(tester);
    await tester.tap(find.byKey(_rowKey));
    await tester.pump();

    // Na zona real: o socket usado dentro do tempo simulado nunca fecharia.
    await tester.runAsync(() async => _play(tester).onPressed!());
    await tester.pump();
    await _settleNetwork(tester);

    expect(peer.received, hasLength(1));
    expect(peer.received.single, contains('42'));
    expect(find.byKey(_pulseKey), findsNothing);
    await peer.close(tester);
  });

  testWidgets('tocar de novo na linha desfaz a selecao', (tester) async {
    final peer = await _pumpConnected(tester);
    await tester.tap(find.byKey(_rowKey));
    await tester.pump();

    await tester.tap(find.byKey(_rowKey));
    await tester.pump();

    expect(tester.widget<ListTile>(find.byKey(_rowKey)).selected, isFalse);
    expect(_play(tester).onPressed, isNull);
    await peer.close(tester);
  });

  testWidgets('com projecao ativa e sem selecao, o play continua ativo', (
    tester,
  ) async {
    final peer = await _pumpConnected(tester, title: 'Hino 100');

    expect(_play(tester).onPressed, isNotNull);
    expect(find.byKey(_pulseKey), findsNothing);
    await peer.close(tester);
  });
}
