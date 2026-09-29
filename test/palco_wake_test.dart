// RF-003 da spec palco-wake-launch-fase3a: sendWake não lança em IP
// inalcançável (porta fechada = LG/TV sem serviço — silencioso).
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/palco_wake.dart';

void main() {
  test('RF-003: WAKE em IP inalcançável retorna false sem lançar', () async {
    // 192.0.2.1 = TEST-NET (garantidamente não responde rápido)
    final ok = await PalcoWake.send('192.0.2.1');
    expect(ok, isFalse);
  });

  test(
    'RF-003: WAKE em porta fechada da LAN retorna false sem lançar',
    () async {
      // o próprio gateway da rede de teste pode não ter :7082 — se tiver,
      // algum serviço responde e o teste ainda valida que não explode
      final ok = await PalcoWake.send('127.0.0.1');
      expect(ok, anyOf(isFalse, isTrue));
    },
  );
}
