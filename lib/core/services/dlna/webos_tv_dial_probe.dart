library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

/// F3.3ab: detecção de TVs webOS via HTTP unicast na porta 1926 (dd.xml).
///
/// Como o Google/Netflix identificam (a parte pública do que fazem):
/// a LG expõe a descrição UPnP em `http://<tv>:1926/` — HTTP comum, sem
/// multicast, imune a APs que bloqueiam multicast em Wi-Fi (que é exatamente
/// o que cegava o SSDP/DLNA do celular; caso real 17/08 e 19/08).
///
/// O dd.xml traz friendlyName real ("[LG] webOS TV UM751C0PSB") e
/// deviceType urn:lge:device:tv:1 — confirmação sólida de que é uma TV LG.
///
/// Launch remoto (POST /apps do DIAL) NÃO está habilitado nessa TV —
/// Netflix/YouTube têm permissão via parceria LG; terceiros não têm canal.
/// A identificação, essa sim, é 100% viável e confiável.
class WebosTvDialProbe {
  /// Varre a sub-rede /24: TCP connect na 1926 + GET / e valida deviceType.
  /// Retorna lista de TVs (ip + friendlyName).
  static Future<List<WebosTv>> scan({
    Duration connectTimeout = const Duration(milliseconds: 700),
    int concurrency = 40,
  }) async {
    final prefix = await _localSubnetPrefix();
    if (prefix == null) return [];
    debugPrint('[WEBOS-DIAL] varrendo $prefix.0/24 na porta 1926');
    final results = <WebosTv>[];
    final futures = <Future<void>>[];
    var sem = 0;
    Future<void> probeHost(String ip) async {
      try {
        final tv = await _probe(ip, connectTimeout);
        if (tv != null) {
          debugPrint('[WEBOS-DIAL] TV: $ip ${tv.friendlyName}');
          results.add(tv);
        }
      } catch (_) {
        // host sem TV: normal, silencioso
      } finally {
        sem--;
      }
    }

    for (var i = 1; i <= 254; i++) {
      final ip = '$prefix.$i';
      // gate de concorrência
      while (sem >= concurrency) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      sem++;
      futures.add(probeHost(ip));
    }
    await Future.wait(futures);
    return results;
  }

  /// GET / na 1926 e valida se é deviceType urn:lge:device:tv (webOS).
  static Future<WebosTv?> _probe(String ip, Duration timeout) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = timeout;
      final req = await client
          .getUrl(Uri.parse('http://$ip:1926/'))
          .timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      if (!body.contains('urn:lge:device:tv')) return null;
      final m = RegExp(
        r'<friendlyName>([^<]+)</friendlyName>',
      ).firstMatch(body);
      return WebosTv(
        ip: ip,
        friendlyName: (m?.group(1) ?? 'LG webOS TV').trim(),
      );
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  static Future<String?> _localSubnetPrefix() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final it in interfaces) {
        for (final addr in it.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              (addr.address.startsWith('192.168.') ||
                  addr.address.startsWith('10.') ||
                  addr.address.startsWith('172.'))) {
            return addr.address.split('.').take(3).join('.');
          }
        }
      }
    } catch (_) {}
    return null;
  }
}

class WebosTv {
  final String ip;
  final String friendlyName;
  WebosTv({required this.ip, required this.friendlyName});
}
