// Parser de DATAPACKET (Midas/ClientDataset XML) do LouvorJA Delphi.
// Usado por itensAgendados.xml e itensAgendadosCategorias.xml.
library;

/// Uma linha <ROW .../> do DATAPACKET como mapa de atributos.
typedef DataPacketRow = Map<String, String>;

class DataPacketParser {
  DataPacketParser._();

  /// Extrai todas as ROWs de um DATAPACKET. Retorna vazio se malformado.
  static List<DataPacketRow> parse(String xml) {
    final rows = <DataPacketRow>[];
    var insideRowdata = false;
    for (final raw in xml.split('<')) {
      final tag = raw.trim();
      if (tag.toLowerCase().startsWith('rowdata')) {
        insideRowdata = true;
        continue;
      }
      if (!insideRowdata) continue;
      if (tag.toLowerCase().startsWith('row ')) {
        rows.add(_parseRowTag(tag));
      }
    }
    return rows;
  }

  static DataPacketRow _parseRowTag(String tag) {
    // tag = 'ROW ID="x" NOME="y"/>' — atributos com aspas duplas,
    // valores podem conter &amp; &lt; &gt; &quot;
    final row = <String, String>{};
    final attrRe = RegExp(r'([A-Za-z_][A-Za-z0-9_]*)="([^"]*)"');
    for (final m in attrRe.allMatches(tag)) {
      row[m.group(1)!.toUpperCase()] = _unescape(m.group(2)!);
    }
    return row;
  }

  static String _unescape(String v) => v
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"');
}
