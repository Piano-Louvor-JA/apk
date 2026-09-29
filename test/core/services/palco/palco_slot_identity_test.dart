library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_slot.dart';

void main() {
  group('PalcoSlot identity', () {
    test('slot principal mantém portas 7080/7081', () {
      final slot = PalcoSlot(
        id: 'principal',
        label: 'Principal (espelho)',
        slotIndex: 0,
      );

      expect(slot.slotIndex, 0);
      expect(slot.httpPort, 7080);
      expect(slot.wsPort, 7081);
    });

    test('TV 2 mantém associação HTTP 7082 e WS 7083', () {
      final slot = PalcoSlot(id: 'tv_2', label: 'TV 2', slotIndex: 1);

      expect(slot.slotIndex, 1);
      expect(slot.httpPort, 7082);
      expect(slot.wsPort, 7083);
      expect(slot.controller.wsPort, 7083);
    });

    test('slot preservado por índice não depende da ordem de restauração', () {
      final slot = PalcoSlot(id: 'sala', label: 'TV Sala', slotIndex: 3);

      expect(slot.httpPort, 7086);
      expect(slot.wsPort, 7087);
    });
  });
}
