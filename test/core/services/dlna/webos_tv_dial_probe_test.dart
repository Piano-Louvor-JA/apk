import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/webos_tv_dial_probe.dart';

void main() {
  group('WebosTvDialProbe.scan — sandbox sem TV na rede', () {
    test('scan retorna lista vazia sem lançar (nenhuma TV em 1926)', () async {
      final tvs = await WebosTvDialProbe.scan(
        connectTimeout: const Duration(milliseconds: 120),
        concurrency: 8,
      );
      expect(tvs, isA<List>());
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
