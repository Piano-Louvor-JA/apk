library;

import 'package:louvorja_piano_mobile/core/constants/api_config.dart';

/// Monta a URL de download de faixa a partir do path relativo da API.
///
/// Bug real: a API retorna paths com espacos e acentos
/// (ex: "/musics/pt/1993 - Ja e Tempo/Hino.mp3") e o request HTTP
/// quebra com caracteres nao-escapados — TODOS os downloads falhavam.
/// Cada segmento do path e encodado preservando as barras.
abstract final class DownloadUrlBuilder {
  static const _filesBase = ApiConfig.urlFiles;

  static String build(String relativeUrl) {
    final cleaned = relativeUrl.replaceFirst(RegExp(r'^/+'), '');
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      return relativeUrl;
    }
    final encoded = cleaned
        .split('/')
        .map((segment) => Uri.encodeComponent(segment))
        .join('/');
    return '$_filesBase/$encoded';
  }
}
