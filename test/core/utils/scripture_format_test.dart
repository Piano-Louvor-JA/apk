library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/utils/scripture_format.dart';

void main() {
  group('formatVerseIntervals', () {
    test('lista vazia retorna string vazia', () {
      expect(ScriptureFormat.formatVerseIntervals([]), '');
    });

    test('numero unico', () {
      expect(ScriptureFormat.formatVerseIntervals([5]), '5');
    });

    test('intervalo consecutivo', () {
      expect(ScriptureFormat.formatVerseIntervals([1, 2, 3]), '1-3');
    });

    test('intervalos mistos', () {
      expect(ScriptureFormat.formatVerseIntervals([1, 2, 3, 5]), '1-3,5');
    });

    test('multiplos intervalos', () {
      expect(
        ScriptureFormat.formatVerseIntervals([1, 2, 3, 5, 6, 7]),
        '1-3,5-7',
      );
    });

    test('numeros desordenados sao ordenados', () {
      expect(ScriptureFormat.formatVerseIntervals([5, 1, 3, 2]), '1-3,5');
    });

    test('numeros duplicados sao ignorados', () {
      expect(ScriptureFormat.formatVerseIntervals([1, 1, 2, 3]), '1-3');
    });
  });

  group('formatReference', () {
    test('formato completo com versiculos e versao', () {
      final ref = ScriptureFormat.formatReference(
        bookName: 'João',
        chapter: 3,
        verses: [16, 17],
        versionAbbreviation: 'ARA',
      );
      expect(ref, 'João 3:16-17 (ARA)');
    });

    test('sem versiculos', () {
      final ref = ScriptureFormat.formatReference(
        bookName: 'Salmos',
        chapter: 23,
      );
      expect(ref, 'Salmos 23');
    });

    test('versiculo unico', () {
      final ref = ScriptureFormat.formatReference(
        bookName: 'João',
        chapter: 3,
        verses: [16],
      );
      expect(ref, 'João 3:16');
    });

    test('sem versao', () {
      final ref = ScriptureFormat.formatReference(
        bookName: 'João',
        chapter: 3,
        verses: [16],
      );
      expect(ref, 'João 3:16');
    });

    test('sem bookName retorna vazio', () {
      final ref = ScriptureFormat.formatReference(bookName: '', chapter: 3);
      expect(ref, '');
    });

    test('chapter 0 retorna vazio', () {
      final ref = ScriptureFormat.formatReference(bookName: 'João', chapter: 0);
      expect(ref, '');
    });
  });

  group('parseVerseQuery', () {
    final verses = <String, String>{
      '1': 'v1',
      '2': 'v2',
      '3': 'v3',
      '4': 'v4',
      '5': 'v5',
    };

    test('numero unico', () {
      expect(ScriptureFormat.parseVerseQuery('3', verses), [3]);
    });

    test('intervalo', () {
      expect(ScriptureFormat.parseVerseQuery('1-3', verses), [1, 2, 3]);
    });

    test('multiplas partes', () {
      expect(ScriptureFormat.parseVerseQuery('1,3-5', verses), [1, 3, 4, 5]);
    });

    test('intervalo reversado', () {
      expect(ScriptureFormat.parseVerseQuery('5-3', verses), [3, 4, 5]);
    });

    test('numero inexistente ignorado', () {
      expect(ScriptureFormat.parseVerseQuery('99', verses), <int>[]);
    });

    test('string vazia retorna vazio', () {
      expect(ScriptureFormat.parseVerseQuery('', verses), <int>[]);
    });

    test('texto nao-numerico ignorado', () {
      expect(ScriptureFormat.parseVerseQuery('abc', verses), <int>[]);
    });

    test('parte com espaco', () {
      expect(ScriptureFormat.parseVerseQuery(' 1 , 2 ', verses), [1, 2]);
    });
  });

  group('buildText', () {
    test('concatena versiculos selecionados', () {
      final verses = <String, String>{
        '1': 'No princípio',
        '2': 'criou Deus',
        '3': 'os céus',
      };
      final text = ScriptureFormat.buildText(verses, [1, 3]);
      expect(text, 'No princípio os céus');
    });

    test('lista vazia retorna vazio', () {
      final text = ScriptureFormat.buildText({'1': 'v1'}, []);
      expect(text, '');
    });

    test('numero inexistente ignorado', () {
      final text = ScriptureFormat.buildText({'1': 'v1'}, [1, 99]);
      expect(text, 'v1');
    });
  });

  group('chapterRecordKey', () {
    test('formato correto', () {
      expect(ScriptureFormat.chapterRecordKey(1, 43, 3), 'bible_1_43_3');
    });
  });

  group('pickDefaultVersionId', () {
    test('prefere ARA', () {
      const versions = [
        BibleVersionDef(id: 2, abbreviation: 'NVI', name: 'NVI'),
        BibleVersionDef(id: 1, abbreviation: 'ARA', name: 'ARA'),
      ];
      expect(ScriptureFormat.pickDefaultVersionId(versions, null), 1);
    });

    test('usa savedId se valido', () {
      const versions = [
        BibleVersionDef(id: 1, abbreviation: 'ARA', name: 'ARA'),
        BibleVersionDef(id: 2, abbreviation: 'NVI', name: 'NVI'),
      ];
      expect(ScriptureFormat.pickDefaultVersionId(versions, 2), 2);
    });

    test('lista vazia retorna null', () {
      expect(ScriptureFormat.pickDefaultVersionId([], null), null);
    });

    test('savedId invalido cai para ARA ou primeiro', () {
      const versions = [
        BibleVersionDef(id: 5, abbreviation: 'NVI', name: 'NVI'),
      ];
      expect(ScriptureFormat.pickDefaultVersionId(versions, 99), 5);
    });
  });
}
