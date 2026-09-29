library;

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Extrai os slides de um .pptx (ZIP) na ORDEM REAL da apresentação.
///
/// Caso real (2026-08-18): PPTs da Escola Sabatina (ex: PRI_A_T3semana7.pptx)
/// são ~1 imagem por slide. O mobile não tem renderizador PPTX — mas o
/// .pptx é um ZIP: as imagens embutidas em ppt/media/ são os slides.
///
/// v2 (2026-08-20): ordem via ppt/_rels/presentation.xml.rels + slides list
/// (ordem de exibição de verdade), e cada slide usa a PRIMEIRA imagem do
/// seu próprio .rels. Slides de texto puro (sem imagem grande) caem no
/// fallback de ordenação numérica — transições/animações são metadata do
/// PowerPoint, não existem na imagem; como projetamos a imagem, elas são
/// automaticamente "desativadas".
abstract final class PptxSlideExtractor {
  static const _imageExts = {'.png', '.jpg', '.jpeg', '.bmp', '.webp'};
  static const _minBytes = 20 * 1024;

  /// Retorna [{name, bytes}] dos slides em ordem. Vazio se não der.
  static List<({String name, Uint8List bytes})> extract(String pptxPath) {
    final file = File(pptxPath);
    if (!file.existsSync()) return const [];
    try {
      final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());

      // 1. Media: todas as imagens grandes por nome.
      final media = <String, ({String name, Uint8List bytes})>{};
      for (final f in archive.files) {
        if (!f.isFile) continue;
        final name = f.name.split('/').last.toLowerCase();
        final dot = name.lastIndexOf('.');
        if (dot < 0) continue;
        if (!_imageExts.contains(name.substring(dot))) continue;
        final data = Uint8List.fromList(f.content as List<int>);
        if (data.length < _minBytes) continue; // logo/icone, nao slide
        media[name] = (name: name, bytes: data);
      }
      if (media.isEmpty) return const [];

      // 2. Ordem dos slides: presentation.xml (sldIdLst) + rels.
      final ordered = _orderedSlideMedia(archive, media);
      if (ordered != null) return ordered;

      // 3. Fallback: ordem numerica do sufixo (image1 < image2 < ...).
      final list = media.values.toList();
      int num(String n) =>
          int.parse(RegExp(r'(\d+)').firstMatch(n)?.group(1) ?? '0');
      list.sort((a, b) => num(a.name).compareTo(num(b.name)));
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Lê ppt/presentation.xml, resolve cada sldId → slideN.xml via
  /// presentation.xml.rels, e pega a primeira imagem grande do .rels do
  /// slide. Retorna null se qualquer peça faltar (fallback numérico).
  static List<({String name, Uint8List bytes})>? _orderedSlideMedia(
    Archive archive,
    Map<String, ({String name, Uint8List bytes})> media,
  ) {
    try {
      final presFile = archive.files
          .where((f) => f.isFile && f.name == 'ppt/presentation.xml')
          .firstOrNull;
      if (presFile == null) return null;
      final pres = XmlDocument.parse(
        String.fromCharCodes(presFile.content as List<int>),
      );

      // r:id dos sldId em ordem.
      final slideRids = pres.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'sldId')
          .map((e) => e.getAttribute('r:id'))
          .whereType<String>()
          .toList();
      if (slideRids.isEmpty) return null;

      // rels: rIdN -> target slides/slideN.xml
      final relsFile = archive.files
          .where((f) => f.isFile && f.name == 'ppt/_rels/presentation.xml.rels')
          .firstOrNull;
      if (relsFile == null) return null;
      final rels = XmlDocument.parse(
        String.fromCharCodes(relsFile.content as List<int>),
      );
      String? ridToTarget(String rid) {
        for (final rel in rels.descendants.whereType<XmlElement>()) {
          if (rel.name.local != 'Relationship') continue;
          if (rel.getAttribute('Id') != rid) continue;
          final target = rel.getAttribute('Target');
          if (target == null) continue;
          // Target vem relativo a ppt/ → slides/slide1.xml
          return 'ppt/$target';
        }
        return null;
      }

      final out = <({String name, Uint8List bytes})>[];
      for (final rid in slideRids) {
        final slidePath = ridToTarget(rid);
        if (slidePath == null) continue;
        // .rels do slide: pega a primeira imagem do media map.
        final slideRelsPath = slidePath
            .replaceFirst('slides/', 'slides/_rels/')
            .replaceFirst('.xml', '.xml.rels');
        final slideRelsFile = archive.files
            .where((f) => f.isFile && f.name == slideRelsPath)
            .firstOrNull;
        if (slideRelsFile == null) continue;
        final srels = XmlDocument.parse(
          String.fromCharCodes(slideRelsFile.content as List<int>),
        );
        for (final rel in srels.descendants.whereType<XmlElement>()) {
          if (rel.name.local != 'Relationship') continue;
          final target = (rel.getAttribute('Target') ?? '')
              .split('/')
              .last
              .toLowerCase();
          final img = media[target];
          if (img != null) {
            out.add(img);
            break; // primeira imagem grande do slide
          }
        }
      }
      return out.isNotEmpty ? out : null;
    } catch (_) {
      return null;
    }
  }
}
