import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/data/repositories/local_liturgy_media_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import '../../core/services/palco/palco_controller_test.dart' show FakeReceiver;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'player local projeta HTML no receiver e compartilha sem conexão desktop',
    () async {
      SharedPreferences.setMockInitialValues({});
      final palco = PalcoOrchestrator.instance;
      const id = 'local-integration';
      expect(
        palco.addSlot(
          id: id,
          label: 'TV de teste',
          slotIndex: 0,
          persist: false,
        ),
        true,
      );
      final controller = palco.slot(id)!.controller;
      final receiver = FakeReceiver();
      final media = LocalLiturgyMediaImpl();
      addTearDown(() async {
        await media.dispose();
        await receiver.close();
        await palco.removeSlot(id);
      });
      await controller.connect(
        const PalcoTarget(name: 'TV de teste', ip: '127.0.0.1'),
      );
      await receiver.connect('127.0.0.1', controller.wsPort);
      Future<void> flush() async =>
          Future<void>.delayed(const Duration(milliseconds: 100));
      await flush();
      receiver.received.clear();
      await media.open(
        const LiturgyItem(
          id: 'text',
          type: LiturgyItemType.annotation,
          name: 'Culto',
          notesHtml: '<b>Santo</b>',
          titleColor: '#ffee58',
        ),
        'pt',
        DateTime(2026),
      );
      await flush();
      expect(
        receiver.received.where((m) => m['type'] == 'projection'),
        isEmpty,
      );
      await media.send(
        RemoteCommand(
          id: 'project',
          action: RemoteAction.videoToggleProjection,
        ),
      );
      await flush();
      final projection = receiver.received.lastWhere(
        (m) => m['type'] == 'projection',
      );
      expect(projection['text'], contains('<b>Santo</b>'));
      expect(projection['text'], contains('#ffee58'));
      expect(media.snapshot.videoControls!.projecting, true);
      await media.send(
        RemoteCommand(
          id: 'mode',
          action: RemoteAction.videoSetIndependentMode,
          mode: 'share',
        ),
      );
      await media.send(
        RemoteCommand(
          id: 'target',
          action: RemoteAction.videoSetIndependentTarget,
          targetId: id,
          enabled: true,
        ),
      );
      await flush();
      expect(
        receiver.received.lastWhere(
          (m) => m['type'] == 'projection',
        )['obsPane'],
        true,
      );
      expect(
        receiver.received.lastWhere((m) => m['type'] == 'obsShare')['enabled'],
        true,
      );
      await media.send(RemoteCommand(id: 'close', action: RemoteAction.stop));
      await flush();
      expect(
        receiver.received.lastWhere((m) => m['type'] == 'obsShare')['enabled'],
        false,
      );
      expect(palco.isMuted(id), false);
      expect(media.snapshot.hasOpenMedia, false);
    },
  );
}
