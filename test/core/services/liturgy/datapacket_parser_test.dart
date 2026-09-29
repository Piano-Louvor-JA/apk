// Testes do parser DATAPACKET com o arquivo REAL de categorias do Rafael.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/datapacket_parser.dart';

void main() {
  // Arquivo REAL do Rafael, fora do repo: teste só roda onde ele existe
  // (padrão do repo — igual media_duration_reader_test).
  const realFile =
      '/media/rafaelejosi/NovoVolume/nvme-mint/Downloads/itensAgendadosCategorias.xml';

  test('arquivo real de categorias: 1 ROW Provai e Vede', () {
    if (!File(realFile).existsSync()) {
      // ignore: avoid_print
      print('skip: arquivo de teste ausente');
      return;
    }
    final xml = File(realFile).readAsStringSync();
    final rows = DataPacketParser.parse(xml);
    expect(rows, hasLength(1));
    expect(rows.first['ID'], '11072026102847075');
    expect(rows.first['NOME'], 'Provai e Vede');
  });

  test('multiplas rows, atributos ausentes, escapes', () {
    const xml =
        '<?xml version="1.0" standalone="yes"?><DATAPACKET Version="2.0">'
        '<METADATA><FIELDS/><PARAMS/></METADATA><ROWDATA>'
        '<ROW ID="a1" NOME="Culto Jovem &amp; Louvor" ARQUIVO_INFO="I"/>'
        '<ROW ID="a2" NOME="Serm&amp;#227;o"/>'
        '<ROW ID="a3"/>'
        '</ROWDATA></DATAPACKET>';
    final rows = DataPacketParser.parse(xml);
    expect(rows, hasLength(3));
    expect(rows[0]['NOME'], 'Culto Jovem & Louvor');
    expect(rows[0]['ARQUIVO_INFO'], 'I');
    // atributo ausente → chave não presente (não null crash)
    expect(rows[1].containsKey('ARQUIVO'), isFalse);
    expect(rows[2]['ID'], 'a3');
  });

  test('sem ROWDATA → vazio, sem crash', () {
    const xml = '<DATAPACKET Version="2.0"><METADATA/><PARAMS/></DATAPACKET>';
    expect(DataPacketParser.parse(xml), isEmpty);
  });

  test('row minúscula também aceita', () {
    const xml = '<ROWDATA><row ID="x1" NOME="min"/></ROWDATA>';
    final rows = DataPacketParser.parse(xml);
    expect(rows.first['NOME'], 'min');
  });
}
