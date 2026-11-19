library;

import 'dart:async';
import 'dart:io' show InternetAddress, InternetAddressType, Platform;

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
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
///
/// iOS: o `MDnsClient` abre socket multicast cru, que no iOS 14+ só funciona
/// com o entitlement `com.apple.developer.networking.multicast` (pedido à
/// Apple). Por isso no iOS a varredura usa o Bonjour nativo (bonsoir →
/// NWBrowser), que só precisa de `NSBonjourServices` no Info.plist.
class PalcoMdnsDiscovery {
  /// Teste: força o caminho iOS (null = Platform.isIOS).
  @visibleForTesting
  static bool? debugIsIOS;

  /// Teste: substitui a varredura Bonjour nativa.
  @visibleForTesting
  static Future<List<WebosTv>> Function(Duration timeout)? debugBonjourScan;

  /// Varre por serviços `_palco._tcp` na rede local.
  /// Retorna receivers com `role=receiver` no TXT, dedup por IP.
  static Future<List<WebosTv>> scan({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (debugIsIOS ?? Platform.isIOS) {
      try {
        return await (debugBonjourScan ?? _scanBonjour)(timeout);
      } catch (e) {
        debugPrint('[MDNS] bonjour falhou (não bloqueia): $e');
        return [];
      }
    }
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

  /// iOS: Bonjour nativo (NWBrowser). Resolve cada serviço achado e filtra
  /// `role=receiver`, igual ao caminho multicast.
  static Future<List<WebosTv>> _scanBonjour(Duration timeout) async {
    final discovery = BonsoirDiscovery(type: '_palco._tcp');
    await discovery.initialize();
    final results = <String, WebosTv>{};
    final pending = <Future<void>>[];
    final sub = discovery.eventStream!.listen((event) {
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          event.service.resolve(discovery.serviceResolver);
        case BonsoirDiscoveryServiceResolvedEvent():
          final service = event.service;
          pending.add(
            receiverFromBonjour(
              name: service.name,
              attributes: service.attributes,
              hostAddresses: service.hostAddresses,
              hostname: service.hostname,
            ).then((tv) {
              if (tv != null) results.putIfAbsent(tv.ip, () => tv);
            }),
          );
        default:
          break;
      }
    });
    try {
      await discovery.start();
      await Future<void>.delayed(timeout);
      await Future.wait(pending);
    } finally {
      await sub.cancel();
      await discovery.stop();
    }
    return results.values.toList();
  }

  /// Converte um serviço Bonjour resolvido em receiver (null se não for
  /// `role=receiver` ou se não houver IPv4). Usa o hostname só se o sistema
  /// não devolveu endereço.
  @visibleForTesting
  static Future<WebosTv?> receiverFromBonjour({
    required String name,
    required Map<String, String> attributes,
    required List<String> hostAddresses,
    String? hostname,
    Future<List<InternetAddress>> Function(String host)? lookup,
  }) async {
    if (attributes['role'] != 'receiver') return null;
    String? ip = hostAddresses.cast<String?>().firstWhere(
      (a) => InternetAddress.tryParse(a!)?.type == InternetAddressType.IPv4,
      orElse: () => null,
    );
    if (ip == null && hostname != null && hostname.isNotEmpty) {
      try {
        final found = await (lookup ?? InternetAddress.lookup)(hostname);
        ip = found
            .where((a) => a.type == InternetAddressType.IPv4)
            .map((a) => a.address)
            .firstOrNull;
      } catch (_) {
        ip = null;
      }
    }
    if (ip == null) return null;
    debugPrint('[MDNS] receiver (bonjour): $name @ $ip');
    return WebosTv(ip: ip, friendlyName: name.isEmpty ? 'Palco' : name);
  }

  /// `Palco AndroidTV._palco._tcp.local` → `Palco AndroidTV`.
  static String _friendlyName(String serviceName) {
    final label = serviceName.split('._palco._tcp').first;
    return label.isEmpty ? 'Palco' : label;
  }
}
