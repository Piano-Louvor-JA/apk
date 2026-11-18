import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_module_panels.dart';

void main() {
  testWidgets(
    'áudio de sorteio envia play, mute, volume e escolha de arquivo',
    (tester) async {
      final actions = <RemoteAction>[];
      int? capturedVolume;
      String? capturedName;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteClockRandomPanel(
              random: const RemoteRandomState(
                mode: 'names',
                drawnCount: 0,
                availableCount: 0,
                isDrawing: false,
                isProjecting: false,
                audioSupported: true,
                audioVolume: 40,
                customAudioFiles: ['Som.mp3'],
              ),
              send:
                  (
                    action, {
                    numberMin,
                    numberMax,
                    namesText,
                    index,
                    volume,
                    versionId,
                    bookId,
                    chapter,
                    verse,
                    durationMs,
                    name,
                    style,
                    showSeconds,
                    format24h,
                    musicId,
                    mode,
                    query,
                  }) async {
                    actions.add(action);
                    capturedVolume = volume;
                    capturedName = name;
                  },
            ),
          ),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('remote-random-audio-play')),
      );
      await tester.tap(find.byKey(const Key('remote-random-audio-play')));
      expect(actions.last, RemoteAction.randomToggleAudio);
      await tester.tap(find.byKey(const Key('remote-random-audio-mute')));
      expect(actions.last, RemoteAction.randomToggleAudioMute);
      final slider = tester.widget<Slider>(
        find.byKey(const Key('remote-random-audio-volume')),
      );
      slider.onChanged!(75);
      slider.onChangeEnd!(75);
      expect(actions.last, RemoteAction.randomSetAudioVolume);
      expect(capturedVolume, 75);
      await tester.ensureVisible(
        find.byKey(const Key('remote-random-audio-source')),
      );
      await tester.tap(find.byKey(const Key('remote-random-audio-source')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Som.mp3').last);
      await tester.pumpAndSettle();
      expect(actions.last, RemoteAction.randomUseCustomAudio);
      expect(capturedName, 'Som.mp3');
    },
  );
  testWidgets('botão acompanha play e pause recebidos do desktop', (tester) async {
    Future<void> render(bool playing) => tester.pumpWidget(MaterialApp(home: Scaffold(body: RemoteClockRandomPanel(random: RemoteRandomState(mode: 'names', drawnCount: 0, availableCount: 0, isDrawing: false, isProjecting: false, audioSupported: true, audioPlaying: playing)))));
    await render(true);
    final button = find.byKey(const Key('remote-random-audio-play'));
    expect(find.descendant(of: button, matching: find.byIcon(TablerIcons.playerPause)), findsOneWidget);
    await render(false);
    expect(find.descendant(of: button, matching: find.byIcon(TablerIcons.playerPlay)), findsOneWidget);
  });

}
