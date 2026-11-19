/// Nome dos vídeos baixados: `<título>_<id>`, igual ao app desktop
/// (`electron/online-video/file-name.mjs`). O título perde acentos,
/// símbolos e pontuação (sobram letras e números ASCII separados por um
/// espaço) e fica com até [youtubeFileTitleMax] caracteres; o ID do YouTube
/// no fim deixa o nome único e reconhecível mesmo com título vazio.
library;

const youtubeFileTitleMax = 80;

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', //
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y', //
};

/// Título limpo: sem acento, símbolo nem pontuação, até 80 caracteres.
String sanitizeYoutubeTitle(String? title) {
  if (title == null) return '';
  final out = StringBuffer();
  for (final rune in title.runes) {
    final ch = String.fromCharCode(rune);
    final lower = ch.toLowerCase();
    final plain = _accents[lower];
    if (plain != null) {
      out.write(ch == lower ? plain : plain.toUpperCase());
    } else {
      out.write(ch);
    }
  }
  final clean = out.toString().replaceAll(RegExp('[^A-Za-z0-9]+'), ' ').trim();
  final cut = clean.length > youtubeFileTitleMax
      ? clean.substring(0, youtubeFileTitleMax)
      : clean;
  return cut.trim();
}

/// Nome sem extensão: `<título limpo>_<id>`, ou só o ID quando não há
/// título (o app guarda o próprio ID como título nesse caso).
String youtubeFileBase(String? title, String videoId) {
  final clean = sanitizeYoutubeTitle(title);
  return clean.isEmpty || clean == videoId ? videoId : '${clean}_$videoId';
}

/// Nome com extensão.
String youtubeFileName(String? title, String videoId) =>
    '${youtubeFileBase(title, videoId)}.mp4';

/// Parte editável de `<título>_<id>.mp4` (o que vem antes do `_<id>`).
String editableYoutubeTitle(String? fileName, String videoId) {
  if (fileName == null || fileName.isEmpty) return '';
  final base = fileName.endsWith('.mp4')
      ? fileName.substring(0, fileName.length - 4)
      : fileName;
  if (base == videoId) return '';
  final suffix = '_$videoId';
  return base.endsWith(suffix)
      ? base.substring(0, base.length - suffix.length)
      : base;
}
