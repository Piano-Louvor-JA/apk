/// Stub de path_provider para Web.
///
/// No Web, getApplicationDocumentsDirectory nunca e chamado porque
/// HymnsPage usa kIsWeb para decidir. Mas o import condicional
/// precisa de uma funcao com a mesma assinatura.
library;

import 'dart:io' show Directory;

Future<Directory> getApplicationDocumentsDirectory() async {
  throw UnsupportedError(
    'getApplicationDocumentsDirectory is not available on Web',
  );
}
