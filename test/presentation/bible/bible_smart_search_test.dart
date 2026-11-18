import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bible_smart_search.dart';

// Recorte do catálogo real (pt_bible_book): nomes com algarismo romano,
// abreviações com dígito e o par Jó/Jo que só difere no acento.
const _raw = [
  [1, 'Gênesis', 'Gn', 50],
  [9, 'I Samuel', '1Sm', 31],
  [10, 'II Samuel', '2Sm', 24],
  [18, 'Jó', 'Jó', 42],
  [19, 'Salmos', 'Sl', 150],
  [22, 'Cantares de Salomão', 'Cn', 8],
  [29, 'Joel', 'Jl', 3],
  [32, 'Jonas', 'Jn', 4],
  [6, 'Josué', 'Js', 24],
  [43, 'João', 'Jo', 21],
  [46, 'I Coríntios', '1Co', 16],
  [47, 'II Coríntios', '2Co', 13],
  [62, 'I João', '1Jo', 5],
  [66, 'Apocalipse', 'Ap', 22],
];

final books = [
  for (final r in _raw)
    BibleBook(
      id: r[0] as int,
      name: r[1] as String,
      abbreviation: r[2] as String,
      chapters: r[3] as int,
      bookNumber: r[0] as int,
    ),
];

List<BibleSuggestion> s(String q) => BibleSmartSearch.suggest(q, books);

BibleSuggestion first(String q) {
  final r = s(q);
  expect(r, isNotEmpty, reason: 'sem sugestão para "$q"');
  return r.first;
}

void expectRef(
  String q,
  String book,
  int chapter, [
  List<int> verses = const [],
]) {
  final f = first(q);
  expect(f.kind, BibleSuggestionKind.reference, reason: q);
  expect(f.book!.name, book, reason: q);
  expect(f.chapter, chapter, reason: q);
  expect(f.verses, verses, reason: q);
}

void main() {
  group('referências em vários jeitos de escrever', () {
    test('formato clássico', () {
      expectRef('jo 3:16', 'João', 3, [16]);
      expectRef('Gn 1:1-3', 'Gênesis', 1, [1, 2, 3]);
      expectRef('gn 1:1,3-5', 'Gênesis', 1, [1, 3, 4, 5]);
    });

    test('ponto, vírgula ou espaço separando capítulo e versículo', () {
      expectRef('jo 3.16', 'João', 3, [16]);
      expectRef('jo 3,16', 'João', 3, [16]);
      expectRef('jo 3 16', 'João', 3, [16]);
    });

    test('sem espaço entre livro e capítulo', () {
      expectRef('jo3:16', 'João', 3, [16]);
      expectRef('sl23', 'Salmos', 23);
    });

    test('nome completo, sem acento e maiúsculas', () {
      expectRef('genesis 1', 'Gênesis', 1);
      expectRef('SALMOS 23', 'Salmos', 23);
      expectRef('Salmo 23', 'Salmos', 23);
    });

    test('livros numerados: dígito, espaço, romano ou por extenso', () {
      expectRef('1co 13', 'I Coríntios', 13);
      expectRef('1 co 13:4-7', 'I Coríntios', 13, [4, 5, 6, 7]);
      expectRef('1 coríntios 13', 'I Coríntios', 13);
      expectRef('i coríntios 13', 'I Coríntios', 13);
      expectRef('2 sm 7', 'II Samuel', 7);
      expectRef('primeira corintios 13', 'I Coríntios', 13);
      expectRef('segundo samuel 7', 'II Samuel', 7);
    });

    test('nomes compostos', () {
      expectRef('cantares de salomão 2', 'Cantares de Salomão', 2);
      expectRef('cantares 2', 'Cantares de Salomão', 2);
      expectRef('canticos 2', 'Cantares de Salomão', 2);
    });

    test('intervalo invertido e traço tipográfico', () {
      expectRef('jo 3:18-16', 'João', 3, [16, 17, 18]);
      expectRef('jo 3:16–18', 'João', 3, [16, 17, 18]);
    });
  });

  group('Jó × João (só o acento muda)', () {
    test('"jo" é João; "jó" é Jó', () {
      expectRef('jo 1', 'João', 1);
      expectRef('jó 1', 'Jó', 1);
    });

    test('capítulo que João não tem cai em Jó', () {
      expectRef('jo 38', 'Jó', 38);
    });

    test('"jo" sem capítulo lista João primeiro e os outros "Jo…" depois', () {
      final names = s('jo')
          .where((x) => x.kind == BibleSuggestionKind.book)
          .map((x) => x.book!.name)
          .toList();
      expect(names.first, 'João');
      expect(names, containsAll(['Jó', 'Joel', 'Jonas', 'Josué']));
    });
  });

  group('sugestões enquanto digita', () {
    test('prefixo do nome sugere o livro', () {
      final f = first('apoc');
      expect(f.kind, BibleSuggestionKind.book);
      expect(f.book!.name, 'Apocalipse');
    });

    test('palavra do meio do nome também acha', () {
      final names = s('corintios').map((x) => x.book?.name).toList();
      expect(names, containsAll(['I Coríntios', 'II Coríntios']));
    });

    test('nome ambíguo com capítulo sugere cada livro que tem o capítulo', () {
      final refs = s('corintios 13')
          .where((x) => x.kind == BibleSuggestionKind.reference)
          .map((x) => x.label)
          .toList();
      expect(refs, ['I Coríntios 13', 'II Coríntios 13']);
    });

    test('capítulo inexistente não vira referência', () {
      final r = s('jn 9');
      expect(r.where((x) => x.kind == BibleSuggestionKind.reference), isEmpty);
      expect(r.first.book!.name, 'Jonas');
    });

    test('palavra que não é livro vira busca no texto', () {
      final r = s('amor');
      expect(r.single.kind, BibleSuggestionKind.text);
      expect(r.single.query, 'amor');
    });

    test('palavra que começa como livro oferece livro e busca no texto', () {
      final r = s('jona');
      expect(r.first.book!.name, 'Jonas');
      expect(r.last.kind, BibleSuggestionKind.text);
    });

    test('enquanto digita (":" ou "-" no fim) já sugere a referência', () {
      expectRef('jo 3:', 'João', 3);
      expectRef('jo 3:16-', 'João', 3, [16]);
      expectRef('jo 3:16,', 'João', 3, [16]);
    });

    test('só números não sugere nada', () {
      expect(s('316'), isEmpty);
    });

    test('frase longa é busca no texto', () {
      expect(first('no princípio criou deus').kind, BibleSuggestionKind.text);
    });

    test('vazio ou só espaços não sugere nada', () {
      expect(s(''), isEmpty);
      expect(s('   '), isEmpty);
    });

    test('rótulo da referência', () {
      expect(first('jo 3:16-18').label, 'João 3:16-18');
      expect(first('gn 1:1,3-5').label, 'Gênesis 1:1,3-5');
      expect(first('sl 23').label, 'Salmos 23');
    });
  });
}
