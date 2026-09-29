library;

import 'dart:convert';

import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

/// Resultado do parse: itens por dia (chave 1..7 = segunda..domingo, padrão
/// do formato .ja do Delphi LouvorJA).
typedef JaLiturgy = Map<int, List<LiturgyItem>>;

/// Parser do formato `.ja` exportado pelo LouvorJA Delphi.
///
/// Formato (spec extraída de arquivo real 2026-08-23):
/// - UTF-8 com BOM, CRLF, estilo INI
/// - `[item_<ts>[_d<dia>_i<n>]]` com campos tipo/item/cor/subtipo/subitem/
///   musica/dir/checked
/// - `[Geral]` com chaves `1..7` listando ids na ordem, separados por `;`
///
/// IDs Delphi de música são compatíveis com a API louvorja.com.br
/// (verificado: music_2000 = "Mãos" Hinário Adventista).
abstract final class JaLiturgyParser {
  /// Faz o parse; lança [FormatException] em arquivo estruturalmente inválido
  /// (sem seção [Geral] ou sem nenhum item).
  static JaLiturgy parse(String raw) {
    // BOM + CRLF
    var text = raw;
    if (text.startsWith('\uFEFF')) text = text.substring(1);

    final sections = <String, Map<String, String>>{};
    String? current;
    for (final line_ in text.split('\n')) {
      final line = line_.trim();
      if (line.isEmpty) continue;
      final sec = _sectionRe.firstMatch(line);
      if (sec != null) {
        current = sec.group(1)!.toLowerCase();
        sections[current] = {};
        continue;
      }
      if (current == null) continue;
      final kv = _kvRe.firstMatch(line);
      if (kv != null) {
        sections[current]![kv.group(1)!.toLowerCase()] = kv.group(2) ?? '';
      }
    }

    if (!sections.containsKey('geral')) {
      throw const FormatException('Arquivo .ja sem seção [Geral]');
    }

    // Itens por id de seção.
    final itemsById = <String, LiturgyItem>{};
    for (final entry in sections.entries) {
      if (entry.key == 'geral') continue;
      final item = _parseItem(entry.key, entry.value);
      if (item != null) {
        // Dedup: id base sem sufixo _dN_iM manda (mesma entrada referenciada
        // em vários dias).
        final baseId = _baseId(entry.key);
        itemsById.putIfAbsent(baseId, () => item);
      }
    }
    if (itemsById.isEmpty) {
      throw const FormatException('Arquivo .ja sem itens de liturgia');
    }

    // Ordem por dia: [Geral] chaves 1..7.
    final result = <int, List<LiturgyItem>>{};
    final geral = sections['geral']!;
    for (final day in geral.keys) {
      final dayNum = int.tryParse(day);
      if (dayNum == null || dayNum < 1 || dayNum > 7) continue;
      final list = <LiturgyItem>[];
      for (final ref in (geral[day] ?? '').split(';')) {
        final id = ref.trim().toLowerCase();
        if (id.isEmpty) continue;
        final item = itemsById[_baseId(id)];
        if (item != null) list.add(item);
      }
      if (list.isNotEmpty) result[dayNum] = list;
    }
    if (result.isEmpty) {
      throw const FormatException('[Geral] sem ordem de itens por dia');
    }
    return result;
  }

  static final _sectionRe = RegExp(r'^\[(.+)\]$');
  static final _kvRe = RegExp(r'^([^=]+)=(.*)$');

  /// Remove sufixo `_d<dia>_i<n>` (referência duplicada em outro dia).
  static String _baseId(String id) => id.replaceAll(RegExp(r'_d\d+_i\d+$'), '');

  static LiturgyItem? _parseItem(String id, Map<String, String> f) {
    final tipo = f['tipo']?.trim().toLowerCase();
    final name = f['item'] ?? '';
    final subitem = f['subitem'] ?? '';
    final checked = f['checked'] ?? '';
    // Semântica Delphi: checked guarda a DATA (dd/mm/aaaa) em que foi
    // marcado; só está done se == HOJE (reset automático na virada do dia —
    // fmMenu.pas compara com FormatDateTime('dd/mm/yyyy', Now)).
    bool isDoneToday() {
      final v = checked.trim();
      if (v.isEmpty) return false;
      final now = DateTime.now();
      final dd = now.day.toString().padLeft(2, '0');
      final mm = now.month.toString().padLeft(2, '0');
      final yyyy = now.year.toString();
      return v == '$dd/$mm/$yyyy';
    }

    final cor = f['cor'] ?? '';
    final musicId = int.tryParse(f['musica'] ?? '');

    final type = switch (tipo) {
      'musica' => LiturgyItemType.music,
      'anotacao' => LiturgyItemType.annotation,
      'arquivo' => _typeFromPath(f['dir'] ?? subitem),
      _ => null, // desconhecido: pula
    };
    if (type == null) return null;

    return LiturgyItem(
      id: 'ja_${_baseId(id)}',
      type: type,
      name: name.isEmpty ? subitem : name,
      subtitle: subitem,
      done: isDoneToday(),
      accentColor: _delphiColor(cor),
      musicId: type == LiturgyItemType.music ? musicId : null,
      filePath:
          type != LiturgyItemType.music && type != LiturgyItemType.annotation
          ? _nonEmpty(f['dir'])
          : null,
    );
  }

  static String? _nonEmpty(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// $00BBGGRR (Delphi) → #RRGGBB.
  static String _delphiColor(String raw) {
    final m = RegExp(r'^\$([0-9A-Fa-f]{8})$').firstMatch(raw.trim());
    if (m == null) return '';
    final hex = m.group(1)!;
    final b = hex.substring(2, 4);
    final g = hex.substring(4, 6);
    final r = hex.substring(6, 8);
    return '#$r$g$b';
  }

  static LiturgyItemType _typeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.isEmpty) return LiturgyItemType.otherFiles;
    if (p.endsWith('.mp4') ||
        p.endsWith('.mkv') ||
        p.endsWith('.avi') ||
        p.endsWith('.webm') ||
        p.endsWith('.mov'))
      return LiturgyItemType.video;
    if (p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.gif') ||
        p.endsWith('.bmp') ||
        p.endsWith('.webp')) {
      return LiturgyItemType.images;
    }
    if (p.endsWith('.pdf')) return LiturgyItemType.pdf;
    if (p.endsWith('.pptx') || p.endsWith('.ppt')) {
      return LiturgyItemType.presentation;
    }
    return LiturgyItemType.otherFiles;
  }
}

/// Decodifica bytes do arquivo .ja — usado pelo FilePicker.
///
/// O Delphi LouvorJA exporta em ANSI (Windows-1252); versões mais novas ou
/// arquivos convertidos vêm em UTF-8 (com ou sem BOM). Estratégia: tenta
/// UTF-8 estrito; se falhar, decodifica como Windows-1252 (Latin-1
/// supervisionado — nunca lança, preserva acentos do ANSI).
String decodeJaFile(List<int> bytes) {
  try {
    return utf8.decode(bytes); // estrito: bytes inválidos lançam
  } on FormatException {
    return latin1.decode(bytes, allowInvalid: false);
  }
}
