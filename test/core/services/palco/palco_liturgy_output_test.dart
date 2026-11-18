import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_sender.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_models.dart';

class Sender extends PalcoSender {
  final sent = <PalcoMessage>[];
  @override
  void send(PalcoMessage message) => sent.add(message);
}

void main() {
  test(
    'saída independente usa o protocolo existente do receiver e libera ao fechar',
    () {
      final sender = Sender();
      final controller = PalcoController(sender: sender);
      controller.sendLiturgyMessage(
        PalcoMessage.projection(text: 'Santo'),
        share: true,
      );
      expect(sender.sent.last.fields['obsPane'], true);
      expect(sender.sent.last.fields['text'], 'Santo');
      controller.setLiturgyShare(true);
      expect(sender.sent.last.toJson(), containsPair('enabled', true));
      controller.setLiturgyShare(false);
      expect(sender.sent.last.toJson(), containsPair('enabled', false));
      controller.sendLiturgyMessage(
        const PalcoMessage(
          type: 'video',
          fields: {'action': 'seek', 'positionMs': 15000},
        ),
      );
      expect(sender.sent.last.fields['positionMs'], 15000);
      expect(sender.sent.last.fields['obsPane'], false);
    },
  );
}
