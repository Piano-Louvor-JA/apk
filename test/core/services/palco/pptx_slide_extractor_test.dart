// F3.3i: extração de imagens de slides do .pptx (ZIP ppt/media/*).
library;

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/pptx_slide_extractor.dart';

Uint8List _fakeImage(int size) => Uint8List.fromList(List.filled(size, 0x89));

File _makePptx(String path, Map<String, List<int>> media) {
  final archive = Archive();
  media.forEach((name, bytes) {
    archive.addFile(ArchiveFile('ppt/media/$name', bytes.length, bytes));
  });
  File(path).writeAsBytesSync(ZipEncoder().encode(archive));
  return File(path);
}

void main() {
  test('modo fiel aceita slide inteiro com uma imagem na ordem declarada', () {
    final archive = Archive();
    void xml(String path, String value) {
      final bytes = utf8.encode(value);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    xml(
      'ppt/presentation.xml',
      '<presentation xmlns:r="r"><sldIdLst><sldId r:id="r1"/></sldIdLst><sldSz cx="100" cy="80"/></presentation>',
    );
    xml(
      'ppt/_rels/presentation.xml.rels',
      '<Relationships><Relationship Id="r1" Target="slides/slide1.xml"/></Relationships>',
    );
    xml(
      'ppt/slides/slide1.xml',
      '<sld><pic><xfrm><off x="0" y="0"/><ext cx="100" cy="80"/></xfrm></pic></sld>',
    );
    xml(
      'ppt/slides/_rels/slide1.xml.rels',
      '<Relationships><Relationship Id="img" Target="../media/image1.png"/></Relationships>',
    );
    final bytes = _fakeImage(40 * 1024);
    archive.addFile(ArchiveFile('ppt/media/image1.png', bytes.length, bytes));
    final f = File('/tmp/liturgy-complete.pptx')
      ..writeAsBytesSync(ZipEncoder().encode(archive));
    expect(
      PptxSlideExtractor.extract(f.path, requireCompleteSlides: true),
      hasLength(1),
    );
  });
  test('modo fiel não trata imagens soltas como slides completos', () {
    final f = _makePptx('/tmp/liturgy-partial.pptx', {
      'image1.png': _fakeImage(40 * 1024),
    });
    expect(
      PptxSlideExtractor.extract(f.path, requireCompleteSlides: true),
      isEmpty,
    );
  });

  test('extrai imagens grandes em ordem numérica, ignora ícones pequenos', () {
    final f = _makePptx('/tmp/test_slides.pptx', {
      'image10.png': _fakeImage(30 * 1024),
      'image2.jpg': _fakeImage(25 * 1024),
      'image1.png': _fakeImage(40 * 1024),
      'logo.png': _fakeImage(5 * 1024), // icone: ignorado
    });
    final slides = PptxSlideExtractor.extract(f.path);
    expect(slides.length, 3, reason: 'logo pequeno filtrado');
    expect(slides.map((s) => s.name).toList(), [
      'image1.png',
      'image2.jpg',
      'image10.png',
    ], reason: 'ordem numérica, não lexicográfica');
  });

  test('arquivo inexistente retorna vazio', () {
    expect(PptxSlideExtractor.extract('/tmp/nao_existe.pptx'), isEmpty);
  });

  test('zip corrompido retorna vazio sem lançar', () {
    final f = File('/tmp/corrupt.pptx')..writeAsBytesSync([1, 2, 3, 4]);
    expect(PptxSlideExtractor.extract(f.path), isEmpty);
  });

  test('sem imagens retorna vazio', () {
    final f = _makePptx('/tmp/sem_img.pptx', {
      'slide1.xml': [1, 2, 3],
    });
    expect(PptxSlideExtractor.extract(f.path), isEmpty);
  });
}
