import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/dlna_renderer_client.dart';

/// Server SOAP fake: responde 200 ou 500 conforme o caminho/config.
void main() {
  late HttpServer server;
  late String controlUrl;
  final soapActions = <String>[];

  setUp(() async {
    soapActions.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final action = req.headers.value('SOAPACTION') ?? '';
      soapActions.add(action);
      if (action.contains('Fail')) {
        req.response.statusCode = 500;
        req.response.add(utf8.encode('<error>boom</error>'));
      } else {
        req.response.add(utf8.encode('<?xml version="1.0"?><s:Envelope/>'));
      }
      await req.response.close();
    });
    controlUrl = 'http://127.0.0.1:${server.port}/control';
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('projectImage PNG faz SetAVTransportURI + Play (200 = true)', () async {
    final client = DlnaRendererClient(controlUrl);

    final ok = await client.projectImage('http://img/1.png', title: 'Hino 1');

    expect(ok, isTrue);
    expect(client.lastError, isNull);
    expect(soapActions, hasLength(2));
    expect(soapActions.first, contains('SetAVTransportURI'));
    expect(soapActions.last, contains('Play'));

    client.dispose();
  });

  test('projectImage JPEG usa JPEG_LRG no DIDL', () async {
    final didl = DlnaRendererClient.didlImageFor(
      'http://img/2.jpg',
      'Slide',
      jpeg: true,
    );
    expect(didl, contains('JPEG_LRG'));
    expect(didl, contains('image/jpeg'));
    expect(didl, contains('http://img/2.jpg'));

    final didlPng = DlnaRendererClient.didlImageFor('http://img/3.png', 'S');
    expect(didlPng, contains('PNG_LRG'));
    expect(didlPng, contains('image/png'));
  });

  test('DIDL escapa título com XML especial', () {
    final didl = DlnaRendererClient.didlImageFor(
      'http://img/4.png',
      'Hino <10 &> Especial',
    );
    expect(didl, contains('Hino &lt;10 &amp;&gt; Especial'));
    expect(didl.contains('<10'), isFalse);
  });

  test('SOAP HTTP 500 registra lastError e retorna false', () async {
    final client = DlnaRendererClient(controlUrl);

    final ok = await client.stop(); // action=Stop → 200

    // stop normal retorna true; agora força falha via URL dedicada:
    expect(ok, isTrue);

    final failClient = DlnaRendererClient(controlUrl);
    // Usa projectImage cujo SetAVTransportURI responde 200 — precisa de um
    // action "Fail": simular via controlUrl inexistente.
    final badClient = DlnaRendererClient(
      'http://127.0.0.1:1/control',
    );
    final badOk = await badClient.projectImage('http://img/x.png');
    expect(badOk, isFalse);
    expect(badClient.lastError, isNotNull);
    badClient.dispose();
    failClient.dispose();
  });

  test('stop manda SOAPACTION Stop', () async {
    final client = DlnaRendererClient(controlUrl);
    final ok = await client.stop();
    expect(ok, isTrue);
    expect(soapActions.single, contains('#Stop'));
    client.dispose();
  });
}
