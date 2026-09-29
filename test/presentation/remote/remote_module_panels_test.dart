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

  testWidgets('RemoteBiblePanel seleciona livro por nome e navega capítulo', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(RemoteBiblePanel(send: fakeSend, state: bibleState)),
    );
    expect(find.byKey(const Key('remote-bible-book-select')), findsOneWidget);
    await tester.tap(find.byKey(const Key('remote-bible-chapter-plus')));
    await tester.pump();
    expect(sent.single.action, RemoteAction.bibleOpen);
    expect(sent.single.chapter, 2);

    sent.clear();
    await tester.tap(find.byKey(const Key('remote-bible-verse-plus')));
    await tester.pump();
    expect(sent.single.action, RemoteAction.bibleSelectVerse);
    expect(sent.single.verse, 2);
  });

  testWidgets(
    'RemoteHymnsPanel busca via media.search e abre com hit do desktop',
    (tester) async {
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
        wrap(RemoteHymnsPanel(send: fakeSend, state: state)),
      );

      await tester.enterText(
        find.byKey(const Key('remote-hymns-query')),
        'Cruz',
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(sent.single.action, RemoteAction.mediaSearch);
      expect(sent.single.query, 'Cruz');

      // troca modo p/ playback e abre o hit (id do DESKTOP)
      await tester.tap(find.byKey(const Key('remote-hymns-mode-instrumental')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('remote-hymns-result-0')));
      await tester.pump();

      expect(sent.last.action, RemoteAction.mediaOpen);
      expect(sent.last.musicId, 42);
      expect(sent.last.mode, 'instrumental');
    },
  );

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
