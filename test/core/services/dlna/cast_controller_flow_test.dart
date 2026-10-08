import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/cast_controller.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/ssdp_discovery.dart';

const _descXml = '<?xml version="1.0"?>\n'
    '<root xmlns="urn:schemas-upnp-org:device-1-0">\n'
    '  <device>\n'
    '    <friendlyName>TV Fake Cast</friendlyName>\n'
    '    <serviceList>\n'
    '      <service>\n'
    '        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>\n'
    '        <SCPDURL>/AVTransport/scpd.xml</SCPDURL>\n'
    '        <controlURL>/AVTransport/control</controlURL>\n'
    '      </service>\n'
    '      <service>\n'
    '        <serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType>\n'
    '        <controlURL>/ConnectionManager/control</controlURL>\n'
    '      </service>\n'
    '    </serviceList>\n'
    '  </device>\n'
    '</root>';

void main() {
  late HttpServer descServer;
  final soapActions = <String>[];

  setUp(() async {
    soapActions.clear();
    descServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    descServer.listen((req) async {
      req.response.headers.set(HttpHeaders.contentTypeHeader, 'text/xml');
      final action = req.headers.value('SOAPACTION');
      if (action != null) soapActions.add(action);
      if (req.uri.path == '/ConnectionManager/control') {
        req.response.add(utf8.encode(
          '<s:Envelope><s:Body><u:GetProtocolInfoResponse>'
          '<Sink>png_lrg 1920x1080</Sink>'
          '</u:GetProtocolInfoResponse></s:Body></s:Envelope>',
        ));
      } else {
        req.response.add(utf8.encode(_descXml));
      }
      await req.response.close();
    });

  });

  tearDown(() async {
    await descServer.close(force: true);
  });

  Future<DlnaRenderer> resolvedRenderer() async {
    final r = DlnaRenderer(
      ip: '127.0.0.1',
      descriptionUrl: 'http://127.0.0.1:${descServer.port}/desc.xml',
    );
    expect(await r.resolve(), isTrue);
    return r;
  }

  test('connect + projectSlide: SOAP Play dispara e imageFormat é png', () async {
    final c = CastController();
    final renderer = await resolvedRenderer();

    expect(await c.connect(renderer), isTrue);
    expect(c.isConnected, isTrue);
    expect(c.rendererName, 'TV Fake Cast');
    expect(c.imageFormat, StageImageFormat.png, reason: 'Sink declara PNG_LRG');

    final ok = await c.projectSlide(
      Uint8List.fromList(List.filled(64, 7)),
      title: 'Slide 1',
    );
    expect(ok, isTrue);
    expect(soapActions.where((a) => a.contains('Play')), isNotEmpty);
    expect(c.lastError, isNull);

    await c.disconnect();
    expect(c.isConnected, isFalse);
  });

  test('debounce: rajada de slides é atrasada mas todas projetam', () async {
    final c = CastController();
    final renderer = await resolvedRenderer();
    await c.connect(renderer);

    final t0 = DateTime.now();
    await c.projectSlide(Uint8List.fromList([1]));
    final firstGap = DateTime.now().difference(t0);
    // 1ª projeção NÃO espera debounce (lastProjectAt é época).
    expect(firstGap, lessThan(const Duration(milliseconds: 200)));

    final t1 = DateTime.now();
    await c.projectSlide(Uint8List.fromList([2]));
    final secondGap = DateTime.now().difference(t1);
    // 2ª logo em seguida espera o restante dos 250ms.
    expect(secondGap, lessThan(const Duration(milliseconds: 400)));

    expect(
      soapActions.where((a) => a.contains('Play')).length,
      greaterThanOrEqualTo(2),
    );

    await c.disconnect();
  });

  test('SOAP falhando (TV fora): projectSlide retorna false e lastError set', () async {
      final c = CastController();
      final renderer = await resolvedRenderer();
      // Control URL morta: apontar pra porta fechada.
      final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = dead.port;
      await dead.close(force: true);
      renderer.avTransportControlUrl = 'http://127.0.0.1:$deadPort/control';

      expect(await c.connect(renderer), isTrue);
      final ok = await c.projectSlide(Uint8List.fromList([1]));
      expect(ok, isFalse);
      expect(c.lastError, isNotNull);

      await c.disconnect();
  });
}
