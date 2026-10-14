import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_sender.dart';

/// Isolamento de portas em teste: `flutter test` roda arquivos em processos
/// paralelos; com portas fixas (7080/7081...) dois senders colidem
/// (`Address already in use`). Com [PalcoSender.bindEphemeralPortsForTesting]
/// o sender faz bind em porta efêmera e expõe a porta real obtida, mantendo
/// a porta configurada como identidade (slot/UI/persistência).
void main() {
  late ServerSocket heldHttp;
  late ServerSocket heldWs;
  late bool previous;

  setUp(() async {
    previous = PalcoSender.bindEphemeralPortsForTesting;
    // Simula outro processo/arquivo de teste segurando as portas "fixas".
    heldHttp = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    heldWs = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
  });

  tearDown(() async {
    PalcoSender.bindEphemeralPortsForTesting = previous;
    await heldHttp.close();
    await heldWs.close();
  });

  test(
    'com portas fixas ocupadas, start falha (comportamento de produção)',
    () async {
      PalcoSender.bindEphemeralPortsForTesting = false;
      final sender = PalcoSender(
        httpPortFixed: heldHttp.port,
        wsPortFixed: heldWs.port,
      );
      addTearDown(sender.stop);

      expect(await sender.start(), isNull);
      expect(sender.isRunning, isFalse);
    },
  );

  test(
    'bindEphemeralPortsForTesting: sobe em porta efêmera e expõe a real',
    () async {
      PalcoSender.bindEphemeralPortsForTesting = true;
      final sender = PalcoSender(
        httpPortFixed: heldHttp.port,
        wsPortFixed: heldWs.port,
      );
      addTearDown(sender.stop);

      // Antes de subir, a porta efetiva é a configurada (identidade).
      expect(sender.effectiveHttpPort, heldHttp.port);
      expect(sender.effectiveWsPort, heldWs.port);

      final base = await sender.start();
      expect(base, isNotNull, reason: 'não deve colidir com a porta fixa');
      expect(sender.isRunning, isTrue);
      expect(sender.effectiveHttpPort, isNot(heldHttp.port));
      expect(sender.effectiveWsPort, isNot(heldWs.port));
      expect(base, endsWith(':${sender.effectiveHttpPort}'));

      // A porta real responde de verdade.
      final client = HttpClient();
      addTearDown(client.close);
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:${sender.effectiveHttpPort}/status'),
      );
      final res = await req.close();
      await res.drain<void>();
      expect(res.statusCode, 200);

      // Porta configurada continua sendo a identidade após parar.
      await sender.stop();
      expect(sender.effectiveHttpPort, heldHttp.port);
      expect(sender.effectiveWsPort, heldWs.port);
    },
  );
}
