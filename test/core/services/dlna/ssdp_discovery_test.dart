import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/ssdp_discovery.dart';

const _descXml = '<?xml version="1.0"?>\n'
    '<root xmlns="urn:schemas-upnp-org:device-1-0">\n'
    '  <device>\n'
    '    <friendlyName>TV Sala Fake</friendlyName>\n'
    '    <serviceList>\n'
    '      <service>\n'
    '        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>\n'
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
  group('SsdpDiscovery.scan — sem TV na rede', () {
    test('scan com timeout curto retorna lista (vazia em sandbox)', () async {
      final found = await SsdpDiscovery.scan(timeoutMs: 300);
      expect(found, isA<List<DlnaRenderer>>());
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('scan simultâneo não vaza erro', () async {
      final results = await Future.wait([
        SsdpDiscovery.scan(timeoutMs: 100),
        SsdpDiscovery.scan(timeoutMs: 100),
      ]);
      expect(results, hasLength(2));
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('DlnaRenderer.resolve — description XML real via HttpServer fake', () {
    HttpServer? server;
    late String base;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://127.0.0.1:${server!.port}';
      server!.listen((req) async {
        if (req.uri.path == '/desc.xml') {
          req.response.headers.set(HttpHeaders.contentTypeHeader, 'text/xml');
          req.response.add(utf8.encode(_descXml));
          await req.response.close();
        } else if (req.uri.path == '/ConnectionManager/control') {
          req.response.add(utf8.encode(
            '<s:Envelope><s:Body><u:GetProtocolInfoResponse>'
            '<Sink>png_lrg 1920x1080, jpeg_sm</Sink>'
            '</u:GetProtocolInfoResponse></s:Body></s:Envelope>',
          ));
          await req.response.close();
        } else if (req.uri.path == '/AVTransport/scpd.xml') {
          req.response.add(utf8.encode(
            '<scpd><actionList><action><name>SetAVTransportURI</name></action>'
            '<action><name>Play</name></action></actionList></scpd>',
          ));
          await req.response.close();
        } else {
          req.response.statusCode = 404;
          await req.response.close();
        }
      });
    });

    tearDown(() async {
      await server?.close(force: true);
    });

    test('resolve extrai friendlyName + controlURL + sink', () async {
      final r = DlnaRenderer(ip: '127.0.0.1', descriptionUrl: '$base/desc.xml');
      final ok = await r.resolve();

      expect(ok, isTrue);
      expect(r.friendlyName, 'TV Sala Fake');
      expect(r.avTransportControlUrl, contains('/AVTransport/control'));
      expect(r.sinkProtocols, contains('png_lrg 1920x1080'));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('resolve com XML sem AVTransport retorna false', () async {
      final bad = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      bad.listen((req) async {
        req.response.add(utf8.encode('<root><device/></root>'));
        await req.response.close();
      });

      final r = DlnaRenderer(
        ip: '127.0.0.1',
        descriptionUrl: 'http://127.0.0.1:${bad.port}/desc.xml',
      );
      final ok = await r.resolve();
      expect(ok, isFalse);
      await bad.close(force: true);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('resolve com host inacessível retorna false sem lançar', () async {
      final r = DlnaRenderer(
        ip: '127.0.0.1',
        descriptionUrl: 'http://127.0.0.1:1/desc.xml',
      );
      final ok = await r.resolve();
      expect(ok, isFalse);
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
