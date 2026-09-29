// ignore_for_file: unrelated_type_equality_checks, unnecessary_null_comparison
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_chapter.dart';

void main() {
  group('BibleBook', () {
    test('fromJson mapeia campos do catalogo', () {
      final book = BibleBook.fromJson({
        'id_bible_book': 1,
        'name': 'Gênesis',
        'abbreviation': 'Gn',
        'chapters': 50,
        'book_number': 1,
        'id_language': 'pt',
      });
      expect(book.id, 1);
      expect(book.name, 'Gênesis');
      expect(book.abbreviation, 'Gn');
      expect(book.chapters, 50);
      expect(book.bookNumber, 1);
      expect(book.languageId, 'pt');
    });

    test('fromJson com dados faltantes usa defaults', () {
      final book = BibleBook.fromJson({});
      expect(book.id, 0);
      expect(book.name, '');
      expect(book.chapters, 0);
      expect(book.bookNumber, 0);
      expect(book.languageId, 'pt');
    });

    test('fromJson com tipos numericos alternativos', () {
      final book = BibleBook.fromJson({
        'id_bible_book': '43',
        'name': 'João',
        'abbreviation': 'Jo',
        'chapters': 21.0,
        'book_number': '43',
      });
      expect(book.id, 43);
      expect(book.chapters, 21);
      expect(book.bookNumber, 43);
    });

    test('testament: AT quando bookNumber <= 39', () {
      const book = BibleBook(
        id: 1,
        name: 'Gênesis',
        abbreviation: 'Gn',
        chapters: 50,
        bookNumber: 1,
      );
      expect(book.testament, BibleTestament.ot);
    });

    test('testament: NT quando bookNumber >= 40', () {
      const book = BibleBook(
        id: 40,
        name: 'Mateus',
        abbreviation: 'Mt',
        chapters: 28,
        bookNumber: 40,
      );
      expect(book.testament, BibleTestament.nt);
    });

    test('tone: law para bookNumber 1-5', () {
      const genesis = BibleBook(
        id: 1,
        name: 'Gn',
        abbreviation: 'Gn',
        chapters: 50,
        bookNumber: 1,
      );
      expect(genesis.tone, BibleBookTone.law);
    });

    test('tone: history para bookNumber 6-17', () {
      const joshua = BibleBook(
        id: 6,
        name: 'Js',
        abbreviation: 'Js',
        chapters: 24,
        bookNumber: 6,
      );
      expect(joshua.tone, BibleBookTone.history);
    });

    test('tone: prophets para bookNumber 18-39', () {
      const job = BibleBook(
        id: 18,
        name: 'Jó',
        abbreviation: 'Jó',
        chapters: 42,
        bookNumber: 18,
      );
      expect(job.tone, BibleBookTone.prophets);
    });

    test('tone: gospels para bookNumber 40-43', () {
      const matthew = BibleBook(
        id: 40,
        name: 'Mt',
        abbreviation: 'Mt',
        chapters: 28,
        bookNumber: 40,
      );
      expect(matthew.tone, BibleBookTone.gospels);
    });

    test('tone: letters para bookNumber 44-66', () {
      const acts = BibleBook(
        id: 44,
        name: 'At',
        abbreviation: 'At',
        chapters: 28,
        bookNumber: 44,
      );
      expect(acts.tone, BibleBookTone.letters);
    });

    test('== por id', () {
      const a = BibleBook(
        id: 1,
        name: 'A',
        abbreviation: 'a',
        chapters: 1,
        bookNumber: 1,
      );
      const b = BibleBook(
        id: 1,
        name: 'B',
        abbreviation: 'b',
        chapters: 2,
        bookNumber: 2,
      );
      expect(a == b, true);
    });

    test('!= por id diferente', () {
      const a = BibleBook(
        id: 1,
        name: 'A',
        abbreviation: 'a',
        chapters: 1,
        bookNumber: 1,
      );
      const b = BibleBook(
        id: 2,
        name: 'A',
        abbreviation: 'a',
        chapters: 1,
        bookNumber: 1,
      );
      expect(a == b, false);
    });

    test('hashCode consistente', () {
      const a = BibleBook(
        id: 1,
        name: 'A',
        abbreviation: 'a',
        chapters: 1,
        bookNumber: 1,
      );
      const b = BibleBook(
        id: 1,
        name: 'B',
        abbreviation: 'b',
        chapters: 2,
        bookNumber: 2,
      );
      expect(a.hashCode, b.hashCode);
    });

    test('toString contem id e name', () {
      const book = BibleBook(
        id: 43,
        name: 'João',
        abbreviation: 'Jo',
        chapters: 21,
        bookNumber: 43,
      );
      expect(book.toString(), contains('João'));
    });
  });

  group('BibleVersion', () {
    test('fromJson mapeia campos', () {
      final v = BibleVersion.fromJson({
        'id_bible_version': 1,
        'abbreviation': 'ARA',
        'name': 'Almeida Revista e Atualizada',
        'id_language': 'pt',
      });
      expect(v.id, 1);
      expect(v.abbreviation, 'ARA');
      expect(v.name, 'Almeida Revista e Atualizada');
      expect(v.languageId, 'pt');
    });

    test('fromJson com dados faltantes', () {
      final v = BibleVersion.fromJson({});
      expect(v.id, 0);
      expect(v.abbreviation, '');
      expect(v.name, '');
      expect(v.languageId, 'pt');
    });

    test('fromJson com string numerica', () {
      final v = BibleVersion.fromJson({
        'id_bible_version': '5',
        'abbreviation': 'NVI',
        'name': 'Nova Versão Internacional',
      });
      expect(v.id, 5);
    });

    test('== por id', () {
      const a = BibleVersion(id: 1, abbreviation: 'ARA', name: 'A');
      const b = BibleVersion(id: 1, abbreviation: 'NVI', name: 'B');
      expect(a == b, true);
    });

    test('toString', () {
      const v = BibleVersion(id: 1, abbreviation: 'ARA', name: 'Almeida');
      expect(v.toString(), contains('ARA'));
    });

    test('hashCode consistente', () {
      const a = BibleVersion(id: 1, abbreviation: 'A', name: 'X');
      const b = BibleVersion(id: 1, abbreviation: 'B', name: 'Y');
      expect(a.hashCode, b.hashCode);
    });

    test('== tipo diferente', () {
      expect(
        const BibleVersion(id: 1, abbreviation: 'A', name: 'X') == 'str',
        false,
      );
      expect(
        const BibleVersion(id: 1, abbreviation: 'A', name: 'X') == 42,
        false,
      );
    });

    test('identical', () {
      const a = BibleVersion(id: 1, abbreviation: 'A', name: 'X');
      expect(a == a, true);
    });
  });

  group('BibleChapter', () {
    test('cria com Map de versiculos', () {
      final ch = BibleChapter(verses: {'1': 'No princípio', '2': 'E a terra'});
      expect(ch.verses.length, 2);
      expect(ch.verses['1'], 'No princípio');
    });

    test('sortedVerses retorna em ordem numerica', () {
      final ch = BibleChapter(verses: {'3': 'C', '1': 'A', '2': 'B'});
      final sorted = ch.sortedVerseEntries;
      expect(sorted[0].number, 1);
      expect(sorted[1].number, 2);
      expect(sorted[2].number, 3);
    });

    test('isEmpty quando sem versiculos', () {
      const ch = BibleChapter(verses: {});
      expect(ch.isEmpty, true);
      expect(ch.isNotEmpty, false);
    });

    test('isNotEmpty quando tem versiculos', () {
      final ch = BibleChapter(verses: {'1': 'texto'});
      expect(ch.isNotEmpty, true);
      expect(ch.isEmpty, false);
    });
  });
}
