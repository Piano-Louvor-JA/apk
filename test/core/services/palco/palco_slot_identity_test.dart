library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_slot.dart';

void main() {
  group('PalcoSlot identity', () {
    test('slot principal mantém portas 4980/4981', () {
      final slot = PalcoSlot(
        id: 'principal',
        label: 'Principal (espelho)',
        slotIndex: 0,
      );

      expect(slot.slotIndex, 0);
      expect(slot.httpPort, 4980);
      expect(slot.wsPort, 4981);
    });

    test('TV 2 mantém associação HTTP 4982 e WS 4983', () {
      final slot = PalcoSlot(id: 'tv_2', label: 'TV 2', slotIndex: 1);

      expect(slot.slotIndex, 1);
      expect(slot.httpPort, 4982);
      expect(slot.wsPort, 4983);
      expect(slot.controller.wsPort, 4983);
    });

    test('slot preservado por índice não depende da ordem de restauração', () {
      final slot = PalcoSlot(id: 'sala', label: 'TV Sala', slotIndex: 3);

      expect(slot.httpPort, 4986);
      expect(slot.wsPort, 4987);
    });

    test('representação mostra identidade e portas do slot', () {
      final slot = PalcoSlot(id: 'sala', label: 'TV Sala', slotIndex: 2);
      slot.label = 'TV Sala Nova';

      expect(slot.toString(), 'PalcoSlot(sala, TV Sala Nova, ports 4984/4985)');
    });
  });
}
