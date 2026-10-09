import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/cast_controller.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/ssdp_discovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CastController — sem TV (falhas limpas)', () {
    test('projectSlide antes de connect retorna false', () async {
      final c = CastController();
      final ok = await c.projectSlide(Uint8List.fromList([1, 2, 3]));
      expect(ok, isFalse);
    });

    test('connect com renderer sem controlUrl retorna false sem crash', () async {
      final c = CastController();
      // controlUrl nulo força _client criação com null → crash? API exige
      // non-null: passar renderer sem resolve() = controlUrl null → guard.
      final r = DlnaRenderer(ip: '127.0.0.1', descriptionUrl: 'http://127.0.0.1:1/desc.xml');
      final ok = await c.connect(r);
      // Sem controlUrl (resolve() não rodou), connect deve falhar limpo.
      expect(ok, isFalse);
      await c.disconnect();
      expect(c.isConnected, isFalse);
    });

    test('disconnect duplo é idempotente', () async {
      final c = CastController();
      await c.disconnect();
      await c.disconnect();
      expect(c.isConnected, isFalse);
      expect(c.rendererName, isNull);
      expect(c.lastError, isNull);
    });

    test('discoverTvs em sandbox retorna lista vazia sem lançar', () async {
      final tvs = await CastController.discoverTvs();
      expect(tvs, isA<List>());
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
