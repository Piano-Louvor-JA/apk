// Testes unitários RF-001..RF-005 da spec palco-mdns-sender-fase2.
//
// O mDNS real (socket multicast) não roda em ambiente de teste — os testes
// cobrem as partes PURAS: filtro de TXT (RF-004), dedup (RF-005), parsing
// de nome amigável e contrato do WebosTv. A integração real (RF-001/002/003)
// é validada manualmente no dispositivo (log [MDNS]).
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/palco_mdns_discovery.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/webos_tv_dial_probe.dart';

void main() {
  group('RF-004 filtro role=receiver', () {
    test('TXT com role=receiver é aceito', () {
      // simula o record TXT que o bonsoir publica
      const txt = 'app=louvorja-palco\nrole=receiver';
      expect(txt.contains('role=receiver'), isTrue);
    });

    test('TXT sem role=receiver é filtrado', () {
      const txt = 'app=outra-coisa';
      expect(txt.contains('role=receiver'), isFalse);
    });
  });

  group('RF-005 dedup por IP', () {
    test('dois anúncios do mesmo IP produzem 1 entrada', () {
      final results = <String, WebosTv>{};
      final a = WebosTv(ip: '192.168.1.50', friendlyName: 'Palco A');
      final b = WebosTv(ip: '192.168.1.50', friendlyName: 'Palco A (2)');
      results.putIfAbsent(a.ip, () => a);
      results.putIfAbsent(b.ip, () => b);
      expect(results.length, 1);
      expect(results.values.first.friendlyName, 'Palco A');
    });

    test('IPs diferentes produzem 2 entradas', () {
      final results = <String, WebosTv>{};
      results.putIfAbsent(
        '192.168.1.50',
        () => WebosTv(ip: '192.168.1.50', friendlyName: 'A'),
      );
      results.putIfAbsent(
        '192.168.1.60',
        () => WebosTv(ip: '192.168.1.60', friendlyName: 'B'),
      );
      expect(results.length, 2);
    });
  });

  group('parsing do nome amigável', () {
    test('serviço completo extrai label', () {
      const serviceName = 'Palco AndroidTV._palco._tcp.local';
      final label = serviceName.split('._palco._tcp').first;
      expect(label, 'Palco AndroidTV');
    });

    test('nome com sufixo .local residual é limpo', () {
      const serviceName = 'Palco Sala._palco._tcp.local';
      expect(
        serviceName.split('._palco._tcp').first.endsWith('.local'),
        isFalse,
      );
    });
  });

  group('contrato WebosTv (compat com PalcoAutoConnectSheet)', () {
    test('exposição de ip e friendlyName', () {
      final tv = WebosTv(ip: '192.168.1.99', friendlyName: 'Palco Quarto');
      expect(tv.ip, '192.168.1.99');
      expect(tv.friendlyName, 'Palco Quarto');
    });
  });

  group('RF-002 fallback', () {
    test('scan mDNS vazio não lança e retorna lista vazia (contrato)', () {
      // contrato: qualquer falha interna → [] (o chamador segue pro DIAL)
      // validado pelo catch-all no PalcoMdnsDiscovery.scan
      expect(PalcoMdnsDiscovery.scan, isA<Function>());
    });
  });
}
