library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/global_search_service.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/presentation/search/global_search_page.dart';

void main() {
  testWidgets('GlobalSearchPage mostra resultados agrupados', (tester) async {
    final hymns = <Hymn>[
      Hymn(id: 1, title: 'Amor de Deus', number: 10, hasInstrumental: false),
    ];
    final verses = <BibleVerseRef>[
      const BibleVerseRef(
        bookId: 43,
        bookName: 'João',
        chapter: 3,
        verse: 16,
        text: 'Porque Deus amou o mundo',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          service: GlobalSearchService(),
          hymnsProvider: () async => hymns,
          versesProvider: () async => verses,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'amou o mundo');
    await tester.pumpAndSettle();

    expect(find.text('Amor de Deus'), findsNothing);
    expect(find.text('João 3:16'), findsOneWidget);
  });

  testWidgets('query curta nao dispara busca', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          service: GlobalSearchService(),
          hymnsProvider: () async => <Hymn>[],
          versesProvider: () async => <BibleVerseRef>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'am');
    await tester.pumpAndSettle();

    // Estado vazio visivel, sem grupos
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('callback onHymnSelected e chamado ao tocar resultado', (
    tester,
  ) async {
    Hymn? selected;
    final hymns = <Hymn>[
      Hymn(id: 2, title: 'Grande Amor', number: 5, hasInstrumental: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          service: GlobalSearchService(),
          hymnsProvider: () async => hymns,
          versesProvider: () async => <BibleVerseRef>[],
          onHymnSelected: (h) => selected = h,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'grande amor');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grande Amor').first);
    await tester.pumpAndSettle();

    expect(selected?.id, 2);
  });

  testWidgets('AC-1: OK/Done com exatamente 1 hino resultado toca o hino', (
    tester,
  ) async {
    Hymn? selected;
    final hymns = <Hymn>[
      Hymn(id: 7, title: 'Grande Amor', number: 5, hasInstrumental: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          service: GlobalSearchService(),
          hymnsProvider: () async => hymns,
          versesProvider: () async => <BibleVerseRef>[],
          onHymnSelected: (h) => selected = h,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'grande amor');
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(selected?.id, 7);
  });

  testWidgets('AC-2: OK/Done com 2 resultados nao toca', (tester) async {
    Hymn? selected;
    final hymns = <Hymn>[
      Hymn(id: 7, title: 'Grande Amor', number: 5, hasInstrumental: false),
      Hymn(id: 8, title: 'Grande Amor Eterno', number: 6, hasInstrumental: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          service: GlobalSearchService(),
          hymnsProvider: () async => hymns,
          versesProvider: () async => <BibleVerseRef>[],
          onHymnSelected: (h) => selected = h,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'grande amor');
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsAtLeast(2));

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });

  testWidgets('AC-3: OK/Done com query curta nao toca e nao busca', (
    tester,
  ) async {
    Hymn? selected;
    final hymns = <Hymn>[
      Hymn(id: 7, title: 'Grande Amor', number: 5, hasInstrumental: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          service: GlobalSearchService(),
          hymnsProvider: () async => hymns,
          versesProvider: () async => <BibleVerseRef>[],
          onHymnSelected: (h) => selected = h,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'am');
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(find.byType(ListTile), findsNothing);
  });

  // RF-03: zero resultados no submit nunca toca.
  testWidgets('AC-4: OK/Done com zero resultados nao toca', (tester) async {
    Hymn? selected;
    final hymns = <Hymn>[
      Hymn(id: 7, title: 'Grande Amor', number: 5, hasInstrumental: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          service: GlobalSearchService(),
          hymnsProvider: () async => hymns,
          versesProvider: () async => <BibleVerseRef>[],
          onHymnSelected: (h) => selected = h,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz inexistente');
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });

  // RF-04: resultado exclusivamente biblico no submit nao toca hino.
  testWidgets('AC-5: OK/Done com resultado so-biblia nao toca hino', (
    tester,
  ) async {
    Hymn? selected;
    final verses = <BibleVerseRef>[
      const BibleVerseRef(
        bookId: 43,
        bookName: 'João',
        chapter: 3,
        verse: 16,
        text: 'Porque Deus amou o mundo',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          service: GlobalSearchService(),
          hymnsProvider: () async => <Hymn>[],
          versesProvider: () async => verses,
          onHymnSelected: (h) => selected = h,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'amou o mundo');
    await tester.pumpAndSettle();
    expect(find.text('João 3:16'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });

  // RF-05: digitar (onChanged) nunca chama o callback; so a acao done toca.
  testWidgets('AC-6: digitar sozinho nao chama onHymnSelected', (
    tester,
  ) async {
    Hymn? selected;
    final hymns = <Hymn>[
      Hymn(id: 7, title: 'Grande Amor', number: 5, hasInstrumental: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          service: GlobalSearchService(),
          hymnsProvider: () async => hymns,
          versesProvider: () async => <BibleVerseRef>[],
          onHymnSelected: (h) => selected = h,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'grande amor');
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsAtLeast(1));

    // Digitou, viu o resultado, nao tocou: callback permanece nulo.
    expect(selected, isNull);
  });

  // RF-01 (recomputacao): submit usa a query ATUAL, nao resultado stale.
  testWidgets('AC-7: trocar query antes do Done recomputa no submit', (
    tester,
  ) async {
    Hymn? selected;
    final hymns = <Hymn>[
      Hymn(id: 7, title: 'Grande Amor', number: 5, hasInstrumental: false),
      Hymn(id: 8, title: 'Grande Amor Eterno', number: 6, hasInstrumental: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchPage(
          service: GlobalSearchService(),
          hymnsProvider: () async => hymns,
          versesProvider: () async => <BibleVerseRef>[],
          onHymnSelected: (h) => selected = h,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 2 resultados com 'grande': nao pode tocar.
    await tester.enterText(find.byType(TextField), 'grande');
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsAtLeast(2));

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(selected, isNull);

    // Refina para query que casa exatamente 1 hino: Done toca o hino certo.
    await tester.enterText(find.byType(TextField), 'grande amor eterno');
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(selected?.id, 8);
  });
}
