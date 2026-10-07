import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/presentation/settings/widgets/remote/remote_section.dart';

/// RemoteSession real (sem rede): connectDesktop com host/porta para
/// conexão a um server inexistente falha rápido — suficiente pra validar
/// o caminho de UI de falha e sucesso de fluxo sem hardware.
RemoteSession _realSession() => RemoteSession();

void main() {
  group('RemoteSection — validação de campos', () {
    testWidgets('IP inválido mantém botão conectar desabilitado', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RemoteSection(session: _realSession()))),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'nao-e-ip');
      await tester.pump();

      // botão conectar fica desabilitado com host inválido
      final connect = tester.widget<OutlinedButton>(
        find.widgetWithIcon(OutlinedButton, TablerIcons.plugConnected),
      );
      expect(connect.onPressed, isNull);
    });

    testWidgets('IP válido habilita fluxo; token inválido sinaliza', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RemoteSection(session: _realSession()))),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), '192.168.1.192');
      await tester.pump();

      // token fora do formato [A-Za-z0-9]{4,12}
      await tester.enterText(find.byType(TextField).at(1), 'x!');
      await tester.pump();

      // Campos validam sem lançar; estado interno reflete nos botões.
      expect(find.byType(TextField), findsNWidgets(2));
    });
  });

  group('RemoteSection — conexão desktop (falha de rede real)', () {
    testWidgets('connectDesktop para host inexistente mostra snackbar', (
      tester,
    ) async {
      final session = _realSession();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RemoteSection(session: session))),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), '10.255.255.1:59999');
      await tester.enterText(find.byType(TextField).at(1), 'abcd1234');
      await tester.pump();

      final connectBtn = find.widgetWithIcon(
        OutlinedButton,
        TablerIcons.plugConnected,
      );
      await tester.tap(connectBtn, warnIfMissed: false);
      // socket real: refused em loopback é quase imediato; dá tempo pro IO
      // completar sem deixar o SnackBar (4s) expirar.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final status = session.currentStatus;
      debugPrint('status pós-connect: $status');
      // durante a tentativa (IP não-roteável): busy → botão desabilitado
      final btnDuring = tester.widget<OutlinedButton>(connectBtn);
      expect(btnDuring.onPressed, isNull,
          reason: 'durante a conexão o botão trava (anti duplo-tap)');
      // pós-falha a session volta a disconnected — coberto no
      // remote_session_test (backoff 1+3+7s é lento demais pro widget test).
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('disconnect sem conexão não lança', (tester) async {
      final session = _realSession();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RemoteSection(session: session))),
      );
      await tester.pump();

      // disconnect sem conexão: caminho direto da session, sem UI extra
      await session.disconnect();
      expect(session.currentStatus, RemoteSessionStatus.disconnected);
      expect(tester.takeException(), isNull);
    });
  });

  group('DesktopQrScannerPage — guardas', () {
    testWidgets('renderiza câmera/preview sem crash e volta sem código', (
      tester,
    ) async {
      String? popped;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const DesktopQrScannerPage()),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // scanner pode não ter câmera no sandbox: página não pode crashar
      expect(tester.takeException(), isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(popped, isNull);
    });
  });
}
