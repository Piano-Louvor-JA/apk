import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bible_search_panel.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bible_smart_search.dart';

const _books = [
  BibleBook(
    id: 19,
    name: 'Salmos',
    abbreviation: 'Sl',
    chapters: 150,
    bookNumber: 19,
  ),
  BibleBook(
    id: 43,
    name: 'João',
    abbreviation: 'Jo',
    chapters: 21,
    bookNumber: 43,
  ),
];

class _Spy {
  final picked = <BibleSuggestion>[];
  final chapters = <String>[];
  final recents = <String>[];
  final examples = <String>[];
  var cleared = 0;
}

Future<_Spy> _pump(
  WidgetTester tester,
  String query, {
  List<String> recents = const [],
}) async {
  final spy = _Spy();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BibleSearchPanel(
          query: query,
          books: _books,
          recents: recents,
          onPick: spy.picked.add,
          onChapter: (b, c) => spy.chapters.add('${b.name} $c'),
          onRecent: spy.recents.add,
          onExample: spy.examples.add,
          onClearRecents: () => spy.cleared++,
        ),
      ),
    ),
  );
  return spy;
}

void main() {
  testWidgets('campo vazio mostra recentes e exemplos tocáveis', (
    tester,
  ) async {
    final spy = await _pump(tester, '', recents: ['Salmos 23']);
    await tester.tap(find.text('Salmos 23'));
    expect(spy.recents, ['Salmos 23']);
    await tester.tap(find.text('jo 3:16'));
    expect(spy.examples, ['jo 3:16']);
  });

  testWidgets('sem recentes não mostra a seção de recentes', (tester) async {
    await _pump(tester, '');
    expect(find.byKey(const Key('bible-search-recents')), findsNothing);
    expect(find.byKey(const Key('bible-search-examples')), findsOneWidget);
  });

  testWidgets('livro encontrado mostra os capítulos para tocar direto', (
    tester,
  ) async {
    final spy = await _pump(tester, 'salmos');
    expect(find.byKey(const Key('bible-search-chapters')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bible-search-chapter-1')));
    expect(spy.chapters, ['Salmos 1']);
  });

  testWidgets('referência pronta abre a passagem ao tocar', (tester) async {
    final spy = await _pump(tester, 'jo 3:16');
    await tester.tap(find.text('João 3:16'));
    expect(spy.picked.single.kind, BibleSuggestionKind.reference);
    expect(spy.picked.single.chapter, 3);
  });

  testWidgets('palavra solta oferece busca no texto', (tester) async {
    final spy = await _pump(tester, 'amor');
    await tester.tap(find.byKey(const Key('bible-search-suggestion-0')));
    expect(spy.picked.single.kind, BibleSuggestionKind.text);
  });

  testWidgets('limpar recentes', (tester) async {
    final spy = await _pump(tester, '', recents: ['amor']);
    await tester.tap(find.byKey(const Key('bible-search-clear-recents')));
    expect(spy.cleared, 1);
  });
}
