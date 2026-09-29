library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

/// F3.3z: detecção de TVs webOS por TCP connect-scan na porta 3001.
///
/// Por quê: o SSDP/DLNA multicast nem sempre chega no celular (APs que não
/// entregam multicast a clientes Wi-Fi — caso real 2026-08-17, e de novo em
/// 2026-08-19: TV responde ao PC/ethernet mas o app no Wi-Fi não vê nada).
/// A porta 3001 (serviço webOS) aceita conexão TCP nos dois IPs da TV e é
/// recusada em outros hosts testados (celulares, PC). Unicast TCP não
/// depende de multicast e atravessa qualquer AP.
///
/// Não substitui o SSDP (que dá friendlyName) — é o FALLBACK quando o
/// multicast falha: "tem uma TV webOS em `<ip>`" já basta pra orientar o
/// operador a abrir o Palco.
class WebosTvTcpProbe {
  /// Varre a sub-rede /24 procurando hosts com a porta 3001 aberta.
  /// Retorna o primeiro IP que aceitar conexão (resposta vazia é normal —
  /// o serviço não fala HTTP ali; o ACCEPT do TCP é o fingerprint).
  static Future<String?> scan({
    Duration timeout = const Duration(milliseconds: 600),
    int concurrency = 32,
  }) async {
    final prefix = await _localSubnetPrefix();
    if (prefix == null) return null;
    debugPrint('[WEBOS-PROBE] varrendo $prefix.0/24 na porta 3001');
    final found = Completer<String?>();
    var pending = 0;
    var next = 1;

    void checkNext() {
      while (pending < concurrency && next <= 254 && !found.isCompleted) {
        final i = next++;
        pending++;
        Socket.connect('$prefix.$i', 3001, timeout: timeout)
            .then((s) {
              debugPrint('[WEBOS-PROBE] $prefix.$i:3001 ABERTA — TV webOS!');
              s.destroy();
              if (!found.isCompleted) found.complete('$prefix.$i');
            })
            .catchError((_) {})
            .whenComplete(() {
              pending--;
              if (pending == 0 && next > 254 && !found.isCompleted) {
                found.complete(null);
              }
              checkNext();
            });
      }
    }

    checkNext();
    return found.future;
  }

  /// Mesmo prefixo /24 do SSDP discovery (interface Wi-Fi do aparelho).
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
