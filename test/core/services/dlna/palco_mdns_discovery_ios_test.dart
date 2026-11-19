import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/palco_mdns_discovery.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/webos_tv_dial_probe.dart'
    show WebosTv;

/// iOS: descoberta via Bonjour nativo (sem entitlement de multicast).
void main() {
  tearDown(() {
    PalcoMdnsDiscovery.debugIsIOS = null;
    PalcoMdnsDiscovery.debugBonjourScan = null;
  });

  test('no iOS usa a varredura Bonjour', () async {
    PalcoMdnsDiscovery.debugIsIOS = true;
    Duration? got;
    PalcoMdnsDiscovery.debugBonjourScan = (timeout) async {
      got = timeout;
      return [WebosTv(ip: '192.168.0.20', friendlyName: 'Palco Sala')];
    };

    final tvs = await PalcoMdnsDiscovery.scan(
      timeout: const Duration(seconds: 3),
    );

    expect(got, const Duration(seconds: 3));
    expect(tvs.single.ip, '192.168.0.20');
  });

  test('falha do Bonjour não quebra a busca', () async {
    PalcoMdnsDiscovery.debugIsIOS = true;
    PalcoMdnsDiscovery.debugBonjourScan = (_) async => throw Exception('x');
    expect(await PalcoMdnsDiscovery.scan(), isEmpty);
  });

  group('receiverFromBonjour', () {
    test('role=receiver com IPv4 → receiver', () async {
      final tv = await PalcoMdnsDiscovery.receiverFromBonjour(
        name: 'Palco Sala',
        attributes: const {'role': 'receiver'},
        hostAddresses: const ['fe80::1', '192.168.0.20'],
      );
      expect(tv?.ip, '192.168.0.20');
      expect(tv?.friendlyName, 'Palco Sala');
    });

    test('sem role=receiver → null', () async {
      expect(
        await PalcoMdnsDiscovery.receiverFromBonjour(
          name: 'Outro',
          attributes: const {'role': 'sender'},
          hostAddresses: const ['192.168.0.20'],
        ),
        isNull,
      );
    });

    test('sem endereço resolve pelo hostname', () async {
      final tv = await PalcoMdnsDiscovery.receiverFromBonjour(
        name: '',
        attributes: const {'role': 'receiver'},
        hostAddresses: const [],
        hostname: 'tv.local',
        lookup: (_) async => [InternetAddress('192.168.0.30')],
      );
      expect(tv?.ip, '192.168.0.30');
      expect(tv?.friendlyName, 'Palco');
    });

    test('hostname que não resolve → null', () async {
      final tv = await PalcoMdnsDiscovery.receiverFromBonjour(
        name: 'X',
        attributes: const {'role': 'receiver'},
        hostAddresses: const [],
        hostname: 'tv.local',
        lookup: (_) async => throw const SocketException('nope'),
      );
      expect(tv, isNull);
    });
  });
}
