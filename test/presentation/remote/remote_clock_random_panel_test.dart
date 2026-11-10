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
        name: name,
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
    List<String> available = const [],
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
    available: available,
  );

  setUp(() => sent.clear());

  testWidgets('clock: alterna projeção e mostra formato 24h', (tester) async {
    await tester.pumpWidget(
      wrap(
        RemoteTimePanel(
          send: fakeSend,
          state: RemotePlayerState(playing: false, position: Duration.zero, duration: Duration.zero, slideIndex: 0, slideCount: 0, volume: 80, canPrevious: false, canNext: false, clockModule: clock(projecting: false)),
        ),
      ),
    );
    expect(find.text('24h'), findsOneWidget);

    await tester.tap(find.text('remote.clock.title'));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const Key('remote-random-import')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('remote-random-names')),
      'Maria\nJoão',
    );
    await tester.tap(find.byKey(const Key('remote-random-import-save')));
    await tester.pumpAndSettle();

    final imp = sent.lastWhere(
      (c) => c.action == RemoteAction.randomImportNames,
    );
    expect(imp.namesText, 'Maria\nJoão');
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byKey(const Key('remote-random-import')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(find.byKey(const Key('remote-random-names'))).initialValue, isEmpty);
    await tester.tap(find.text('common.cancel'));
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remote-random-import-save')));
    await tester.pump();
    expect(sent.length, before);
    await tester.tap(find.text('common.cancel'));
    await tester.pumpAndSettle();

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
    expect(find.text('remote.clock.title'), findsNothing);
    expect(find.text('0 / 0'), findsOneWidget);
  });
  testWidgets('recepção inclui um nome pelo formulário sem aceitar campo vazio', (tester) async {
    await tester.pumpWidget(wrap(RemoteClockRandomPanel(send: fakeSend, random: random(mode: 'names'))));
    final button = find.byKey(const Key('remote-random-add-name'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remote-random-name-save')));
    await tester.pump();
    expect(sent, isEmpty);
    expect(find.text('remote.random.nameRequired'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('remote-random-name-input')), '  Maria da Silva  ');
    await tester.tap(find.byKey(const Key('remote-random-name-save')));
    await tester.pumpAndSettle();
    expect(sent.single.action, RemoteAction.randomAddName);
    expect(sent.single.name, 'Maria da Silva');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('mostra nomes confirmados pelo desktop e importar fica logo após adicionar', (tester) async {
    await tester.pumpWidget(wrap(RemoteClockRandomPanel(send: fakeSend, random: random(mode: 'names', available: ['Maria', 'João', 'Ana']))));
    expect(find.byKey(const Key('remote-random-names')), findsNothing);
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('João'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(tester.getBottomLeft(find.byKey(const Key('remote-random-add-name'))).dy, lessThan(tester.getTopLeft(find.byKey(const Key('remote-random-import'))).dy));
    expect(tester.getBottomLeft(find.byKey(const Key('remote-random-import'))).dy, lessThan(tester.getTopLeft(find.byKey(const Key('remote-random-participants'))).dy));
  });

  testWidgets('nome sorteado fica riscado e desativado na lista e retorna ao normal quando devolvido', (tester) async {
    Future<void> render(List<String> drawn) => tester.pumpWidget(wrap(RemoteClockRandomPanel(send: fakeSend, random: random(mode: 'names', available: ['Ana', 'Bia'], drawn: drawn))));
    await render(['Ana']);
    final ana = find.byKey(const Key('remote-random-participant-0'));
    final bia = find.byKey(const Key('remote-random-participant-1'));
    expect(tester.widget<ListTile>(ana).enabled, isFalse);
    expect(tester.widget<ListTile>(bia).enabled, isTrue);
    expect(tester.widget<Text>(find.descendant(of: ana, matching: find.text('Ana'))).style!.decoration, TextDecoration.lineThrough);
    await render([]);
    expect(tester.widget<ListTile>(ana).enabled, isTrue);
    expect(tester.widget<Text>(find.descendant(of: ana, matching: find.text('Ana'))).style?.decoration, isNot(TextDecoration.lineThrough));
  });

  testWidgets('X exclui o nome pelo índice correto inclusive quando já sorteado', (tester) async {
    await tester.pumpWidget(wrap(RemoteClockRandomPanel(send: fakeSend, random: random(mode: 'names', available: ['Ana', 'Bia'], drawn: ['Ana']))));
    final button = find.byKey(const Key('remote-random-remove-name-0'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    expect(sent.single.action, RemoteAction.randomRemoveAvailable);
    expect(sent.single.index, 0);
  });

  testWidgets('lista mostra até cinco nomes e tem barra e rolagem para os demais', (tester) async {
    final names = List.generate(8, (index) => 'Pessoa ${index + 1}');
    await tester.pumpWidget(wrap(RemoteClockRandomPanel(send: fakeSend, random: random(mode: 'names', available: names))));
    final viewport = find.byKey(const Key('remote-random-participants-viewport'));
    await tester.ensureVisible(viewport);
    await tester.pumpAndSettle();
    expect(tester.getSize(viewport).height, 5 * 48);
    final scrollbar = tester.widget<Scrollbar>(find.byKey(const Key('remote-random-participants-scrollbar')));
    expect(scrollbar.thumbVisibility, isTrue);
    final list = find.descendant(of: viewport, matching: find.byType(ListView));
    await tester.drag(list, const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(scrollbar.controller!.offset, greaterThan(0));
    expect(find.text('Pessoa 8').hitTestable(), findsOneWidget);
  });

  testWidgets('limpar histórico envia comando para liberar os nomes sorteados', (tester) async {
    await tester.pumpWidget(wrap(RemoteClockRandomPanel(send: fakeSend, random: random(mode: 'names', available: ['Ana', 'Bia'], drawn: ['Ana']))));
    final clear = find.byKey(const Key('remote-random-clear-history'));
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    expect(sent.single.action, RemoteAction.randomClearHistory);
  });

  testWidgets('Limpar lista remove os participantes e fica desativado quando vazia', (tester) async {
    await tester.pumpWidget(wrap(RemoteClockRandomPanel(send: fakeSend, random: random(mode: 'names', available: ['Ana', 'Bia']))));
    final button = find.byKey(const Key('remote-random-clear-list'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    await tester.tap(find.byKey(const Key('remote-random-clear-list-confirm')));
    await tester.pumpAndSettle();
    expect(sent.single.action, RemoteAction.randomClearAvailable);
    await tester.pumpWidget(wrap(RemoteClockRandomPanel(send: fakeSend, random: random(mode: 'names'))));
    expect(tester.widget<TextButton>(button).onPressed, isNull);
  });

  testWidgets('cancelar confirmação de limpar lista preserva os nomes', (tester) async {
    await tester.pumpWidget(wrap(RemoteClockRandomPanel(send: fakeSend, random: random(mode: 'names', available: ['Ana']))));
    final button = find.byKey(const Key('remote-random-clear-list'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('common.cancel'));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(find.text('Ana'), findsOneWidget);
  });

}
