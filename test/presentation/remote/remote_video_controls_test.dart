import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_player_bar.dart';

const _audio = Key('remote-audio-output');
const _project = Key('remote-video-project');
const _targets = Key('remote-video-targets');
const _captions = Key('remote-video-captions');
const _pulse = Key('remote-project-pulse');
const _close = Key('remote-close-media');
const _independent = Key('remote-independent');

RemoteVideoControls _controls({
  String audioOutput = 'player',
  bool canProject = true,
  bool projecting = false,
  bool canControlCaptions = true,
  bool captionsHidden = false,
}) => RemoteVideoControls(
  audioOutput: audioOutput,
  canProject: canProject,
  projecting: projecting,
  canControlCaptions: canControlCaptions,
  captionsHidden: captionsHidden,
  monitors: const [
    RemoteVideoTarget(
      id: 'monitor:2',
      label: 'Monitor 2',
      detail: '1280 × 720',
      selected: true,
    ),
    RemoteVideoTarget(id: 'monitor:3', label: 'Monitor 3', selected: false),
  ],
  tvs: const [RemoteVideoTarget(id: 'tv:a', label: 'TV Sala', selected: true)],
);

RemotePlayerState _state(RemoteVideoControls? controls, {bool open = true}) =>
    RemotePlayerState(
      playing: open,
      position: Duration.zero,
      duration: open ? const Duration(minutes: 3) : Duration.zero,
      slideIndex: 0,
      slideCount: 0,
      volume: 60,
      canPrevious: false,
      canNext: false,
      videoControls: controls,
    );

void main() {
  late List<RemoteCommand> sent;

  setUp(() => sent = []);

  Future<void> pump(
    WidgetTester tester,
    RemoteVideoControls? controls, {
    bool showTransport = true,
    bool open = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: RemotePlayerBar(
            state: _state(controls, open: open),
            showTransport: showTransport,
            send: (c) async => sent.add(c),
          ),
        ),
      ),
    ),
  );

  IconButton button(WidgetTester tester, Key key) =>
      tester.widget<IconButton>(find.byKey(key));

  group('visibilidade', () {
    testWidgets('sem video a linha fica visivel e desativada', (tester) async {
      await pump(tester, null, open: false);

      final menu = tester.widget<PopupMenuButton<String>>(find.byKey(_audio));
      expect(menu.enabled, isFalse);
      expect(button(tester, _targets).onPressed, isNotNull);
      expect(button(tester, _independent).onPressed, isNotNull);
      expect(button(tester, _project).onPressed, isNull);
      expect(find.byKey(_pulse), findsNothing);
    });

    testWidgets('hino aberto sem barra de video mantem o stop', (tester) async {
      await pump(tester, null);

      expect(find.byKey(_project), findsNothing);
      expect(find.byTooltip('remote.stop'), findsOneWidget);
    });

    testWidgets('stop do hino pede confirmacao antes de parar', (tester) async {
      await pump(tester, null);

      await tester.tap(find.byTooltip('remote.stop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('remote-close-confirm')), findsOneWidget);
      expect(sent, isEmpty);

      await tester.tap(find.byKey(const Key('remote-close-ok')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(sent.single.action, RemoteAction.stop);
    });

    testWidgets('com video o projetar substitui o stop na linha do play', (
      tester,
    ) async {
      await pump(tester, _controls());

      expect(find.byTooltip('remote.stop'), findsNothing);
      expect(
        tester.getCenter(find.byKey(_project)).dy,
        tester.getCenter(find.byKey(const Key('remote-play-button'))).dy,
      );
      expect(
        tester.getCenter(find.byKey(_audio)).dy,
        lessThan(tester.getCenter(find.byKey(_project)).dy),
      );
    });

    testWidgets('nao aparece fora da liturgia', (tester) async {
      await pump(tester, _controls(), showTransport: false);

      expect(find.byKey(_audio), findsNothing);
    });

    testWidgets('CC so aparece quando o video tem legenda', (tester) async {
      await pump(tester, _controls(canControlCaptions: false));

      expect(find.byKey(_captions), findsNothing);
    });
  });

  testWidgets('escolher o destino do som envia o modo', (tester) async {
    await pump(tester, _controls());

    await tester.tap(find.byKey(_audio));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('remote-audio-option-connections')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(sent.single.action, RemoteAction.videoSetAudioOutput);
    expect(sent.single.mode, 'connections');
  });

  group('projetar', () {
    testWidgets('alterna a projecao', (tester) async {
      await pump(tester, _controls());

      await tester.tap(find.byKey(_project));
      await tester.pump();

      expect(sent.single.action, RemoteAction.videoToggleProjection);
    });

    testWidgets('seta para cima e grossa antes de projetar', (tester) async {
      await pump(tester, _controls());

      final icon = tester.widget<Icon>(
        find.descendant(of: find.byKey(_project), matching: find.byType(Icon)),
      );
      expect(icon.icon, TablerIcons.arrowUpRight);
      expect(icon.shadows, isNotEmpty);
    });

    testWidgets('projetando mostra seta para baixo', (tester) async {
      await pump(tester, _controls(projecting: true));

      final icon = tester.widget<Icon>(
        find.descendant(of: find.byKey(_project), matching: find.byType(Icon)),
      );
      expect(icon.icon, TablerIcons.arrowDown);
    });

    testWidgets('pulso do projetar e mais forte que o do play', (tester) async {
      await pump(tester, _controls());
      await tester.pump(const Duration(milliseconds: 225));
      await tester.pump(const Duration(milliseconds: 225));

      final scale = tester.widget<ScaleTransition>(find.byKey(_pulse));
      expect(scale.scale.value, greaterThan(1.2));
    });

    testWidgets('X pede confirmacao antes de fechar', (tester) async {
      await pump(tester, _controls());

      await tester.tap(find.byKey(_close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('remote-close-confirm')), findsOneWidget);
      expect(sent, isEmpty);
    });

    testWidgets('cancelar a confirmacao nao fecha', (tester) async {
      await pump(tester, _controls());

      await tester.tap(find.byKey(_close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('remote-close-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('remote-close-confirm')), findsNothing);
      expect(sent, isEmpty);
    });

    testWidgets('confirmar fecha a midia', (tester) async {
      await pump(tester, _controls());

      await tester.tap(find.byKey(_close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('remote-close-ok')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(sent.single.action, RemoteAction.stop);
    });

    testWidgets('sem video nao ha X', (tester) async {
      await pump(tester, null, open: false);

      expect(find.byKey(_close), findsNothing);
    });

    testWidgets('pulsa enquanto da para projetar', (tester) async {
      await pump(tester, _controls());

      expect(find.byKey(_pulse), findsOneWidget);
    });

    testWidgets('nao pulsa projetando nem sem tela disponivel', (tester) async {
      await pump(tester, _controls(projecting: true));
      expect(find.byKey(_pulse), findsNothing);

      await pump(tester, _controls(canProject: false));
      expect(find.byKey(_pulse), findsNothing);
    });

    testWidgets('sem tela disponivel fica desativado', (tester) async {
      await pump(tester, _controls(canProject: false));

      expect(button(tester, _project).onPressed, isNull);
    });

    testWidgets('projetando pode retirar mesmo sem tela disponivel', (
      tester,
    ) async {
      await pump(tester, _controls(canProject: false, projecting: true));

      expect(button(tester, _project).onPressed, isNotNull);
    });
  });

  testWidgets('CC alterna as legendas', (tester) async {
    await pump(tester, _controls());

    await tester.tap(find.byKey(_captions));
    await tester.pump();

    expect(sent.single.action, RemoteAction.videoToggleCaptions);
  });

  group('telas', () {
    testWidgets('selo conta os monitores marcados, como no desktop', (
      tester,
    ) async {
      await pump(tester, _controls());

      // Monitor 2 + TV Sala: mesma conta do cabeçalho do desktop.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('lista monitores e TVs e envia a marcacao', (tester) async {
      await pump(tester, _controls());

      await tester.tap(find.byKey(_targets));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Monitor 2'), findsOneWidget);
      expect(find.text('TV Sala'), findsOneWidget);

      await tester.tap(find.byKey(const Key('remote-target-monitor:3')));
      await tester.pump();

      expect(sent.single.action, RemoteAction.videoSetTarget);
      expect(sent.single.targetId, 'monitor:3');
      expect(sent.single.enabled, isTrue);
    });
  });

  group('telas sem video', () {
    const idleWithTvs = RemotePlayerState(
      playing: false,
      position: Duration.zero,
      duration: Duration.zero,
      slideIndex: 0,
      slideCount: 0,
      volume: 60,
      canPrevious: false,
      canNext: false,
      idleVideoTargets: [
        RemoteVideoTarget(id: 'monitor:2', label: 'Monitor 2', selected: true),
      ],
      idleVideoTvs: [
        RemoteVideoTarget(
          id: 'tv:5',
          label: 'Tv Frontal',
          detail: 'Conexões ativas: 0',
          selected: true,
        ),
      ],
    );

    Future<void> pumpIdle(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RemotePlayerBar(
              state: idleWithTvs,
              showTransport: true,
              send: (c) async => sent.add(c),
            ),
          ),
        ),
      ),
    );

    testWidgets('contador soma monitores e conexoes', (tester) async {
      await pumpIdle(tester);

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('lista conexoes e envia a escolha', (tester) async {
      await pumpIdle(tester);
      await tester.tap(find.byKey(_targets));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Tv Frontal'), findsOneWidget);
      await tester.tap(find.text('Tv Frontal'));
      await tester.pump();

      expect(sent.single.action, RemoteAction.videoSetTarget);
      expect(sent.single.targetId, 'tv:5');
      expect(sent.single.enabled, isFalse);
    });

    testWidgets('abre a lista com os monitores do desktop', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RemotePlayerBar(
                state: const RemotePlayerState(
                  playing: false,
                  position: Duration.zero,
                  duration: Duration.zero,
                  slideIndex: 0,
                  slideCount: 0,
                  volume: 60,
                  canPrevious: false,
                  canNext: false,
                  idleVideoTargets: [
                    RemoteVideoTarget(
                      id: 'monitor:2',
                      label: 'Monitor 2',
                      selected: true,
                    ),
                  ],
                ),
                showTransport: true,
                send: (c) async => sent.add(c),
              ),
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byKey(_targets));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Monitor 2'), findsOneWidget);
    });
  });

  testWidgets('separa monitores das conexoes remotas', (tester) async {
    await pump(tester, _controls());

    await tester.tap(find.byKey(_targets));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('remote.video.remoteConnections'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('remote.video.remoteConnections')).dy,
      greaterThan(tester.getTopLeft(find.text('Monitor 3')).dy),
    );
  });

  testWidgets('projecao independente abre mesmo sem video', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RemotePlayerBar(
              state: const RemotePlayerState(
                playing: false,
                position: Duration.zero,
                duration: Duration.zero,
                slideIndex: 0,
                slideCount: 0,
                volume: 60,
                canPrevious: false,
                canNext: false,
                idleIndependent: RemoteIndependentControls(
                  mode: 'overlay',
                  live: false,
                  armed: false,
                  monitors: [
                    RemoteVideoTarget(
                      id: 'monitor:2',
                      label: 'Monitor 2',
                      selected: false,
                    ),
                  ],
                  remotes: [],
                ),
              ),
              showTransport: true,
              send: (c) async => sent.add(c),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(_independent));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('remote-independent-monitor:2')));
    await tester.pump();

    expect(sent.single.action, RemoteAction.videoSetIndependentTarget);
  });

  group('projecao independente', () {
    RemoteVideoControls withIndependent({bool armed = false}) =>
        RemoteVideoControls(
          audioOutput: 'player',
          canProject: true,
          projecting: false,
          canControlCaptions: false,
          captionsHidden: false,
          monitors: const [],
          tvs: const [],
          independent: RemoteIndependentControls(
            mode: 'overlay',
            live: false,
            armed: armed,
            monitors: const [
              RemoteVideoTarget(
                id: 'monitor:2',
                label: 'Monitor 2',
                selected: false,
              ),
              RemoteVideoTarget(
                id: 'monitor:3',
                label: 'Monitor 3',
                selected: false,
                enabled: false,
              ),
            ],
            remotes: const [
              RemoteVideoTarget(id: 'tv:a', label: 'OBS', selected: false),
            ],
          ),
        );

    Future<void> open(WidgetTester tester) async {
      await pump(tester, withIndependent());
      await tester.tap(find.byKey(_independent));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('mostra monitores e conexoes remotas', (tester) async {
      await open(tester);

      expect(find.text('Monitor 2'), findsOneWidget);
      expect(find.text('OBS'), findsOneWidget);
    });

    testWidgets('marcar monitor envia o destino', (tester) async {
      await open(tester);

      await tester.tap(find.byKey(const Key('remote-independent-monitor:2')));
      await tester.pump();

      expect(sent.single.action, RemoteAction.videoSetIndependentTarget);
      expect(sent.single.targetId, 'monitor:2');
      expect(sent.single.enabled, isTrue);
    });

    testWidgets('monitor desligado em Telas fica desativado', (tester) async {
      await open(tester);

      await tester.tap(
        find.byKey(const Key('remote-independent-monitor:3')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(sent, isEmpty);
    });

    testWidgets('modo selecionado fica legivel', (tester) async {
      await open(tester);

      final selected = tester.widget<ChoiceChip>(
        find.byKey(const Key('remote-independent-mode-overlay')),
      );
      final other = tester.widget<ChoiceChip>(
        find.byKey(const Key('remote-independent-mode-share')),
      );
      final scheme = Theme.of(
        tester.element(find.byKey(const Key('remote-independent-mode-overlay'))),
      ).colorScheme;

      expect(selected.labelStyle?.color, scheme.primary);
      expect(selected.selectedColor, scheme.primary.withValues(alpha: 0.15));
      expect(selected.checkmarkColor, scheme.primary);
      expect(other.labelStyle?.color, isNull);
    });

    testWidgets('trocar o modo envia o comando', (tester) async {
      await open(tester);

      await tester.tap(find.byKey(const Key('remote-independent-mode-share')));
      await tester.pump();

      expect(sent.single.action, RemoteAction.videoSetIndependentMode);
      expect(sent.single.mode, 'share');
    });
  });

  group('protocolo', () {
    const player =
        '"playing":true,"positionMs":0,"durationMs":0,"volume":0,'
        '"canPrevious":false,"canNext":false';

    test('le os controles enviados pelo desktop', () {
      final state =
          RemoteProtocol.parse(
                '{"v":1,"type":"state","player":{$player},"video":{'
                '"audioOutput":"both","canProject":true,"projecting":true,'
                '"canControlCaptions":true,"captionsHidden":true,'
                '"monitors":[{"id":"monitor:2","label":"Monitor 2",'
                '"detail":"800 × 600","selected":true},{"id":5}],'
                '"tvs":[{"id":"tv:a","label":"TV","selected":false}]}}',
              )!
              as RemotePlayerState;

      final video = state.videoControls!;
      expect(video.audioOutput, 'both');
      expect(video.projecting, isTrue);
      expect(video.captionsHidden, isTrue);
      expect(video.monitors.single.detail, '800 × 600');
      expect(video.tvs.single.selected, isFalse);
    });

    test('le o suporte a abrir sem projetar', () {
      final state =
          RemoteProtocol.parse(
                '{"v":1,"type":"state","player":{$player},'
                '"liturgy":{"canOpen":true,"items":[]}}',
              )!
              as RemotePlayerState;

      expect(state.liturgyCanOpen, isTrue);
    });

    test('le a projecao independente e as telas sem video', () {
      final state =
          RemoteProtocol.parse(
                '{"v":1,"type":"state","player":{$player},'
                '"videoTargets":{"monitors":[{"id":"monitor:2",'
                '"label":"Monitor 2","selected":true}]},'
                '"video":{"independent":{"mode":"share","live":true,'
                '"armed":false,"monitors":[{"id":"monitor:2",'
                '"label":"Monitor 2","selected":true,"onAir":true,'
                '"enabled":false}],"remotes":[]}}}',
              )!
              as RemotePlayerState;

      expect(state.idleVideoTargets.single.selected, isTrue);
      final independent = state.videoControls!.independent!;
      expect(independent.mode, 'share');
      expect(independent.live, isTrue);
      expect(independent.monitors.single.onAir, isTrue);
      expect(independent.monitors.single.enabled, isFalse);
    });

    test('le a projecao independente sem video', () {
      final state =
          RemoteProtocol.parse(
                '{"v":1,"type":"state","player":{$player},'
                '"videoTargets":{"monitors":[],"independent":{"mode":"share",'
                '"live":false,"armed":true,"monitors":[],"remotes":[]}}}',
              )!
              as RemotePlayerState;

      expect(state.idleIndependent?.mode, 'share');
      expect(state.idleIndependent?.armed, isTrue);
    });

    test('desktop antigo nao envia controles', () {
      final state =
          RemoteProtocol.parse('{"v":1,"type":"state","player":{$player}}')!
              as RemotePlayerState;

      expect(state.videoControls, isNull);
    });

    test('comando leva destino e estado', () {
      final encoded = RemoteCommand(
        id: 'x',
        action: RemoteAction.videoSetTarget,
        targetId: 'tv:a',
        enabled: false,
      ).encode();

      expect(encoded, contains('"action":"video.setTarget"'));
      expect(encoded, contains('"targetId":"tv:a"'));
      expect(encoded, contains('"enabled":false'));
    });
  });
}
