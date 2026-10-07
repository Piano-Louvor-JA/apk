import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/remote/unified_qr_scanner.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('P2pPairingFromScanPage — offer inválida', () {
    testWidgets('JSON quebrado mostra estado de erro sem crash', (tester) async {
      await tester.pumpWidget(
        _wrap(const P2pPairingFromScanPage(offerJson: '{quebrado')),
      );
      await tester.pump();
      // negocia e falha: aceitaOffer de oferta inválida → null → log de erro
      await tester.pump(const Duration(seconds: 1));

      // página inte renderizada (hint + spinner/estado)
      expect(find.textContaining('liturgy.p2p'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SDP vazio não crasha — fica negociando ou erro', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const P2pPairingFromScanPage(
            offerJson: '{"type":"offer","sdp":""}',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
    });
  });

  group('UnifiedQrScanner — smoke', () {
    testWidgets('renderiza câmera sem crash em sandbox (sem permissão)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const UnifiedQrScanner()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // câmera pode falhar silenciosa no sandbox; a tela não pode crashar
      expect(tester.takeException(), isNull);
    });
  });
}
