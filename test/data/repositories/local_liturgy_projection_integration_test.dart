import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/data/repositories/local_liturgy_media_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_playback.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:mocktail/mocktail.dart';
import '../../core/services/palco/palco_controller_test.dart' show FakeReceiver;
import 'local_liturgy_media_impl_test.dart' show Audio, Video;

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

  Future<(PalcoOrchestrator, FakeReceiver, String)> connectTv(String id) async {
    SharedPreferences.setMockInitialValues({});
    final palco = PalcoOrchestrator.instance;
    expect(
      palco.addSlot(id: id, label: 'TV', slotIndex: 0, persist: false),
      true,
    );
    final controller = palco.slot(id)!.controller;
    final receiver = FakeReceiver();
    addTearDown(() async {
      await receiver.close();
      await palco.removeSlot(id);
    });
    await controller.connect(const PalcoTarget(name: 'TV', ip: '127.0.0.1'));
    await receiver.connect('127.0.0.1', controller.wsPort);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    receiver.received.clear();
    return (palco, receiver, id);
  }

  Future<void> flush() async =>
      Future<void>.delayed(const Duration(milliseconds: 100));

  test('seek com vídeo pausado reenvia pausa para o receiver', () async {
    final (_, receiver, _) = await connectTv('local-seek');
    final media = LocalLiturgyMediaImpl(createVideo: (_) => Video());
    addTearDown(media.dispose);
    await media.open(
      const LiturgyItem(
        id: 'v',
        type: LiturgyItemType.video,
        name: 'Vídeo',
        filePath: '/clip.mp4',
      ),
      'pt',
      DateTime(2026),
    );
    await media.send(
      RemoteCommand(id: 'p', action: RemoteAction.videoToggleProjection),
    );
    await media.send(RemoteCommand(id: 'pause', action: RemoteAction.pause));
    await flush();
    receiver.received.clear();
    await media.send(
      RemoteCommand(
        id: 's',
        action: RemoteAction.seek,
        position: const Duration(seconds: 30),
      ),
    );
    await flush();
    final actions = receiver.received
        .where((m) => m['type'] == 'video')
        .map((m) => m['action'])
        .toList();
    expect(actions, ['seek', 'pause']);
    expect(media.snapshot.playing, false);
  });

  test('trocar o modo da música mantém a projeção e o áudio nas TVs', () async {
    registerFallbackValue(Duration.zero);
    final (_, receiver, _) = await connectTv('local-mode');
    final dir = await Directory.systemTemp.createTemp('local-mode');
    addTearDown(() => dir.delete(recursive: true));
    final vocal = (await File('${dir.path}/digno.mp3').writeAsBytes([1])).path;
    final playback = (await File(
      '${dir.path}/digno-pb.mp3',
    ).writeAsBytes([2])).path;
    final audio = Audio();
    String? source;
    when(() => audio.positionStream).thenAnswer((_) => const Stream.empty());
    when(() => audio.durationStream).thenAnswer((_) => const Stream.empty());
    when(() => audio.playingStream).thenAnswer((_) => const Stream.empty());
    when(() => audio.currentUrl).thenAnswer((_) => source);
    when(() => audio.playUrl(any())).thenAnswer((call) async {
      source = call.positionalArguments.first as String;
    });
    when(() => audio.setVolume(any())).thenAnswer((_) async {});
    when(() => audio.seek(any())).thenAnswer((_) async {});
    when(() => audio.pause()).thenAnswer((_) async {});
    when(() => audio.resume()).thenAnswer((_) async {});
    when(() => audio.stop()).thenAnswer((_) async => source = null);
    final media = LocalLiturgyMediaImpl(
      audio: audio,
      resolveMusic: (item, language) async => LiturgyMusicPlayback(
        detail: const Hymn(id: 1, title: 'Digno', durationMs: 60000),
        source: item.musicMode == 'instrumental' ? playback : vocal,
        isLocal: true,
      ),
    );
    addTearDown(media.dispose);
    await media.open(
      const LiturgyItem(
        id: 'm',
        type: LiturgyItemType.music,
        name: 'Digno',
        musicId: 1,
      ),
      'pt',
      DateTime(2026),
    );
    await media.send(
      RemoteCommand(
        id: 'out',
        action: RemoteAction.videoSetAudioOutput,
        mode: 'both',
      ),
    );
    await media.send(
      RemoteCommand(id: 'p', action: RemoteAction.videoToggleProjection),
    );
    await flush();
    receiver.received.clear();
    await media.send(
      RemoteCommand(
        id: 'mode',
        action: RemoteAction.setMode,
        mode: 'instrumental',
      ),
    );
    await flush();
    expect(media.snapshot.videoControls!.projecting, true);
    expect(receiver.received.where((m) => m['type'] == 'idle'), isEmpty);
    expect(
      receiver.received.where((m) => m['type'] == 'projection'),
      isNotEmpty,
    );
    final audioUrl = receiver.received.lastWhere(
      (m) => m['type'] == 'audio' && m['url'] != null,
    )['url'];
    expect(audioUrl, contains('digno-pb'));
  });
}
