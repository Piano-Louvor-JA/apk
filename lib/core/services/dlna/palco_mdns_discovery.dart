library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:multicast_dns/multicast_dns.dart';

import 'multicast_lock.dart';
import 'webos_tv_dial_probe.dart' show WebosTv;

/// F3.4 fase 2: descoberta de receivers Palco via mDNS (`_palco._tcp`).
///
/// O receiver Android TV anuncia o serviço via NSD (bonsoir) com TXT
/// `role=receiver`. Este detector escuta a rede por 2s e resolve
/// PTR → SRV → TXT → A, retornando nome amigável + IP.
///
/// Fallback mantido: se mDNS não achar (rede bloqueando multicast — caso
/// real em Wi-Fi de igreja), o chamador usa WebosTvDialProbe (HTTP 1926).
class PalcoMdnsDiscovery {
  /// Varre por serviços `_palco._tcp` na rede local.
  /// Retorna receivers com `role=receiver` no TXT, dedup por IP.
  static Future<List<WebosTv>> scan({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    await MulticastLock.acquire();
    try {
      final client = MDnsClient();
      await client.start();
      try {
        final results = <String, WebosTv>{};

        await for (final ptr in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer('_palco._tcp.local'),
          timeout: timeout,
        )) {
          final serviceName = ptr.domainName;
          debugPrint('[MDNS] PTR: $serviceName');
          final tv = await _resolve(client, serviceName);
          if (tv != null) {
            results.putIfAbsent(tv.ip, () => tv); // RF-005: dedup por IP
          }
        }
        return results.values.toList();
      } finally {
        client.stop();
      }
    } catch (e) {
      debugPrint('[MDNS] scan falhou (não bloqueia): $e');
      return [];
    } finally {
      await MulticastLock.release();
    }
  }

  /// Resolve um serviço: SRV (target) + TXT (role) + A (ip).
  static Future<WebosTv?> _resolve(
    MDnsClient client,
    String serviceName,
  ) async {
    // TXT: filtra role=receiver (RF-004)
    var isReceiver = false;
    await for (final txt in client.lookup<TxtResourceRecord>(
      ResourceRecordQuery.text(serviceName),
      timeout: const Duration(milliseconds: 800),
    )) {
      if (txt.text.contains('role=receiver')) {
        isReceiver = true;
        break;
      }
    }
    if (!isReceiver) return null;

    // SRV: pega o hostname target
    String? target;
    await for (final srv in client.lookup<SrvResourceRecord>(
      ResourceRecordQuery.service(serviceName),
      timeout: const Duration(milliseconds: 800),
    )) {
      target = srv.target;
      break;
    }
    if (target == null) return null;

    // A: resolve IP
    await for (final addr in client.lookup<IPAddressResourceRecord>(
      ResourceRecordQuery.addressIPv4(target),
      timeout: const Duration(milliseconds: 800),
    )) {
      final ip = addr.address.address;
      final name = _friendlyName(serviceName);
      debugPrint('[MDNS] receiver: $name @ $ip');
      return WebosTv(ip: ip, friendlyName: name);
    }
    return null;
  }

  /// `Palco AndroidTV._palco._tcp.local` → `Palco AndroidTV`.
  static String _friendlyName(String serviceName) {
    final label = serviceName.split('._palco._tcp').first;
    return label.isEmpty ? 'Palco' : label;
  }
}
