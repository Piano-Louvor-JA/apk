library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/ja_liturgy_parser.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

const _sample = '''
[item_20260704084840569]
tipo=musica
item=Momentos de louvor
cor=\$004F0000
escolha=0
musica=1660
subtipo=div
subitem=Música Missão (Adoradores 4)
checked=22/08/2026

[item_20260704085317501]
tipo=arquivo
item=Abertura escola sabatina
cor=\$004F0000
subtipo=arq
subitem=Arquivo C:\\Users\\iasdn\\Videos\\video.mp4
dir=C:\\Users\\iasdn\\Videos\\video.mp4
dir_info=E
checked=

[item_20260704085517828]
tipo=anotacao
item=Oração
cor=\$004F0000
subitem=
checked=

[Geral]
7=item_20260704084840569;item_20260704085317501;item_20260704085517828;
6=item_20260704084840569_d6_i0;item_20260704085317501_d6_i0;
''';

void main() {
  test('parse completo: dias, tipos, campos', () {
    final map = JaLiturgyParser.parse(_sample);
    expect(map.keys, containsAll([6, 7]));

    final sun = map[7]!;
    expect(sun.length, 3);
    expect(sun[0].type, LiturgyItemType.music);
    expect(sun[0].musicId, 1660);
    expect(sun[0].name, 'Momentos de louvor');
    expect(sun[0].subtitle, contains('Adoradores 4'));
    expect(sun[0].done, isFalse); // checked=22/08/2026 != hoje
    expect(sun[1].type, LiturgyItemType.video);
    expect(sun[1].filePath, contains('video.mp4'));
    expect(sun[1].done, isFalse);
    expect(sun[2].type, LiturgyItemType.annotation);
  });

  test('dedup: _d6_i0 resolve pro mesmo item (ids iguais)', () {
    final map = JaLiturgyParser.parse(_sample);
    final sat = map[6]!;
    expect(sat.length, 2);
    expect(sat[0].id, map[7]![0].id);
  });

  test(r'cor Delphi $00BBGGRR converte pra #RRGGBB', () {
    final map = JaLiturgyParser.parse(_sample);
    // \$004F0000: BB=4F? não — layout: 00 BB GG RR = 00 4F 00 00 → r=00,g=00,b=4F
    expect(map[7]![0].accentColor, '#00004F');
  });

  test('BOM + CRLF não quebram o parse', () {
    final crlf = _sample.replaceAll('\n', '\r\n');
    final withBom = '\uFEFF$crlf';
    final map = JaLiturgyParser.parse(withBom);
    expect(map[7]!.length, 3);
  });

  test('extensão decide tipo de arquivo', () {
    final mkv = _sample.replaceAll('video.mp4', 'clipe.mkv');
    expect(JaLiturgyParser.parse(mkv)[7]![1].type, LiturgyItemType.video);
    final pdf = _sample.replaceAll('video.mp4', 'ensaio.pdf');
    expect(JaLiturgyParser.parse(pdf)[7]![1].type, LiturgyItemType.pdf);
    final pptx = _sample.replaceAll('video.mp4', 'slides.pptx');
    expect(
      JaLiturgyParser.parse(pptx)[7]![1].type,
      LiturgyItemType.presentation,
    );
  });

  test('sem [Geral] lança FormatException', () {
    expect(
      () => JaLiturgyParser.parse('[item_x]\ntipo=musica\nitem=A\n'),
      throwsFormatException,
    );
  });

  test('tipo desconhecido é pulado sem quebrar', () {
    final withUnknown = _sample.replaceAll(
      'tipo=anotacao',
      'tipo=coisadesconhecida',
    );
    final map = JaLiturgyParser.parse(withUnknown);
    expect(map[7]!.length, 2);
  });

  test('decodeJaFile: UTF-8 com BOM preserva acentos', () {
    final bytes = utf8.encode('\uFEFFsubitem=Música Missão');
    expect(decodeJaFile(bytes), contains('Música'));
  });

  test('decodeJaFile: ANSI (cp1252) decodifica acentos', () {
    // 'Música' em Windows-1252: M ú s i c a
    final bytes = [0x4D, 0xFA, 0x73, 0x69, 0x63, 0x61];
    expect(decodeJaFile(bytes), 'Música');
  });

  test('dir vazio → otherFiles', () {
    final empty = _sample.replaceAll(
      'dir=C:\\Users\\iasdn\\Videos\\video.mp4',
      'dir=',
    );
    expect(
      JaLiturgyParser.parse(empty)[7]![1].type,
      LiturgyItemType.otherFiles,
    );
  });
  test('checked com data de HOJE => done; data antiga => não', () {
    final hoje = DateTime.now();
    final dd = hoje.day.toString().padLeft(2, '0');
    final mm = hoje.month.toString().padLeft(2, '0');
    final yyyy = hoje.year.toString();
    final sample =
        '[item_a]\r\ntipo=anotacao\r\nitem=X\r\nchecked=$dd/$mm/$yyyy\r\n\r\n[Geral]\r\n7=item_a;\r\n';
    final map = JaLiturgyParser.parse(sample);
    expect(map[7]!.single.done, isTrue);

    final ontem =
        '[item_b]\r\ntipo=anotacao\r\nitem=Y\r\nchecked=01/01/2020\r\n\r\n[Geral]\r\n7=item_b;\r\n';
    final map2 = JaLiturgyParser.parse(ontem);
    expect(map2[7]!.single.done, isFalse);
  });
}
// (testes de encoding no bloco abaixo)
