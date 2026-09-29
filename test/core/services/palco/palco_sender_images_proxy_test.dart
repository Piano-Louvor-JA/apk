// F3.3d: /images/<path> deve proxyar a API LouvorJA.
//
// Bug real (2026-08-18): receiver resolve covers relativos contra a origem
// (http://host:7080/images/generico_116.jpg); o handler antigo chamava
// _serveProxy sem ?url= → 400/404 → capa quebrada no Palco.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_sender.dart';

void main() {
  test(
    '/images/<path> proxya a imagem da API LouvorJA (200, image/*)',
    () async {
      final sender = PalcoSender(httpPortFixed: 0, wsPortFixed: 0);
      await sender.start();
      final port = sender.effectiveHttpPort;
      try {
        final client = HttpClient();
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/images/generico_116.jpg'),
        );
        final res = await req.close();
        final bytes = await res.fold<List<int>>([], (acc, d) => acc..addAll(d));
        expect(
          res.statusCode,
          200,
          reason: 'capa generica existe na API e deve proxyar',
        );
        expect(
          res.headers.value(HttpHeaders.contentTypeHeader),
          contains('image'),
        );
        expect(
          bytes.length,
          greaterThan(1000),
          reason: 'imagem real, nao vazia',
        );
        client.close();
      } finally {
        await sender.stop();
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('/proxy sem ?url= continua 400 (contrato preservado)', () async {
    final sender = PalcoSender(httpPortFixed: 0, wsPortFixed: 0);
    await sender.start();
    final port = sender.effectiveHttpPort;
    try {
      final client = HttpClient();
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/proxy'),
      );
      final res = await req.close();
      expect(res.statusCode, 400);
      client.close();
    } finally {
      await sender.stop();
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
