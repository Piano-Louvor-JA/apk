import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_player_presence.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/player/local_liturgy_player.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/player/local_liturgy_player_bar.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_player_bar.dart';
import 'local_liturgy_player_test.dart' show FakeMedia;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'player local reutiliza seleção, play e fechar no tema ${brightness.name}',
      (tester) async {
        final media = FakeMedia();
        final player = LocalLiturgyPlayer(media);
        final presence = RemotePlayerPresence();
        player.choose(
          const LiturgyItem(
            id: 'a',
            type: LiturgyItemType.annotation,
            name: 'Anotação',
          ),
          language: 'pt',
          date: DateTime(2026),
        );
        await tester.binding.setSurfaceSize(const Size(480, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: RepaintBoundary(
                  key: const Key('local-player-golden'),
                  child: LocalLiturgyPlayerBar(
                    player: player,
                    presence: presence,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(RemotePlayerBar), findsOneWidget);
        expect(media.opened, isEmpty);
        await tester.pump(const Duration(seconds: 1));
        await expectLater(
          find.byKey(const Key('local-player-golden')),
          matchesGoldenFile('goldens/local_player_${brightness.name}.png'),
        );
        await tester.tap(find.byKey(const Key('remote-play-button')));
        await tester.pump();
        await tester.pump();
        expect(media.opened, ['a']);
        expect(presence.value, true);
        await tester.tap(find.byKey(const Key('remote-player-minimize')));
        await tester.pump();
        await tester.pump();
        expect(presence.value, false);
        expect(player.state.hasOpenMedia, true);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(player.close);
        presence.dispose();
      },
    );
  }
  testWidgets(
    'limite local da prévia preserva espaço para todos os controles',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemotePlayerBar(
              state: const RemotePlayerState(
                title: 'Digno',
                playing: true,
                position: Duration.zero,
                duration: Duration(minutes: 2),
                slideIndex: 0,
                slideCount: 2,
                volume: 100,
                canPrevious: false,
                canNext: false,
                slideLyrics: ['Santo', 'Santo'],
              ),
              showTransport: true,
              previewMaxHeight: 90,
              send: (_) async {},
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('remote-lyric-preview'))).height,
        lessThanOrEqualTo(90),
      );
      expect(
        tester.getBottomRight(find.byKey(const Key('remote-play-button'))).dy,
        lessThan(600),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
