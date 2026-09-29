library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting, debugPrint;

/// Cliente SOAP do AVTransport DLNA — projeta conteúdo na TV.
///
/// Sequência VALIDADA na LG 50UM7510PSB real (PoC 2026-08-16):
/// SetAVTransportURI (com DIDL-Lite; sem ele a TV não baixa) → Play.
/// PNG e JPEG ambos aceitos nessa TV; JPEG é o fallback universal
/// para sinks DMR-1.0 que não declaram PNG.
class DlnaRendererClient {
  final String controlUrl;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  /// Último erro de SOAP (diagnóstico): ex. 'timeout', 'HTTP 500: ...'.
  String? lastError;

  DlnaRendererClient(this.controlUrl);

  Future<bool> _soap(String action, String body) async {
    lastError = null;
    try {
      final req = await _client.postUrl(Uri.parse(controlUrl));
      req.headers.set('Content-Type', 'text/xml; charset="utf-8"');
      req.headers.set(
        'SOAPACTION',
        '"urn:schemas-upnp-org:service:AVTransport:1#$action"',
      );
      req.write(body);
      final res = await req.close();
      final responseBody = await res.transform(const Utf8Decoder()).join();
      debugPrint(
        '[DLNA] SOAP $action -> HTTP ${res.statusCode} '
        '(${responseBody.length} bytes)',
      );
      if (res.statusCode != 200) {
        lastError =
            'HTTP ${res.statusCode}: ${responseBody.substring(0, responseBody.length.clamp(0, 200))}';
        return false;
      }
      return true;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[DLNA] SOAP $action falhou: $e');
      return false;
    }
  }

  /// Manda a TV exibir [imageUrl] (PNG ou JPEG conforme o sink aceita).
  Future<bool> projectImage(
    String imageUrl, {
    String title = 'Slide',
    bool jpeg = false,
  }) async {
    final didl = _didlImage(imageUrl, title, jpeg: jpeg);
    final set = await _soap(
      'SetAVTransportURI',
      _envelope('''
<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
<InstanceID>0</InstanceID>
<CurrentURI>$imageUrl</CurrentURI>
<CurrentURIMetaData>${_xmlEscape(didl)}</CurrentURIMetaData>
</u:SetAVTransportURI>'''),
    );
    if (!set) return false;
    return _soap(
      'Play',
      _envelope('''
<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
<InstanceID>0</InstanceID><Speed>1</Speed>
</u:Play>'''),
    );
  }

  Future<bool> stop() => _soap(
    'Stop',
    _envelope('''
<u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
<InstanceID>0</InstanceID>
</u:Stop>'''),
  );

  /// DIDL-Lite mínimo que a LG aceita para imagem (descoberta no PoC).
  @visibleForTesting
  static String didlImageFor(String url, String title, {bool jpeg = false}) =>
      _didlImage(url, title, jpeg: jpeg);

  static String _didlImage(String url, String title, {bool jpeg = false}) {
    final pn = jpeg ? 'JPEG_LRG' : 'PNG_LRG';
    final mime = jpeg ? 'image/jpeg' : 'image/png';
    return '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
        '<item id="1" parentID="0" restricted="1">'
        '<dc:title>${_xmlEscape(title)}</dc:title>'
        '<upnp:class>object.item.imageItem</upnp:class>'
        '<res protocolInfo="http-get:*:$mime:DLNA.ORG_PN=$pn">$url</res>'
        '</item></DIDL-Lite>';
  }

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _envelope(String body) =>
      '<?xml version="1.0" encoding="utf-8"?>'
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
      's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
      '<s:Body>$body</s:Body></s:Envelope>';

  void dispose() => _client.close();
}
