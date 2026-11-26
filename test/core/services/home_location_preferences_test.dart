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

  group('ultimo valor conhecido (telemetria)', () {
    test(
      'digitou e apagou: o campo fica vazio, o envio usa o valor guardado',
      () async {
        await HomeLocationPreferences.save(
          const HomeLocation(district: 'Bertioga', church: 'Rio da Praia'),
        );
        await HomeLocationPreferences.save(const HomeLocation());

        final current = await HomeLocationPreferences.load();
        expect(current.district, '');
        final known = await HomeLocationPreferences.loadLastKnown();
        expect(known.district, 'Bertioga');
        expect(known.church, 'Rio da Praia');
        final reported = await HomeLocationPreferences.resolveReported();
        expect(reported.district, 'Bertioga');
        expect(reported.church, 'Rio da Praia');
      },
    );

    test(
      'com o campo preenchido vale o campo, mesmo depois de trocar',
      () async {
        await HomeLocationPreferences.save(
          const HomeLocation(district: 'Bertioga', church: 'Rio da Praia'),
        );
        await HomeLocationPreferences.save(
          const HomeLocation(district: 'Santos', church: 'Rio da Praia'),
        );
        await HomeLocationPreferences.save(
          const HomeLocation(church: 'Rio da Praia'),
        );
        final reported = await HomeLocationPreferences.resolveReported();
        expect(reported.district, 'Santos');
        expect(reported.church, 'Rio da Praia');
      },
    );

    test(
      'valor gravado antes desta versao tambem e guardado ao apagar',
      () async {
        SharedPreferences.setMockInitialValues({
          'home.location': '{"district":"Antigo","church":"IASD Antiga"}',
        });
        await HomeLocationPreferences.save(const HomeLocation());
        final reported = await HomeLocationPreferences.resolveReported();
        expect(reported.district, 'Antigo');
        expect(reported.church, 'IASD Antiga');
      },
    );

    test('sem nada digitado, nada a enviar', () async {
      final reported = await HomeLocationPreferences.resolveReported();
      expect(reported.district, '');
      expect(reported.church, '');
    });

    test('salvar avisa quem escuta (heartbeat reenviar)', () async {
      var calls = 0;
      void listener() => calls++;
      HomeLocationPreferences.savedChanges.addListener(listener);
      await HomeLocationPreferences.save(const HomeLocation(district: 'X'));
      HomeLocationPreferences.savedChanges.removeListener(listener);
      expect(calls, 1);
    });
  });
}
