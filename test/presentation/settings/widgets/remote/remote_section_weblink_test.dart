import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/presentation/settings/widgets/remote/remote_section.dart';

/// Painel ativo da RemoteSection via WebLinkServer REAL em loopback:
/// modo web + status listening + QR + URL clicável + desconectar.
/// Usa runAsync p/ IO real do HttpServer (binding de porta).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSection(WidgetTester tester, RemoteSession session) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: RemoteSection(session: session))),
    );
    await tester.pump();
  }

  testWidgets('Web Link real: painel ativo com URL e desconectar volta ao idle',
      (tester) async {
    final session = RemoteSession();
    addTearDown(() => session.disconnect());

    await pumpSection(tester, session);
    await tester.pump();

    // caminho real: o BOTÃO Web Link chama _startWebLink → _webUrl no state
    await tester.tap(find.byKey(const Key('remote-weblink')));
    // startWebLink faz IO real (HttpServer.bind) — runAsync deixa completar
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();

    final disc = find.byKey(const Key('remote-disconnect'));
    expect(disc, findsOneWidget, reason: 'painel ativo deve ter desconectar');

    var urlWidget = find.byKey(const Key('remote-weblink-url'));
    for (var i = 0; i < 20 && urlWidget.evaluate().isEmpty; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      urlWidget = find.byKey(const Key('remote-weblink-url'));
    }
    expect(urlWidget.evaluate().isNotEmpty, isTrue,
        reason: 'painel web listening deve exibir a URL');
    expect(
      tester
          .widget<Text>(find
              .descendant(of: urlWidget, matching: find.byType(Text))
              .first)
          .data,
      anyOf(contains('127.0.0.1'), contains('?t=')),
    );

    // desconectar pelo botão volta ao idle (campos host/token reaparecem)
    await tester.tap(disc);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(session.mode, RemoteMode.idle);
    expect(find.byKey(const Key('remote-host')), findsOneWidget);
  });

}
