import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_page.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_liturgy_page.dart';

/// Liturgia do desktop no Controle Remoto (separada da Liturgia do apk).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sem desktop conectado mostra o aviso, mesmo com estado antigo', (
    tester,
  ) async {
    RemoteSession.instance.debugEmitStateForTest(
      const RemotePlayerState(
        playing: false,
        position: Duration.zero,
        duration: Duration.zero,
        slideIndex: 0,
        slideCount: 0,
        volume: 60,
        canPrevious: false,
        canNext: false,
        liturgyItems: [
          RemoteLiturgyItem(
            index: 0,
            type: 'music',
            title: 'Digno',
            done: false,
          ),
        ],
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: RemoteLiturgyPage()));
    await tester.pump();

    expect(find.text('remote.tabLiturgy'), findsOneWidget);
    expect(find.byKey(const Key('remote-liturgy-empty')), findsOneWidget);
    expect(find.text('remote.noLiturgy'), findsOneWidget);
    expect(find.byType(RemoteLiturgyMirror), findsNothing);
  });
}
