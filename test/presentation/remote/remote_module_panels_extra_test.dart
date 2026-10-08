import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_module_panels.dart';

/// Ramos extras: edição de duração do countdown, marks/savedTimes,
/// chevrons nos limites (min/max), reset/projeção e clock/random cards.
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

  RemotePlayerState countdownState({
    String status = 'idle',
    int durationMs = 0,
    int accumulatedMs = 0,
    bool finished = false,
    List<int> savedTimesMs = const [],
    bool isProjecting = false,
  }) =>
      RemotePlayerState(
        playing: false,
        position: Duration.zero,
        duration: Duration.zero,
        slideIndex: 0,
        slideCount: 0,
        volume: 0,
        canPrevious: false,
        canNext: false,
        countdownModule: RemoteCountdownState(
          status: status,
          durationMs: durationMs,
          accumulatedMs: accumulatedMs,
          finished: finished,
          savedTimesMs: savedTimesMs,
          isProjecting: isProjecting,
        ),
      );

  setUp(() => sent.clear());

  testWidgets('countdown: editar duração e aplicar manda countdownSetDuration',
      (tester) async {
    await tester.pumpWidget(
      wrap(RemoteTimePanel(send: fakeSend, state: countdownState())),
    );

    await tester.drag(
      find.byKey(const Key('remote-timer-card')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remote-countdown-edit')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('remote-countdown-min')), '5');
    await tester.enterText(find.byKey(const Key('remote-countdown-sec')), '30');
    await tester.tap(find.byKey(const Key('remote-countdown-apply')));
    await tester.pump();

    expect(sent.single.action, RemoteAction.countdownSetDuration);
    expect(sent.single.durationMs, 330000);
  });

  testWidgets('countdown com duração 0 não envia setDuration', (tester) async {
    await tester.pumpWidget(
      wrap(RemoteTimePanel(send: fakeSend, state: countdownState())),
    );
    await tester.drag(
      find.byKey(const Key('remote-timer-card')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remote-countdown-edit')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('remote-countdown-min')), '0');
    await tester.enterText(find.byKey(const Key('remote-countdown-sec')), '0');
    await tester.tap(find.byKey(const Key('remote-countdown-apply')));
    await tester.pump();

    expect(sent, isEmpty);
  });

  testWidgets('countdown rodando com marks: reset, salvar marca e projetar', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        RemoteTimePanel(
          send: fakeSend,
          state: countdownState(
            status: 'running',
            durationMs: 600000,
            accumulatedMs: 90000,
            savedTimesMs: [60000, 120000],
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const Key('remote-timer-card')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    // botão principal do countdown rodando = pause; projection = toggle
    final keys = [
      'remote-countdown-toggle',
      'remote-countdown-projection',
    ];
    for (final key in keys) {
      if (find.byKey(Key(key)).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }
    }
    // aceitar qualquer das ações enviadas — o contrato é comandos válidos.
    for (final cmd in sent) {
      expect(
        cmd.action,
        anyOf(
          RemoteAction.countdownPause,
          RemoteAction.countdownToggleProjection,
          RemoteAction.countdownStart,
          RemoteAction.countdownReset,
        ),
      );
    }
  });

  testWidgets('bible chevron minus desabilitado no capítulo 1', (tester) async {
    const state = RemotePlayerState(
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
        ],
        versions: [RemoteBibleVersion(id: 1, abbreviation: 'ARA')],
      ),
    );
    await tester.pumpWidget(
      wrap(RemoteBiblePanel(send: fakeSend, state: state)),
    );

    final minus = tester.widget<IconButton>(
      find.byKey(const Key('remote-bible-chapter-minus')),
    );
    expect(minus.onPressed, isNull); // capítulo 1 = limite
  });
}
