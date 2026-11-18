import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_slide_gallery.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_player_bar.dart';

const _play = Key('remote-play-button');
const _pulse = Key('remote-play-pulse');
const _seek = Key('remote-seek');
const _slideNext = Key('remote-slide-next');
const _slidePrev = Key('remote-slide-prev');

RemotePlayerState _state({
  String? title = 'Digno',
  bool playing = false,
  bool canPrevious = true,
  bool canNext = true,
  RemotePlaylistState? playlist,
  Duration position = Duration.zero,
  Duration duration = Duration.zero,
  int slideIndex = 0,
  int slideCount = 0,
}) => RemotePlayerState(
  title: title,
  playing: playing,
  position: position,
  duration: duration,
  slideIndex: slideIndex,
  slideCount: slideCount,
  volume: 60,
  canPrevious: canPrevious,
  canNext: canNext,
  playlistModule: playlist,
);

void main() {
  late List<RemoteCommand> sent;

  setUp(() => sent = []);

  Future<void> pump(
    WidgetTester tester,
    RemotePlayerState state, {
    VoidCallback? pendingOpen,
    bool showTransport = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: RemotePlayerBar(
            state: state,
            pendingOpen: pendingOpen,
            showTransport: showTransport,
            send: (c) async => sent.add(c),
          ),
        ),
      ),
    ),
  );

  IconButton iconButton(WidgetTester tester, Key key) =>
      tester.widget<IconButton>(find.byKey(key));

  testWidgets('hino usa seta pulsante, seta para baixo e fechar como o vídeo', (tester) async {
    Future<void> hymn(bool projecting) => pump(tester, RemotePlayerState(
      hymnId: 1, title: 'Hino', playing: true,
      position: Duration.zero, duration: const Duration(minutes: 3),
      slideIndex: 0, slideCount: 2, slideLyrics: const ['Letra', 'Final'],
      volume: 60, canPrevious: false, canNext: false,
      videoControls: RemoteVideoControls(
        audioOutput: 'player', canProject: true, projecting: projecting,
        canControlCaptions: false, captionsHidden: false,
        monitors: const [], tvs: const [],
      ),
    ), showTransport: true);
    const project = Key('remote-video-project');
    const close = Key('remote-close-media');
    await hymn(false);
    expect(find.byKey(const Key('remote-project-pulse')), findsOneWidget);
    expect(find.byKey(close), findsOneWidget);
    await tester.tap(find.byKey(project));
    expect(sent.single.action, RemoteAction.videoToggleProjection);
    await hymn(true);
    expect(find.byKey(const Key('remote-project-pulse')), findsNothing);
    expect(tester.widget<Icon>(find.descendant(of: find.byKey(project), matching: find.byType(Icon))).icon, TablerIcons.arrowDown);
    expect(tester.getCenter(find.byKey(close)).dx, greaterThan(tester.getCenter(find.byKey(project)).dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('player de Hinos/Liturgia minimiza sem comandos e volta ao selecionar outro item', (tester) async {
    await pump(tester, _state(playing: true), showTransport: true);
    await tester.tap(find.byKey(const Key('remote-player-minimize')));
    await tester.pump();
    expect(find.byKey(const Key('remote-player-bar')), findsNothing);
    expect(sent, isEmpty);
    await pump(tester, _state(playing: true), showTransport: true, pendingOpen: () {});
    expect(find.byKey(const Key('remote-player-bar')), findsOneWidget);
    expect(find.byKey(const Key('remote-player-minimize')), findsOneWidget);
  });

  testWidgets('icone de som fica na linha dos controles, antes do anterior', (
    tester,
  ) async {
    await pump(tester, _state());

    final icon = tester.getCenter(
      find.byKey(const Key('remote-volume-button')),
    );
    final previous = tester.getCenter(find.byTooltip('remote.previous'));

    expect(icon.dy, previous.dy);
    expect(icon.dx, lessThan(previous.dx));
  });

  group('barra de volume', () {
    const popup = Key('remote-volume-popup');
    const mute = Key('remote-mute');
    const button = Key('remote-volume-button');

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.byKey(button));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('fica oculta ate tocar no icone', (tester) async {
      await pump(tester, _state());

      expect(find.byKey(popup), findsNothing);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('tocar no icone abre a barra e nao muda o volume', (
      tester,
    ) async {
      await pump(tester, _state());

      await open(tester);

      expect(find.byKey(popup), findsOneWidget);
      expect(sent, isEmpty);
    });

    testWidgets('botao de mudo fica abaixo da barra', (tester) async {
      await pump(tester, _state());
      await open(tester);

      final slider = tester.getRect(find.byKey(popup));
      final muteTop = tester.getTopLeft(find.byKey(mute)).dy;

      expect(muteTop, greaterThanOrEqualTo(slider.bottom));
    });

    testWidgets('botao de mudo zera o volume', (tester) async {
      await pump(tester, _state());
      await open(tester);

      await tester.tap(find.byKey(mute));
      await tester.pump();

      expect(sent.single.action, RemoteAction.setVolume);
      expect(sent.single.volume, 0);
    });

    testWidgets('abaixar a barra ate o fim tambem zera', (tester) async {
      await pump(tester, _state());
      await open(tester);

      tester.widget<Slider>(find.byKey(popup)).onChangeEnd!(0);
      await tester.pump();

      expect(sent.single.volume, 0);
    });

    testWidgets('tocar fora fecha a barra', (tester) async {
      await pump(tester, _state());
      await open(tester);

      await tester.tapAt(const Offset(700, 50));
      await tester.pump();

      expect(find.byKey(popup), findsNothing);
    });

    testWidgets('barra e alta e fina', (tester) async {
      await pump(tester, _state());
      await open(tester);

      final size = tester.getSize(find.byType(RotatedBox));
      expect(size.height, greaterThan(300));
      expect(size.width, 44);
    });

    testWidgets('em tela baixa nao passa do topo', (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, _state());
      await open(tester);

      expect(tester.getTopLeft(find.byType(RotatedBox)).dy, greaterThan(0));
    });
  });

  group('play', () {
    testWidgets('sem midia aberta e sem pendencia fica desativado', (
      tester,
    ) async {
      await pump(tester, _state(title: null));

      expect(iconButton(tester, _play).onPressed, isNull);
      expect(find.byKey(_pulse), findsNothing);
    });

    testWidgets('video tocando sem titulo continua podendo pausar', (
      tester,
    ) async {
      // Executar o item conclui e limpa a selecao: o desktop manda title null.
      await pump(tester, _state(title: null, playing: true));

      await tester.tap(find.byKey(_play));
      await tester.pump();

      expect(sent.single.action, RemoteAction.pause);
    });

    testWidgets('video pausado sem titulo continua podendo retomar', (
      tester,
    ) async {
      await pump(
        tester,
        _state(title: null, duration: const Duration(minutes: 3)),
      );

      await tester.tap(find.byKey(_play));
      await tester.pump();

      expect(sent.single.action, RemoteAction.play);
    });

    testWidgets('com midia aberta alterna entre play e pause', (tester) async {
      await pump(tester, _state(playing: true));

      await tester.tap(find.byKey(_play));
      await tester.pump();

      expect(sent.single.action, RemoteAction.pause);
    });

    testWidgets('item pendente pulsa e tem prioridade sobre o pause', (
      tester,
    ) async {
      var opened = 0;
      await pump(tester, _state(playing: true), pendingOpen: () => opened++);

      expect(find.byKey(_pulse), findsOneWidget);
      await tester.tap(find.byKey(_play));
      await tester.pump();

      expect(opened, 1);
      expect(sent, isEmpty);
    });
  });

  group('anterior e proximo', () {
    testWidgets('playlist ativa habilita anterior e próxima durante reprodução', (tester) async {
      await pump(tester, _state(playing: true, playlist: const RemotePlaylistState(lists: [], queue: [RemotePlaylistItem(musicId: 1, title: 'A'), RemotePlaylistItem(musicId: 2, title: 'B'), RemotePlaylistItem(musicId: 3, title: 'C')], queueIndex: 1)));
      for (final tip in ['remote.previous', 'remote.next']) {
        expect(tester.widget<IconButton>(find.ancestor(of: find.byTooltip(tip), matching: find.byType(IconButton)).first).onPressed, isNotNull);
        await tester.tap(find.byTooltip(tip));
      }
      expect(sent.map((command) => command.action), [RemoteAction.previous, RemoteAction.next]);
    });
    testWidgets('playlist respeita limites e bloqueia navegação durante seleção pendente', (tester) async {
      const playlist = RemotePlaylistState(lists: [], queue: [RemotePlaylistItem(musicId: 1, title: 'A'), RemotePlaylistItem(musicId: 2, title: 'B')], queueIndex: 0);
      await pump(tester, _state(playing: true, canPrevious: false, canNext: true, playlist: playlist));
      expect(tester.widget<IconButton>(find.ancestor(of: find.byTooltip('remote.previous'), matching: find.byType(IconButton)).first).onPressed, isNull);
      expect(tester.widget<IconButton>(find.ancestor(of: find.byTooltip('remote.next'), matching: find.byType(IconButton)).first).onPressed, isNotNull);
      await pump(tester, _state(playing: true, playlist: playlist), pendingOpen: () {});
      expect(tester.widget<IconButton>(find.ancestor(of: find.byTooltip('remote.next'), matching: find.byType(IconButton)).first).onPressed, isNull);
    });

    testWidgets('ficam bloqueados com midia aberta', (tester) async {
      await pump(tester, _state(playing: true));

      await tester.tap(find.byTooltip('remote.previous'), warnIfMissed: false);
      await tester.tap(find.byTooltip('remote.next'), warnIfMissed: false);
      await tester.pump();

      expect(sent, isEmpty);
    });

    // Por enquanto desativados: voltam na playlist e no player das
    // coletâneas e do hinário.
    testWidgets('ficam desativados mesmo quando o desktop permitiria', (
      tester,
    ) async {
      await pump(tester, _state(title: null));

      await tester.tap(find.byTooltip('remote.previous'), warnIfMissed: false);
      await tester.tap(find.byTooltip('remote.next'), warnIfMissed: false);
      await tester.pump();

      expect(sent, isEmpty);
      for (final tip in ['remote.previous', 'remote.next']) {
        final button = tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip(tip),
            matching: find.byType(IconButton),
          ),
        );
        expect(button.onPressed, isNull, reason: tip);
      }
    });

    testWidgets('ficam desativados nos limites da liturgia', (tester) async {
      await pump(tester, _state(canPrevious: false, canNext: false));

      await tester.tap(find.byTooltip('remote.previous'), warnIfMissed: false);
      await tester.tap(find.byTooltip('remote.next'), warnIfMissed: false);
      await tester.pump();

      expect(sent, isEmpty);
    });
  });

  group('busca na faixa', () {
    const duration = Duration(minutes: 3);

    testWidgets('soltar a barra envia a nova posicao', (tester) async {
      await pump(tester, _state(duration: duration), showTransport: true);

      tester.widget<Slider>(find.byKey(_seek)).onChangeEnd!(90000);
      await tester.pump();

      expect(sent.single.action, RemoteAction.seek);
      expect(sent.single.position, const Duration(seconds: 90));
    });

    testWidgets('mantem a posicao escolhida ate o desktop confirmar', (
      tester,
    ) async {
      await pump(tester, _state(duration: duration), showTransport: true);

      tester.widget<Slider>(find.byKey(_seek)).onChangeEnd!(90000);
      await pump(
        tester,
        _state(duration: duration, position: const Duration(seconds: 2)),
        showTransport: true,
      );
      expect(find.text('00:00'), findsNothing);

      // Sem o desktop, a tela nao pode ficar presa na posicao escolhida.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('00:02'), findsOneWidget);
    });

    testWidgets('segue o tempo do desktop depois da confirmacao', (
      tester,
    ) async {
      await pump(tester, _state(duration: duration), showTransport: true);

      tester.widget<Slider>(find.byKey(_seek)).onChangeEnd!(90000);
      await pump(
        tester,
        _state(duration: duration, position: const Duration(seconds: 91)),
        showTransport: true,
      );

      expect(find.text('01:31'), findsOneWidget);
    });

    testWidgets('mostra posicao e duracao', (tester) async {
      await pump(
        tester,
        _state(duration: duration, position: const Duration(seconds: 65)),
        showTransport: true,
      );

      expect(find.text('01:05'), findsOneWidget);
      expect(find.text('03:00'), findsOneWidget);
    });

    testWidgets('some quando a midia nao tem duracao', (tester) async {
      await pump(tester, _state(), showTransport: true);

      expect(find.byKey(_seek), findsNothing);
    });

    testWidgets('nao aparece fora da liturgia', (tester) async {
      await pump(tester, _state(duration: duration));

      expect(find.byKey(_seek), findsNothing);
    });
  });

  group('slides', () {
    testWidgets('navega e mostra a posicao atual', (tester) async {
      await pump(
        tester,
        _state(slideIndex: 1, slideCount: 5),
        showTransport: true,
      );

      expect(find.text('2 / 5'), findsOneWidget);
      await tester.tap(find.byKey(_slideNext));
      await tester.pump();
      await tester.tap(find.byKey(_slidePrev));
      await tester.pump();

      expect(sent.map((c) => c.action), [
        RemoteAction.slideNext,
        RemoteAction.slidePrevious,
      ]);
    });

    testWidgets('respeita o primeiro e o ultimo slide', (tester) async {
      await pump(
        tester,
        _state(slideIndex: 0, slideCount: 2),
        showTransport: true,
      );
      expect(iconButton(tester, _slidePrev).onPressed, isNull);
      expect(iconButton(tester, _slideNext).onPressed, isNotNull);

      await pump(
        tester,
        _state(slideIndex: 1, slideCount: 2),
        showTransport: true,
      );
      expect(iconButton(tester, _slidePrev).onPressed, isNotNull);
      expect(iconButton(tester, _slideNext).onPressed, isNull);
    });

    testWidgets('some sem apresentacao de varios slides', (tester) async {
      await pump(tester, _state(slideCount: 1), showTransport: true);

      expect(find.byKey(_slideNext), findsNothing);
    });
  });

  group('previa do video', () {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP4//8/AAX+Av6n1qOiAAAAAElFTkSuQmCC';

    RemotePlayerState videoState({bool open = true}) => RemotePlayerState(
      playing: true,
      position: Duration.zero,
      duration: const Duration(minutes: 1),
      slideIndex: 0,
      slideCount: 0,
      volume: 60,
      canPrevious: false,
      canNext: false,
      videoControls: open
          ? const RemoteVideoControls(
              audioOutput: 'player',
              canProject: true,
              projecting: false,
              canControlCaptions: false,
              captionsHidden: false,
              monitors: [],
              tvs: [],
            )
          : null,
    );

    Future<ValueNotifier<Uint8List?>> pumpVideo(
      WidgetTester tester, {
      bool open = true,
    }) async {
      final frame = ValueNotifier<Uint8List?>(null);
      addTearDown(frame.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RemotePlayerBar(
                state: videoState(open: open),
                showTransport: true,
                send: (c) async {},
                videoFrame: frame,
              ),
            ),
          ),
        ),
      );
      return frame;
    }

    testWidgets('mostra o quadro que chega do desktop', (tester) async {
      final frame = await pumpVideo(tester);
      expect(find.byKey(const Key('remote-video-frame')), findsNothing);

      frame.value = base64Decode(png);
      await tester.pump();

      expect(find.byKey(const Key('remote-video-frame')), findsOneWidget);
    });

    testWidgets('sem video aberto nao mostra quadro antigo', (tester) async {
      final frame = await pumpVideo(tester, open: false);
      frame.value = base64Decode(png);
      await tester.pump();

      expect(find.byKey(const Key('remote-video-frame')), findsNothing);
    });
  });

  group('previa do slide', () {
    // PNG 1x1 valido: o widget decodifica de verdade.
    const preview = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP4//8/AAX+Av6n1qOiAAAAAElFTkSuQmCC';

    testWidgets('mostra a imagem que esta na tela', (tester) async {
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
                  slideIndex: 1,
                  slideCount: 3,
                  volume: 60,
                  canPrevious: false,
                  canNext: false,
                  slidePreview: preview,
                ),
                showTransport: true,
                send: (c) async {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('remote-slide-preview')), findsOneWidget);
    });

    testWidgets('sem previa nao ocupa espaco', (tester) async {
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
                  slideIndex: 1,
                  slideCount: 3,
                  volume: 60,
                  canPrevious: false,
                  canNext: false,
                ),
                showTransport: true,
                send: (c) async {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('remote-slide-preview')), findsNothing);
    });
  });

  group('troca instantanea da previa', () {
    setUp(RemoteSlideGallery.reset);

    const p0 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC';
    const p1 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNg+M8AAAICAQB7CYF4AAAAAElFTkSuQmCC';
    const p2 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYPgPAAEDAQAIicLsAAAAAElFTkSuQmCC';

    RemotePlayerState galleryState(int index, {bool withPreviews = true}) =>
        RemotePlayerState(
          playing: false,
          position: Duration.zero,
          duration: Duration.zero,
          slideIndex: index,
          slideCount: 3,
          volume: 60,
          canPrevious: false,
          canNext: false,
          slidePreview: [p0, p1, p2][index],
          slideGalleryKey: 'g1',
          slidePreviews: withPreviews ? const [p0, p1, p2] : null,
        );

    Future<void> pumpBar(WidgetTester tester, RemotePlayerState state) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: RemotePlayerBar(
                  state: state,
                  showTransport: true,
                  send: (c) async => sent.add(c),
                ),
              ),
            ),
          ),
        );

    List<int> shownBytes(WidgetTester tester) =>
        (tester.widget<Image>(find.byKey(const Key('remote-slide-preview'))).image
                as MemoryImage)
            .bytes;

    testWidgets('tocar na seta troca a previa e o contador na hora', (
      tester,
    ) async {
      await pumpBar(tester, galleryState(0));

      await tester.tap(find.byKey(_slideNext));
      await tester.pump();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(shownBytes(tester), base64Decode(p1));
      expect(sent.single.action, RemoteAction.slideNext);
    });

    testWidgets('estado atrasado do desktop nao volta a imagem', (
      tester,
    ) async {
      await pumpBar(tester, galleryState(0));
      await tester.tap(find.byKey(_slideNext));
      await tester.pump();

      await pumpBar(tester, galleryState(0, withPreviews: false));

      expect(find.text('2 / 3'), findsOneWidget);
      expect(shownBytes(tester), base64Decode(p1));
    });

    testWidgets('miniaturas que chegaram com a barra fechada valem ao abrir', (
      tester,
    ) async {
      RemoteSession.instance.debugEmitStateForTest(galleryState(0));

      await pumpBar(tester, galleryState(0, withPreviews: false));
      await tester.tap(find.byKey(_slideNext));
      await tester.pump();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(shownBytes(tester), base64Decode(p1));
    });

    testWidgets('miniaturas guardadas valem nos estados seguintes', (
      tester,
    ) async {
      await pumpBar(tester, galleryState(0));
      await pumpBar(tester, galleryState(1, withPreviews: false));

      await tester.tap(find.byKey(_slideNext));
      await tester.pump();

      expect(find.text('3 / 3'), findsOneWidget);
      expect(shownBytes(tester), base64Decode(p2));
    });
  });

  group('previa da letra do hino', () {
    RemotePlayerState hymn(int index) => RemotePlayerState(
      title: 'Digno',
      playing: true,
      position: Duration.zero,
      duration: const Duration(minutes: 5),
      slideIndex: index,
      slideCount: 3,
      volume: 60,
      canPrevious: false,
      canNext: false,
      slideLyrics: const ['Digno', 'Digno és\nSenhor', 'Santo, santo'],
    );

    Future<void> pumpHymn(WidgetTester tester, int index) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RemotePlayerBar(
              state: hymn(index),
              showTransport: true,
              send: (c) async => sent.add(c),
            ),
          ),
        ),
      ),
    );

    Size previewSize(WidgetTester tester) => tester.getSize(
      find.descendant(
        of: find.byKey(const Key('remote-lyric-preview')),
        matching: find.byType(AspectRatio),
      ),
    );

    testWidgets('no celular a previa e 16:9 na largura toda', (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpHymn(tester, 1);

      final size = previewSize(tester);
      expect(size.width / size.height, closeTo(16 / 9, 0.01));
      expect(size.height, greaterThan(180));
    });

    testWidgets('em tela baixa a previa encolhe e mantem 16:9', (tester) async {
      tester.view.physicalSize = const Size(411, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpHymn(tester, 1);

      final size = previewSize(tester);
      expect(size.height, lessThanOrEqualTo(150));
      expect(size.width / size.height, closeTo(16 / 9, 0.01));
    });

    testWidgets('mostra o fundo do slide por tras da letra', (tester) async {
      const bg = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGPgEpEDAABoAD1UCKP3AAAAAElFTkSuQmCC';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RemotePlayerBar(
                state: const RemotePlayerState(
                  title: 'Digno',
                  playing: true,
                  position: Duration.zero,
                  duration: Duration(minutes: 5),
                  slideIndex: 1,
                  slideCount: 2,
                  volume: 60,
                  canPrevious: false,
                  canNext: false,
                  slideLyrics: ['Digno', 'Santo'],
                  slideBackgroundKey: 'h1',
                  slideBackgroundIndex: [-1, 0],
                  slideBackgroundSources: [bg],
                ),
                showTransport: true,
                send: (c) async {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('remote-lyric-background')), findsOneWidget);
      expect(find.text('Santo'), findsOneWidget);
    });

    testWidgets('mostra a letra do slide atual', (tester) async {
      await pumpHymn(tester, 1);

      expect(find.byKey(const Key('remote-lyric-preview')), findsOneWidget);
      expect(find.text('Digno és\nSenhor'), findsOneWidget);
    });

    testWidgets('tocar na seta troca a letra na hora', (tester) async {
      await pumpHymn(tester, 1);

      await tester.tap(find.byKey(_slideNext));
      await tester.pump();

      expect(find.text('Santo, santo'), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
    });
  });
}
