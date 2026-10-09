import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_stop_video_button.dart';

/// Estado do vídeo no palco é flag do singleton StageSession; sem TV
/// conectada os comandos vão pra lista vazia de targets (no-op) — cobre
/// os ramos visuais do botão sem hardware.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    final stage = StageSession.instance;
    if (stage.isVideoOnStage) stage.stopVideoOnStage();
    if (stage.isStageVideoPaused) stage.toggleStageVideoPause();
  });

  testWidgets('sem vídeo no palco → SizedBox.shrink', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(appBar: AppBar(actions: [const StageStopVideoButton()]))),
    );
    await tester.pump();

    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byTooltip('Pausar vídeo'), findsNothing);
  });

  testWidgets('vídeo em palco → botões pause/stop visíveis e funcionais', (
    tester,
  ) async {
    final stage = StageSession.instance;
    stage.markVideoOnStageForTest();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(appBar: AppBar(actions: [const StageStopVideoButton()]))),
    );
    await tester.pump();

    expect(find.byTooltip('Pausar vídeo'), findsOneWidget);
    expect(find.byTooltip('Parar vídeo no Palco'), findsOneWidget);

    // Toggle pause muda tooltip pra "Continuar vídeo".
    await tester.tap(find.byTooltip('Pausar vídeo'));
    await tester.pump();
    expect(stage.isStageVideoPaused, isTrue);
    expect(find.byTooltip('Continuar vídeo'), findsOneWidget);

    await tester.tap(find.byTooltip('Continuar vídeo'));
    await tester.pump();
    expect(stage.isStageVideoPaused, isFalse);
  });

  testWidgets('Parar vídeo oculta os botões (idle) e mostra snackbar', (
    tester,
  ) async {
    final stage = StageSession.instance;
    stage.markVideoOnStageForTest();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(appBar: AppBar(actions: [const StageStopVideoButton()]))),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Parar vídeo no Palco'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(stage.isVideoOnStage, isFalse);
    expect(find.text('Vídeo interrompido — Palco em idle'), findsOneWidget);
  });
}
