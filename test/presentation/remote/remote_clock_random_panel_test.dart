import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_module_panels.dart';

/// RemoteClockRandomPanel: card de relógio (projeção on/off, 12h/24h) e
/// card de sorteio (modos, intervalo, importar nomes, sortear, lista de
/// sorteados com devolver) — todos os comandos via send fake.
void main() {
  final sent = <RemoteCommand>[];

  Future<void> fakeSend(
    RemoteAction action, {
    int? numberMin,
    int? numberMax,
    String? namesText,
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

  RemoteClockState clock({bool projecting = false, bool format24h = true}) =>
      RemoteClockState(
        style: 'digital',
        showSeconds: true,
        format24h: format24h,
        isProjecting: projecting,
      );

  RemoteRandomState random({
    String mode = 'numbers',
    bool drawing = false,
    bool projecting = false,
    List<String> drawn = const [],
    String? display,
  }) => RemoteRandomState(
    mode: mode,
    drawnCount: drawn.length,
    availableCount: 10,
    isDrawing: drawing,
    currentDisplay: display,
    isProjecting: projecting,
    numberMin: 1,
    numberMax: 100,
    drawn: drawn,
  );

  setUp(() => sent.clear());

  testWidgets('clock: alterna projeção e mostra formato 24h', (tester) async {
    await tester.pumpWidget(
      wrap(
        RemoteClockRandomPanel(
          send: fakeSend,
          clock: clock(projecting: false),
          random: random(),
        ),
      ),
    );
    expect(find.text('24h'), findsOneWidget);

    await tester.tap(find.byKey(const Key('remote-clock-projection')));
    await tester.pump();
    expect(
      sent.any((c) => c.action == RemoteAction.clockToggleProjection),
      isTrue,
    );
  });

  testWidgets('random numbers: aplica intervalo e sorteia', (tester) async {
    await tester.pumpWidget(
      wrap(RemoteClockRandomPanel(send: fakeSend, random: random())),
    );

    await tester.enterText(
      find.byKey(const Key('remote-random-min')),
      '5',
    );
    await tester.enterText(
      find.byKey(const Key('remote-random-max')),
      '50',
    );
    await tester.tap(find.byKey(const Key('remote-random-apply-range')));
    await tester.pump();

    final range = sent.lastWhere(
      (c) => c.action == RemoteAction.randomSetNumberRange,
    );
    expect(range.numberMin, 5);
    expect(range.numberMax, 50);

    await tester.tap(find.byKey(const Key('remote-random-draw')));
    await tester.pump();
    expect(sent.any((c) => c.action == RemoteAction.randomStartDraw), isTrue);
  });

  testWidgets('random names: importa nomes e limpa campo', (tester) async {
    await tester.pumpWidget(
      wrap(
        RemoteClockRandomPanel(send: fakeSend, random: random(mode: 'names')),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('remote-random-names')),
      'Maria\nJoão',
    );
    await tester.tap(find.byKey(const Key('remote-random-import')));
    await tester.pump();

    final imp = sent.lastWhere(
      (c) => c.action == RemoteAction.randomImportNames,
    );
    expect(imp.namesText, 'Maria\nJoão');
    expect(
      tester.widget<TextField>(
        find.byKey(const Key('remote-random-names')),
      ).controller!.text,
      isEmpty,
    );
  });

  testWidgets('random: import vazio não envia; display e devolver funcionam',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        RemoteClockRandomPanel(
          send: fakeSend,
          random: random(drawn: ['Ana', 'Bia'], display: '42'),
        ),
      ),
    );

    expect(find.byKey(const Key('remote-random-display')), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);

    // import vazio: no-op (modo names)
    await tester.pumpWidget(
      wrap(
        RemoteClockRandomPanel(send: fakeSend, random: random(mode: 'names')),
      ),
    );
    final before = sent.length;
    await tester.tap(find.byKey(const Key('remote-random-import')));
    await tester.pump();
    expect(sent.length, before);

    // volta pro numbers e devolve o índice 1
    await tester.pumpWidget(
      wrap(
        RemoteClockRandomPanel(
          send: fakeSend,
          random: random(drawn: ['Ana', 'Bia']),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('remote-random-undraw-1')));
    await tester.pump();
    final rm = sent.lastWhere(
      (c) => c.action == RemoteAction.randomRemoveDrawn,
    );
    expect(rm.index, 1);
  });

  testWidgets('random: mudar modo, parar e alternar projeção', (tester) async {
    await tester.pumpWidget(
      wrap(RemoteClockRandomPanel(send: fakeSend, random: random())),
    );

    await tester.tap(find.text('remote.random.names'));
    await tester.pump();
    expect(
      sent.any((c) => c.action == RemoteAction.randomSetMode && c.mode == 'names'),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('remote-random-stop')));
    await tester.pump();
    expect(sent.any((c) => c.action == RemoteAction.randomCancelDraw), isTrue);

    await tester.tap(find.byKey(const Key('remote-random-projection')));
    await tester.pump();
    expect(
      sent.any((c) => c.action == RemoteAction.randomToggleProjection),
      isTrue,
    );
  });

  testWidgets('random desenhando: botão sortear desabilitado', (tester) async {
    await tester.pumpWidget(
      wrap(RemoteClockRandomPanel(send: fakeSend, random: random(drawing: true))),
    );
    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('remote-random-draw')),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('sem estados: clock mostra traço e contadores zero', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(RemoteClockRandomPanel(send: fakeSend)));
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0 / 0'), findsOneWidget);
  });
}
