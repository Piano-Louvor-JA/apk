library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bible_reference_parser.dart';

void main() {
  group('BibleReferenceParser', () {
    test('referência com range: gn 1:1-3', () {
      final r = BibleReferenceParser.parse('gn 1:1-3');
      expect(r, isNotNull);
      expect(r!.bookQuery, 'gn');
      expect(r.chapter, 1);
      expect(r.verses, [1, 2, 3]);
    });

    test('versículos avulsos: genesis 2:3,5', () {
      final r = BibleReferenceParser.parse('genesis 2:3,5');
      expect(r, isNotNull);
      expect(r!.chapter, 2);
      expect(r.verses, [3, 5]);
    });

    test('misto: jo 3:1,3-5', () {
      final r = BibleReferenceParser.parse('jo 3:1,3-5');
      expect(r, isNotNull);
      expect(r!.verses, [1, 3, 4, 5]);
    });

    test('verso único: sl 23:1', () {
      final r = BibleReferenceParser.parse('sl 23:1');
      expect(r, isNotNull);
      expect(r!.chapter, 23);
      expect(r.verses, [1]);
    });

    test('capítulo inteiro: gn 1', () {
      final r = BibleReferenceParser.parse('gn 1');
      expect(r, isNotNull);
      expect(r!.chapter, 1);
      expect(r.verses, isEmpty);
    });

    test('nome com acento: gênesis 1:1-3', () {
      final r = BibleReferenceParser.parse('gênesis 1:1-3');
      expect(r, isNotNull);
      expect(r!.chapter, 1);
      expect(r.verses, [1, 2, 3]);
    });

    test('inválido devolve null: capítulo sem número', () {
      expect(BibleReferenceParser.parse('gn'), isNull);
    });

    test('inválido devolve null: texto solto', () {
      expect(BibleReferenceParser.parse('aleluia irmãos'), isNull);
    });

    test('inválido devolve null: vazio', () {
      expect(BibleReferenceParser.parse(''), isNull);
    });

    test('range invertido é normalizado: gn 1:3-1', () {
      final r = BibleReferenceParser.parse('gn 1:3-1');
      expect(r, isNotNull);
      expect(r!.verses, [1, 2, 3]);
    });

    test('formata referências para o footer do Palco', () {
      expect(BibleReferenceParser.formatVerses([1, 2, 3]), '1-3');
      expect(BibleReferenceParser.formatVerses([1, 3, 4, 5]), '1,3-5');
      expect(BibleReferenceParser.formatVerses([5, 3, 3]), '3,5');
    });
  });
}
