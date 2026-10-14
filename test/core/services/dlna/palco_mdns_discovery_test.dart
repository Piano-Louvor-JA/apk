import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/palco_mdns_discovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PalcoMdnsDiscovery.scan — sandbox sem rede multicast', () {
    test('scan curto retorna lista vazia sem lançar', () async {
      final tvs = await PalcoMdnsDiscovery.scan(timeout: const Duration(milliseconds: 400));
      expect(tvs, isA<List>());
      expect(tvs, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('scans simultâneos não vazam erro', () async {
      final results = await Future.wait([
        PalcoMdnsDiscovery.scan(timeout: const Duration(milliseconds: 200)),
        PalcoMdnsDiscovery.scan(timeout: const Duration(milliseconds: 200)),
      ]);
      expect(results, hasLength(2));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
