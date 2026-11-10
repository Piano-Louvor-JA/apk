import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_control_tool_page.dart';

const _muteKey = Key('remote-mute');

/// Conexao real em loopback; retorna os comandos recebidos pelo browser fake.
Future<List<String>> _pumpConnected(WidgetTester tester) async {
  final session = RemoteSession.instance;
  final received = <String>[];
  late WebSocket browser;
  await tester.runAsync(() async {
    final url = await session.startWebLink(token: 'MUTE1');
    browser = await WebSocket.connect(url!);
    browser.listen((data) {
      if (data is String && data.contains('player.setVolume'))
        received.add(data);
    });
    session.debugInjectStateForTest(title: 'Digno', playing: true, volume: 60);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  // Roda tambem quando o teste falha: socket aberto prenderia o processo.
  addTearDown(() async {
    await browser.close();
    await session.disconnect();
  });
  await tester.pumpWidget(const MaterialApp(home: RemoteControlToolPage()));
  await tester.pump();
  // A barra do player fica na aba Hinos; a Liturgia só escolhe o dia.
  await tester.tap(find.text('remote.tabHymns'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  await tester.tap(find.byKey(const Key('remote-volume-button')));
  await tester.pump();
  await tester.pump();
  return received;
}

IconButton _mute(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(_muteKey));

/// Aciona o botao na zona real, onde o socket funciona, e aguarda a rede.
Future<void> _pressMute(WidgetTester tester) async {
  await tester.runAsync(() async {
    _mute(tester).onPressed!();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
}

Future<void> _desktopReports(WidgetTester tester, int volume) async {
  RemoteSession.instance.debugInjectStateForTest(
    title: 'Digno',
    playing: true,
    volume: volume,
  );
  // Entrega o evento do stream, desenha a barra e atualiza a sobreposicao.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

IconData? _icon(WidgetTester tester) => (_mute(tester).icon as Icon).icon;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('barra de volume nao tem icone a direita', (tester) async {
    await _pumpConnected(tester);

    expect(find.byIcon(TablerIcons.volume2), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tocar no icone esquerdo zera o volume', (tester) async {
    final received = await _pumpConnected(tester);
    expect(_icon(tester), TablerIcons.volume);

    await _pressMute(tester);

    expect(received.single, contains('"value":0'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mudo mostra icone cortado e volta ao volume anterior', (
    tester,
  ) async {
    final received = await _pumpConnected(tester);
    await _pressMute(tester);
    await _desktopReports(tester, 0);
    expect(_icon(tester), TablerIcons.volumeOff);

    await _pressMute(tester);

    expect(received.last, contains('"value":60'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('volume ja zerado sem historico volta ao maximo', (tester) async {
    final received = await _pumpConnected(tester);
    await _desktopReports(tester, 0);

    await _pressMute(tester);

    expect(received.single, contains('"value":100'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
