library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_module_panels.dart';

void main() {
  final sent = <RemoteCommand>[];

  Future<void> fakeSend(
    RemoteAction action, {
    int? index,
    int? volume,
    int? versionId,
    int? bookId,
    int? chapter,
    int? verse,
    int? durationMs,
    String? name,
    String? style,
    bool? showSeconds,
    bool? format24h,
    int? musicId,
    String? mode,
    String? query,
    int? numberMin,
    int? numberMax,
    String? namesText,
  }) async {
    sent.add(
      RemoteCommand(
        id: 't',
        action: action,
        index: index,
        volume: volume,
        versionId: versionId,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        durationMs: durationMs,
        musicId: musicId,
        mode: mode,
        query: query,
        numberMin: numberMin,
        numberMax: numberMax,
        namesText: namesText,
      ),
    );
  }

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  setUp(() => sent.clear());

  const bibleState = RemotePlayerState(
    playing: false,
    position: Duration.zero,
    duration: Duration.zero,
    slideIndex: 0,
    slideCount: 0,
    volume: 0,
    canPrevious: false,
    canNext: false,
    bibleModule: RemoteBibleState(
      bookId: 1,
      chapter: 1,
      selectedVerses: [1],
      isProjecting: false,
      versionId: 1,
      books: [
        RemoteBibleBook(id: 1, name: 'Gênesis', chapters: 50, number: 1),
        RemoteBibleBook(id: 2, name: 'Êxodo', chapters: 40, number: 2),
      ],
      versions: [RemoteBibleVersion(id: 1, abbreviation: 'ARA')],
    ),
  );

  testWidgets(
    'Bíblia organiza versão/livro e capítulo/versículo em duas linhas no celular',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        wrap(RemoteBiblePanel(send: fakeSend, state: bibleState)),
      );
      Rect field(String key) => tester.getRect(find.byKey(Key(key)));
      expect(
        field('remote-bible-version').top,
        field('remote-bible-book-select').top,
      );
      expect(
        field('remote-bible-version').right,
        lessThan(field('remote-bible-book-select').left),
      );
      expect(
        field('remote-bible-chapter-select').top,
        field('remote-bible-verse-select').top,
      );
      expect(
        field('remote-bible-chapter-select').right,
        lessThan(field('remote-bible-verse-select').left),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Bíblia alterna abrir e fechar no mesmo botão conforme o desktop', (tester) async {
    Future<void> show(bool projecting) async {
      final state = RemotePlayerState(
        playing: false, position: Duration.zero, duration: Duration.zero,
        slideIndex: 0, slideCount: 0, volume: 0,
        canPrevious: false, canNext: false,
        bibleModule: RemoteBibleState(
          bookId: 1, chapter: 1, selectedVerses: [1],
          isProjecting: projecting, versionId: 1,
          books: bibleState.bibleModule!.books,
          versions: bibleState.bibleModule!.versions,
        ),
      );
      await tester.pumpWidget(wrap(RemoteBiblePanel(send: fakeSend, state: state)));
    }
    await show(false);
    expect(find.text('remote.bible.close'), findsNothing);
    await tester.tap(find.byKey(const Key('remote-bible-project')));
    expect(sent.last.action, RemoteAction.bibleOpen);
    await show(true);
    expect(find.text('remote.bible.open'), findsNothing);
    expect(find.text('remote.bible.close'), findsOneWidget);
    await tester.tap(find.byKey(const Key('remote-bible-project')));
    expect(sent.last.action, RemoteAction.bibleClose);
    await show(false);
    expect(find.text('remote.bible.open'), findsOneWidget);
    expect(find.text('remote.bible.close'), findsNothing);
  });

  testWidgets('busca de livros ignora acentos e seleciona sem projetar durante a digitação', (tester) async {
    await tester.pumpWidget(wrap(RemoteBiblePanel(send: fakeSend, state: bibleState)));
    await tester.tap(find.byKey(const Key('remote-bible-book-select')));
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('remote-bible-book-search'));
    await tester.enterText(search, 'exodo');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('remote-bible-book-1')), findsNothing);
    expect(find.byKey(const Key('remote-bible-book-2')), findsOneWidget);
    expect(sent, isEmpty);
    await tester.tap(find.byKey(const Key('remote-bible-book-2')));
    await tester.pumpAndSettle();
    expect(sent.single.action.wire, 'bible.select');
    expect(sent.single.bookId, 2);
    expect(sent.single.chapter, 1);
    expect(sent.single.verse, 1);
    expect(search, findsNothing);
  });

  for (final field in ['chapter', 'verse']) {
    testWidgets('busca de $field filtra números e envia apenas ao selecionar', (tester) async {
      await tester.pumpWidget(wrap(RemoteBiblePanel(send: fakeSend, state: bibleState)));
      await tester.tap(find.byKey(Key('remote-bible-$field-select')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(Key('remote-bible-$field-search')), '12');
      await tester.pumpAndSettle();
      expect(find.byKey(Key('remote-bible-$field-1')), findsNothing);
      expect(find.byKey(Key('remote-bible-$field-12')), findsOneWidget);
      expect(sent, isEmpty);
      await tester.tap(find.byKey(Key('remote-bible-$field-12')));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      if (field == 'chapter') {
        expect(sent.single.action.wire, 'bible.select');
        expect(sent.single.chapter, 12);
        expect(sent.single.verse, 1);
      } else {
        expect(sent.single.action, RemoteAction.bibleSelectVerse);
        expect(sent.single.verse, 12);
      }
      expect(find.byKey(Key('remote-bible-$field-search')), findsNothing);
    });
  }

  testWidgets('prévia bíblica mostra texto do desktop e navega sem projetar', (tester) async {
    final state = RemoteProtocol.parse(
      '{"v":1,"type":"state","player":{"playing":false,"positionMs":0,"durationMs":0,'
      '"slideIndex":0,"slideCount":0,"volume":0,"canPrevious":false,"canNext":false},'
      '"bible":{"bookId":1,"chapter":1,'
      '"selectedVerses":[1],"isProjecting":false,"verses":{"1":"No princípio","2":"A terra"},'
      '"books":[{"id":1,"name":"Gênesis","chapters":50,"number":1}]}}',
    ) as RemotePlayerState;
    await tester.pumpWidget(wrap(RemoteBiblePanel(send: fakeSend, state: state)));
    await tester.ensureVisible(find.byKey(const Key('remote-bible-preview')));
    await tester.pumpAndSettle();
    expect(find.text('No princípio'), findsOneWidget);
    expect(find.text('Gênesis 1:1'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('remote-bible-preview-prev'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('remote-bible-preview-next')));
    expect(sent.single.action, RemoteAction.bibleSelectVerse);
    expect(sent.single.verse, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RemoteBiblePanel seleciona livro por nome e navega capítulo', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(RemoteBiblePanel(send: fakeSend, state: bibleState)),
    );
    expect(find.byKey(const Key('remote-bible-book-select')), findsOneWidget);
    await tester.tap(find.byKey(const Key('remote-bible-chapter-plus')));
    await tester.pump();
    expect(sent.single.action.wire, 'bible.select');
    expect(sent.single.chapter, 2);

    sent.clear();
    await tester.tap(find.byKey(const Key('remote-bible-verse-plus')));
    await tester.pump();
    expect(sent.single.action, RemoteAction.bibleSelectVerse);
    expect(sent.single.verse, 2);
  });

  testWidgets(
    'RemoteHymnsPanel busca via media.search e so seleciona o hit do desktop',
    (tester) async {
      RemoteHymnSelection? picked;
      const state = RemotePlayerState(
        playing: false,
        position: Duration.zero,
        duration: Duration.zero,
        slideIndex: 0,
        slideCount: 0,
        volume: 0,
        canPrevious: false,
        canNext: false,
        mediaModule: RemoteMediaState(
          searchResults: [
            RemoteMusicHit(musicId: 42, name: 'Ao Pé da Cruz', track: 160),
          ],
        ),
      );
      await tester.pumpWidget(
        wrap(
          RemoteHymnsPanel(
            send: fakeSend,
            state: state,
            onSelectionChanged: (s) => picked = s,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('remote-hymns-query')),
        'Cruz',
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(sent.single.action, RemoteAction.mediaSearch);
      expect(sent.single.query, 'Cruz');

      // troca modo p/ playback e seleciona o hit (id do DESKTOP): sem projetar
      await tester.tap(find.byKey(const Key('remote-hymns-mode-instrumental')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('remote-hymns-result-0')));
      await tester.pump();

      expect(sent, hasLength(1));
      expect(picked?.musicId, 42);
      expect(picked?.mode, 'instrumental');
    },
  );

  testWidgets('trocar o modo com hino selecionado atualiza a selecao', (
    tester,
  ) async {
    RemoteHymnSelection? picked;
    await tester.pumpWidget(
      wrap(
        RemoteHymnsPanel(
          send: fakeSend,
          selectedMusicId: 42,
          onSelectionChanged: (s) => picked = s,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('remote-hymns-mode-no_audio')));
    await tester.pump();

    expect(picked?.musicId, 42);
    expect(picked?.mode, 'no_audio');
  });

  testWidgets('X aparece com termo digitado e limpa a busca', (tester) async {
    const clearKey = Key('remote-hymns-clear');
    await tester.pumpWidget(wrap(RemoteHymnsPanel(send: fakeSend)));
    expect(find.byKey(clearKey), findsNothing);

    final field = find.byKey(const Key('remote-hymns-query'));
    await tester.enterText(field, 'Digno');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(clearKey), findsOneWidget);

    await tester.tap(find.byKey(clearKey));
    await tester.pump();

    expect(tester.widget<TextField>(field).controller?.text, isEmpty);
    expect(find.byKey(clearKey), findsNothing);
  });

  testWidgets('apos limpar, buscar o mesmo termo consulta o desktop de novo', (
    tester,
  ) async {
    final field = find.byKey(const Key('remote-hymns-query'));
    await tester.pumpWidget(wrap(RemoteHymnsPanel(send: fakeSend)));
    await tester.enterText(field, 'Digno');
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('remote-hymns-clear')));
    await tester.pump();
    await tester.enterText(field, 'Digno');
    await tester.pump(const Duration(milliseconds: 500));

    expect(sent, hasLength(2));
  });

  testWidgets('nova busca limpa a selecao anterior', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      wrap(
        RemoteHymnsPanel(
          send: fakeSend,
          selectedMusicId: 42,
          onSelectionChanged: (s) => cleared = s == null,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('remote-hymns-query')), 'Paz');
    await tester.pump(const Duration(milliseconds: 500));

    expect(cleared, isTrue);
  });

  testWidgets('RemoteTimePanel renderiza timer + countdown e envia ações', (
    tester,
  ) async {
    const state = RemotePlayerState(
      playing: false,
      position: Duration.zero,
      duration: Duration.zero,
      slideIndex: 0,
      slideCount: 0,
      volume: 0,
      canPrevious: false,
      canNext: false,
      timerModule: RemoteTimerState(
        status: 'idle',
        accumulatedMs: 0,
        isProjecting: false,
      ),
      countdownModule: RemoteCountdownState(
        status: 'running',
        durationMs: 300000,
        accumulatedMs: 60000,
        finished: false,
        isProjecting: false,
      ),
    );
    await tester.pumpWidget(
      wrap(RemoteTimePanel(send: fakeSend, state: state)),
    );

    expect(find.byKey(const Key('remote-timer-card')), findsOneWidget);
    expect(find.byKey(const Key('remote-countdown-card')), findsOneWidget);

    // countdown está abaixo da dobra — arrasta a lista pra cima
    await tester.drag(
      find.byKey(const Key('remote-timer-card')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('remote-countdown-card')), findsOneWidget);

    // countdown rodando → botão principal = pause
    await tester.tap(find.byKey(const Key('remote-countdown-toggle')));
    await tester.pump();
    expect(sent.single.action, RemoteAction.countdownPause);

    // timer parado → botão principal = start
    sent.clear();
    await tester.tap(find.byKey(const Key('remote-timer-toggle')));
    await tester.pump();
    expect(sent.single.action, RemoteAction.timerStart);
  });
}
