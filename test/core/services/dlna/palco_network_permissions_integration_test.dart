import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// Smoke tests dos transportes no host que executa flutter test.
/// Não comprovam permissões Android nem descoberta/pareamento com uma TV.
void main() {
  group('apk#90 - transportes de descoberta local no host', () {
    test('multicast_dns inicia e encerra sem esconder falhas', () async {
      final client = MDnsClient();
      try {
        await client.start();
      } finally {
        client.stop();
      }
    });

    test('HTTP recebe uma resposta real no loopback', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final responseSent = server.first.then((request) async {
        request.response.write('dial-smoke');
        await request.response.close();
      });
      try {
        final request = await client.getUrl(
          Uri.http('127.0.0.1:${server.port}', '/'),
        );
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        expect(await response.transform(SystemEncoding().decoder).join(),
            'dial-smoke');
        await responseSent;
      } finally {
        client.close(force: true);
        await server.close(force: true);
      }
    });
  });
}
