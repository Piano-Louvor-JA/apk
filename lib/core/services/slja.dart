/// Parser/gerador do formato .slja (LouvorJA Delphi) — port do slja.ts web.
///
/// Formato: ZIP contendo:
/// - slides.lja — INI (TMemIniFile) com a apresentação
/// - audio/<nome>.mp3 — áudio (opcional)
/// - imagens/<nome> — backgrounds referenciados (dedup)
///
/// INI de 2 níveis: [Geral] + [Slide:1]...[Slide:N]
/// Quebra de linha em `letra` = pipe | (CR/LF viram |)
/// Codificação do INI: Windows-1252/Latin-1 (não UTF-8).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class SljaSlide {
  final String lyric;
  final String? auxiliaryLyric;
  final String type; // 'CAPA' | 'LETRA'
  final int timeMs;
  final String? textColor;
  final String? boxColor;
  final String? backgroundColor;
  final String? imageName;
  final int? imagePosition;
  final bool? textBox;
  final int? fontSize;
  final int? auxiliaryFontSize;

  const SljaSlide({
    required this.lyric,
    required this.type,
    required this.timeMs,
    this.auxiliaryLyric,
    this.textColor,
    this.boxColor,
    this.backgroundColor,
    this.imageName,
    this.imagePosition,
    this.textBox,
    this.fontSize,
    this.auxiliaryFontSize,
  });
}

class SljaAudio {
  final String name;
  final List<int> bytes;
  const SljaAudio({required this.name, required this.bytes});
}

class SljaAsset {
  final String path;
  final List<int> bytes;
  const SljaAsset({required this.path, required this.bytes});
}

class SljaArchive {
  final String title;
  final SljaAudio? audio;
  final List<SljaAsset> assets;
  final List<SljaSlide> slides;
  const SljaArchive({
    required this.title,
    required this.slides,
    this.audio,
    this.assets = const [],
  });
}

/// Lê um .slja (bytes do ZIP) e retorna [SljaArchive].
SljaArchive parseSlja(List<int> zipBytes) {
  var bytes = zipBytes;

  // .slja.zip (recebido via WhatsApp/mensageiro): um zip contendo o .slja
  // (que por sua vez é zip). Detecta e desembrulha um nível.
  try {
    final first = ZipDecoder().decodeBytes(bytes);
    final inner = first.files
        .where((f) => f.isFile && f.name.toLowerCase().endsWith('.slja'))
        .toList();
    if (inner.isNotEmpty) {
      bytes = inner.first.readBytes()!;
    }
  } on FormatException {
    // Não era zip no primeiro nível — segue (deve ser o próprio .slja).
  }

  final archive = ZipDecoder().decodeBytes(bytes);

  // Normaliza chaves: Delphi pode usar backslash (audio\..., imagens\...).
  final entries = <String, ArchiveFile>{};
  for (final f in archive.files) {
    entries[f.name.replaceAll('\\', '/')] = f;
  }

  final iniFile = entries['slides.lja'];
  if (iniFile == null) {
    throw const FormatException('slides.lja não encontrado no .slja');
  }
  // INI do Delphi usa Latin-1, não UTF-8.
  final ini = latin1.decode(iniFile.readBytes()!);

  final iniData = _parseIni(ini);
  final geral = iniData['Geral'] ?? {};
  final slidesCount = int.tryParse(geral['slides'] ?? '0') ?? 0;
  final title = geral['titulo']?.isNotEmpty == true
      ? geral['titulo']!
      : (geral['versao'] != null ? 'v${geral['versao']}' : 'Sem título');

  // Áudio
  SljaAudio? audio;
  if (geral['audio'] == '1' && geral['url_musica'] != null) {
    final audioName = geral['url_musica']!.replaceFirst(
      RegExp(r'^audio[/\\]'),
      '',
    );
    final audioFile = entries['audio/$audioName'];
    if (audioFile != null) {
      audio = SljaAudio(name: audioName, bytes: audioFile.readBytes()!);
    }
  }

  // Assets (imagens)
  final assets = <SljaAsset>[];
  for (final entry in entries.entries) {
    if (entry.key.startsWith('imagens/')) {
      assets.add(
        SljaAsset(
          path: entry.key.substring('imagens/'.length),
          bytes: entry.value.readBytes()!,
        ),
      );
    }
  }

  // Slides
  final slides = <SljaSlide>[];
  for (var i = 1; i <= slidesCount; i++) {
    final section = iniData['Slide:$i'];
    if (section == null) continue;
    final slide = _parseSlideSection(section, i);
    if (slide != null) slides.add(slide);
  }

  return SljaArchive(
    title: title,
    audio: audio,
    assets: assets,
    slides: slides,
  );
}

/// Gera os bytes de um .slja a partir de [archive].
Uint8List buildSlja(SljaArchive archive) {
  final files = <String, List<int>>{};
  files['slides.lja'] = latin1.encode(_generateIni(archive));
  if (archive.audio != null) {
    files['audio/${archive.audio!.name}'] = archive.audio!.bytes;
  }
  final seen = <String>{};
  for (final asset in archive.assets) {
    if (seen.add(asset.path)) {
      files['imagens/${asset.path}'] = asset.bytes;
    }
  }

  final a = Archive();
  for (final e in files.entries) {
    a.addFile(ArchiveFile.bytes(e.key, e.value));
  }
  final zip = ZipEncoder().encode(a);
  return Uint8List.fromList(zip);
}

// ===== INI =====

Map<String, Map<String, String>> _parseIni(String ini) {
  final result = <String, Map<String, String>>{};
  var current = '';
  for (final line in ini.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith(';') || trimmed.startsWith('#')) {
      continue;
    }
    final section = RegExp(r'^\[(.+)\]$').firstMatch(trimmed);
    if (section != null) {
      current = section.group(1)!;
      result[current] = {};
      continue;
    }
    final eq = trimmed.indexOf('=');
    if (eq > 0 && current.isNotEmpty) {
      result[current]![trimmed.substring(0, eq).trim()] = trimmed
          .substring(eq + 1)
          .trim();
    }
  }
  return result;
}

String _generateIni(SljaArchive archive) {
  final lines = <String>[];
  lines.add('[Geral]');
  lines.add('slides=${archive.slides.length}');
  lines.add('versao=2.0');
  lines.add('titulo=${archive.title}');
  if (archive.audio != null) {
    lines.add('url_musica=audio\\${archive.audio!.name}');
    lines.add('audio=1');
  } else {
    lines.add('audio=0');
  }
  lines.add('');

  for (var i = 0; i < archive.slides.length; i++) {
    final s = archive.slides[i];
    lines.add('[Slide:${i + 1}]');
    lines.add('tipo=${s.type}');
    lines.add('letra=${s.lyric.replaceAll('\n', '|')}');
    if (s.auxiliaryLyric != null) {
      lines.add('letra_aux=${s.auxiliaryLyric!.replaceAll('\n', '|')}');
    }
    if (s.timeMs > 0) lines.add('tempo_hms=${_msToHms(s.timeMs)}');
    if (s.textColor != null) lines.add('cor_letra=${s.textColor}');
    if (s.boxColor != null) lines.add('cor_fundo=${s.boxColor}');
    if (s.backgroundColor != null) {
      lines.add('cor_fundo=${s.backgroundColor}');
    }
    if (s.imageName != null) lines.add('imagem=imagens\\${s.imageName}');
    if (s.imagePosition != null) {
      lines.add('imagem_posicao=${s.imagePosition}');
    }
    if (s.textBox != null) lines.add('fundo_letra=${s.textBox! ? '1' : '0'}');
    if (s.fontSize != null) lines.add('tamanho_letra=${s.fontSize}');
    if (s.auxiliaryFontSize != null) {
      lines.add('tamanho_letra_aux=${s.auxiliaryFontSize}');
    }
    lines.add('');
  }
  return lines.join('\r\n');
}

SljaSlide? _parseSlideSection(Map<String, String> section, int index) {
  final type = section['tipo'] ?? (index == 1 ? 'CAPA' : 'LETRA');
  final lyric = (section['letra'] ?? '').replaceAll('|', '\n');
  final aux = section['letra_aux']?.replaceAll('|', '\n');

  var timeMs = 0;
  final hms = section['tempo_hms'];
  if (hms != null && hms.isNotEmpty) {
    timeMs = _hmsToMs(hms);
  } else if (section['tempo'] != null) {
    // Fallback: tempo em bytes do BASS (~176400 bytes/s @ 44.1kHz stereo 16bit)
    final bytes = int.tryParse(section['tempo']!);
    if (bytes != null) timeMs = (bytes / 176400 * 1000).round();
  }

  String? boxColor;
  String? backgroundColor;
  final corFundo = section['cor_fundo'];
  if (corFundo != null && corFundo.isNotEmpty) {
    if (section['fundo_letra'] == '1') {
      boxColor = corFundo;
    } else {
      backgroundColor = corFundo;
    }
  }

  String? imageName;
  final imagem = section['imagem'];
  if (imagem != null && imagem.isNotEmpty) {
    imageName = imagem.replaceFirst(RegExp(r'^imagens[/\\]'), '');
  }

  return SljaSlide(
    lyric: lyric,
    type: type,
    timeMs: timeMs,
    auxiliaryLyric: (aux != null && aux.isNotEmpty) ? aux : null,
    textColor: section['cor_letra'],
    boxColor: boxColor,
    backgroundColor: backgroundColor,
    imageName: imageName,
    imagePosition: int.tryParse(section['imagem_posicao'] ?? ''),
    textBox: section['fundo_letra'] == null
        ? null
        : section['fundo_letra'] == '1',
    fontSize: int.tryParse(section['tamanho_letra'] ?? ''),
    auxiliaryFontSize: int.tryParse(section['tamanho_letra_aux'] ?? ''),
  );
}

String _msToHms(int ms) {
  final totalSeconds = ms ~/ 1000;
  final h = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
  final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

int _hmsToMs(String hms) {
  final parts = hms.split(':').map(int.tryParse).toList();
  if (parts.length == 3) {
    return (parts[0]! * 3600 + parts[1]! * 60 + parts[2]!) * 1000;
  }
  if (parts.length == 2) {
    return (parts[0]! * 60 + parts[1]!) * 1000;
  }
  return 0;
}
