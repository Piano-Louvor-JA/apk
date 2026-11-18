import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/domain/repositories/local_liturgy_media.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/player/local_liturgy_player.dart';

RemotePlayerState snapshot([String? title]) => RemotePlayerState(
  title: title,
  playing: title != null,
  position: Duration.zero,
  duration: Duration.zero,
  slideIndex: 0,
  slideCount: 1,
  volume: 100,
  canPrevious: false,
  canNext: false,
);

class FakeMedia implements LocalLiturgyMedia {
  final events = StreamController<RemotePlayerState>.broadcast(sync: true);
  final commands = <RemoteAction>[];
  final opened = <String>[];
  Completer<void>? opening;
  bool fail = false;
  @override
  Stream<RemotePlayerState> get states => events.stream;
  @override
  Future<void> open(LiturgyItem item, String language, DateTime date) async {
    opened.add(item.id);
    await opening?.future;
    if (fail) throw StateError('invalid');
    events.add(snapshot(item.name));
  }

  @override
  Future<void> send(RemoteCommand command) async {
    commands.add(command.action);
    if (command.action == RemoteAction.stop) events.add(snapshot());
  }

  @override
  Future<void> updateText(LiturgyItem item) async {}
  @override
  Future<void> dispose() => events.close();
}

void main() {
  late FakeMedia media;
  late LocalLiturgyPlayer player;
  const item = LiturgyItem(
    id: 'one',
    type: LiturgyItemType.annotation,
    name: 'Anotação',
  );
  setUp(() {
    media = FakeMedia();
    player = LocalLiturgyPlayer(media);
  });
  tearDown(() async {
    await player.close();
  });
  test(
    'selecionar não abre nem projeta; play abre uma vez e bloqueia troca',
    () async {
      player.choose(item, language: 'pt', date: DateTime(2026));
      expect(media.opened, isEmpty);
      expect(player.pending, item);
      await player.openPending();
      expect(media.opened, ['one']);
      expect(media.commands, isEmpty);
      expect(player.state.title, 'Anotação');
      player.choose(
        item.copyWith(id: 'two'),
        language: 'pt',
        date: DateTime(2026),
      );
      expect(player.pending, isNull);
      expect(player.active?.id, 'one');
    },
  );
  test(
    'escolher um item pede para reabrir a barra e o item só escolhido conta como conteúdo',
    () async {
      expect(player.hasContent, isFalse);
      final before = player.revealCount;
      player.choose(item, language: 'pt', date: DateTime(2026));
      expect(player.revealCount, before + 1);
      expect(player.hasContent, isTrue);
      player.choose(
        item.copyWith(id: 'two'),
        language: 'pt',
        date: DateTime(2026),
      );
      expect(player.revealCount, before + 2);
      await player.send(RemoteCommand(id: 's', action: RemoteAction.stop));
      expect(player.hasContent, isFalse);
    },
  );
  test('comandos atuam no executor local e stop libera nova seleção', () async {
    player.choose(item, language: 'pt', date: DateTime(2026));
    await player.openPending();
    await player.send(
      RemoteCommand(id: 'p', action: RemoteAction.videoToggleProjection),
    );
    await player.send(RemoteCommand(id: 's', action: RemoteAction.stop));
    expect(media.commands, [
      RemoteAction.videoToggleProjection,
      RemoteAction.stop,
    ]);
    expect(player.state.hasOpenMedia, false);
    expect(player.active, isNull);
  });
  test(
    'erro preserva item para tentar novamente e libera carregamento',
    () async {
      media.fail = true;
      player.choose(item, language: 'pt', date: DateTime(2026));
      await expectLater(player.openPending(), throwsStateError);
      expect(player.pending, item);
      expect(player.busy, false);
      expect(player.active, isNull);
      media.fail = false;
      await player.openPending();
      expect(player.state.title, item.name);
    },
  );
  test('duplo play durante abertura não duplica reprodução', () async {
    media.opening = Completer<void>();
    player.choose(item, language: 'pt', date: DateTime(2026));
    final first = player.openPending();
    await player.openPending();
    expect(media.opened, ['one']);
    media.opening!.complete();
    await first;
    expect(player.busy, false);
  });
  test('fechar durante abertura descarta resultado atrasado', () async {
    media.opening = Completer<void>();
    player.choose(item, language: 'pt', date: DateTime(2026));
    final opening = player.openPending();
    await player.send(RemoteCommand(id: 'stop', action: RemoteAction.stop));
    media.opening!.complete();
    await opening;
    expect(player.active, isNull);
    expect(player.state.hasOpenMedia, false);
  });

  test(
    'itens externos também aguardam play e preservam executor original',
    () async {
      var opened = false;
      player.choose(
        item,
        language: 'pt',
        date: DateTime(2026),
        externalOpen: () async {
          opened = true;
        },
      );
      expect(opened, false);
      await player.openPending();
      expect(opened, true);
      expect(media.opened, isEmpty);
      expect(player.pending, isNull);
    },
  );
}
