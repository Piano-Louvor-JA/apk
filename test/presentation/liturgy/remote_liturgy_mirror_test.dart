import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_page.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_site_browser_page.dart';

const _play = Key('remote-play-button');
const _pulse = Key('remote-play-pulse');
const _bar = Key('remote-player-bar');
const _pending = Key('mirror-liturgy-tap-1');
const _done = Key('mirror-liturgy-tap-2');

const _items = [
  RemoteLiturgyItem(
    index: 0,
    type: 'category',
    title: 'Escola Sabatina',
    done: false,
    isCategory: true,
  ),
  RemoteLiturgyItem(index: 1, type: 'music', title: 'Digno', done: false),
  RemoteLiturgyItem(index: 2, type: 'music', title: 'Feito', done: true),
];

const _statePlaying = RemotePlayerState(
  playing: true,
  position: Duration.zero,
  duration: Duration(minutes: 3),
  slideIndex: 0,
  slideCount: 0,
  volume: 60,
  canPrevious: false,
  canNext: true,
  liturgyItems: _items,
);

const _stateCanOpen = RemotePlayerState(
  playing: false,
  position: Duration.zero,
  duration: Duration.zero,
  slideIndex: 0,
  slideCount: 0,
  volume: 60,
  canPrevious: false,
  canNext: true,
  liturgyCanOpen: true,
  liturgyItems: _items,
);

const _state = RemotePlayerState(
  playing: false,
  position: Duration.zero,
  duration: Duration.zero,
  slideIndex: 0,
  slideCount: 0,
  volume: 60,
  canPrevious: false,
  canNext: true,
  liturgyItems: [
    RemoteLiturgyItem(
      index: 0,
      type: 'category',
      title: 'Escola Sabatina',
      done: false,
      isCategory: true,
    ),
    RemoteLiturgyItem(index: 1, type: 'music', title: 'Digno', done: false),
    RemoteLiturgyItem(index: 2, type: 'music', title: 'Feito', done: true),
  ],
);

void main() {
  late List<RemoteCommand> sent;

  setUp(() => sent = []);

  Future<void> pump(WidgetTester tester, {RemotePlayerState state = _state}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteLiturgyMirror(
              state: state,
              send: (c) async => sent.add(c),
            ),
          ),
        ),
      );

  testWidgets('mostra a barra de controles', (tester) async {
    await pump(tester);

    expect(find.byKey(_bar), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(_play)).onPressed, isNull);
  });

  testWidgets('tocar no item nao executa: so escolhe e faz o play pulsar', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(_pending));
    await tester.pump();

    expect(sent, isEmpty);
    expect(find.byKey(_pulse), findsOneWidget);
  });

  testWidgets('play executa o item escolhido no desktop e para de pulsar', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(_pending));
    await tester.pump();

    await tester.tap(find.byKey(_play));
    await tester.pump();

    expect(sent.single.action, RemoteAction.liturgySelect);
    expect(sent.single.index, 1);
    expect(find.byKey(_pulse), findsNothing);
  });

  testWidgets('desktop novo: play abre o item sem projetar', (tester) async {
    await pump(tester, state: _stateCanOpen);
    await tester.tap(find.byKey(_pending));
    await tester.pump();

    await tester.tap(find.byKey(_play));
    await tester.pump();

    expect(sent.single.action, RemoteAction.liturgyOpen);
    expect(sent.single.index, 1);
  });

  group('com midia aberta a lista fica bloqueada', () {
    testWidgets('tocar no item nao escolhe', (tester) async {
      await pump(tester, state: _statePlaying);

      await tester.tap(find.byKey(_pending));
      await tester.pump();

      expect(find.byKey(_pulse), findsNothing);
    });

    testWidgets('marcar como concluido nao envia nada', (tester) async {
      await pump(tester, state: _statePlaying);

      await tester.tap(
        find.descendant(
          of: find.byKey(_pending),
          matching: find.byIcon(TablerIcons.circle),
        ),
      );
      await tester.pump();

      expect(sent, isEmpty);
    });

    testWidgets('escolha feita antes de abrir a midia e descartada', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(_pending));
      await tester.pump();
      expect(find.byKey(_pulse), findsOneWidget);

      await pump(tester, state: _statePlaying);
      await tester.pump();

      expect(find.byKey(_pulse), findsNothing);
    });

    testWidgets('sem midia marcar como concluido continua funcionando', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(
        find.descendant(
          of: find.byKey(_pending),
          matching: find.byIcon(TablerIcons.circle),
        ),
      );
      await tester.pump();

      expect(sent.single.action, RemoteAction.liturgyToggleDone);
    });
  });

  testWidgets('tocar de novo no item desfaz a escolha', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(_pending));
    await tester.pump();

    await tester.tap(find.byKey(_pending));
    await tester.pump();

    expect(find.byKey(_pulse), findsNothing);
  });

  testWidgets('item concluido nao pode ser escolhido, igual ao desktop', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(_done));
    await tester.pump();

    expect(find.byKey(_pulse), findsNothing);
  });

  testWidgets('categoria nao pode ser escolhida', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Escola Sabatina'));
    await tester.pump();

    expect(find.byKey(_pulse), findsNothing);
  });

  group('site', () {
    const siteState = RemotePlayerState(
      playing: false,
      position: Duration.zero,
      duration: Duration.zero,
      slideIndex: 0,
      slideCount: 0,
      volume: 60,
      canPrevious: false,
      canNext: false,
      liturgyCanOpen: true,
      liturgyItems: [
        RemoteLiturgyItem(
          index: 0,
          type: 'site',
          title: 'Site',
          done: false,
          url: 'https://www.adventistas.org',
        ),
      ],
    );

    Future<List<RemoteSiteBrowserPage>> pumpSite(WidgetTester tester) async {
      final opened = <RemoteSiteBrowserPage>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteLiturgyMirror(
              state: siteState,
              send: (c) async => sent.add(c),
              openSite: (context, page) async => opened.add(page),
            ),
          ),
        ),
      );
      return opened;
    }

    Future<RemoteSiteBrowserPage> openViaPlay(WidgetTester tester) async {
      final opened = await pumpSite(tester);
      await tester.tap(find.byKey(const Key('mirror-liturgy-tap-0')));
      await tester.pump();
      await tester.tap(find.byKey(_play));
      await tester.pump();
      return opened.single;
    }

    testWidgets('tocar na linha so escolhe o site, sem abrir o navegador', (
      tester,
    ) async {
      final opened = await pumpSite(tester);

      await tester.tap(find.byKey(const Key('mirror-liturgy-tap-0')));
      await tester.pump();

      expect(opened, isEmpty);
      expect(sent, isEmpty);
      expect(find.byKey(_pulse), findsOneWidget);
    });

    testWidgets('play abre o site no desktop (sem projetar) e o navegador', (
      tester,
    ) async {
      final page = await openViaPlay(tester);

      expect(page.url, 'https://www.adventistas.org');
      expect(page.title, 'Site');
      expect(sent.single.action, RemoteAction.liturgyOpen);
      expect(sent.single.index, 0);
    });

    testWidgets('navegar, rolar e a seta vao para o desktop', (tester) async {
      final page = await openViaPlay(tester);
      sent.clear();

      page.onNavigate('https://www.adventistas.org/pt/');
      page.onScroll(0.5);
      await page.onToggleScreens();

      expect(sent[0].action, RemoteAction.siteNavigate);
      expect(sent[0].url, 'https://www.adventistas.org/pt/');
      expect(sent[1].action, RemoteAction.siteScroll);
      expect(sent[1].ratio, 0.5);
      expect(sent[2].action, RemoteAction.videoToggleProjection);
    });
  });
}
