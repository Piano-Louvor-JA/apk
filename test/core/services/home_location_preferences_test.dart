library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/home_location_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HomeLocationPreferences', () {
    test('sem nada salvo retorna distrito e igreja vazios', () async {
      final location = await HomeLocationPreferences.load();

      expect(location.district, '');
      expect(location.church, '');
    });

    test('roundtrip: o que foi salvo volta no proximo load', () async {
      await HomeLocationPreferences.save(
        const HomeLocation(district: 'Distrito Central', church: 'Igreja Sede'),
      );

      final location = await HomeLocationPreferences.load();

      expect(location.district, 'Distrito Central');
      expect(location.church, 'Igreja Sede');
    });

    test('remove espacos das pontas ao salvar', () async {
      await HomeLocationPreferences.save(
        const HomeLocation(district: '  Norte ', church: ' Sede  '),
      );

      final location = await HomeLocationPreferences.load();

      expect(location.district, 'Norte');
      expect(location.church, 'Sede');
    });

    test('usa a mesma chave de preferencia do desktop', () async {
      await HomeLocationPreferences.save(
        const HomeLocation(district: 'Norte', church: 'Sede'),
      );

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('home.location'), isNotNull);
    });

    test('valor corrompido retorna vazio em vez de quebrar', () async {
      SharedPreferences.setMockInitialValues({'home.location': 'nao-e-json'});

      final location = await HomeLocationPreferences.load();

      expect(location.district, '');
      expect(location.church, '');
    });

    test('JSON com tipos invalidos normaliza para vazio', () async {
      SharedPreferences.setMockInitialValues({
        'home.location': '{"district":42,"church":null}',
      });

      final location = await HomeLocationPreferences.load();

      expect(location.district, '');
      expect(location.church, '');
    });
  });
}
