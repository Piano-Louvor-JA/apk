// F3.3i: extração de imagens de slides do .pptx (ZIP ppt/media/*).
library;

import 'dart:io';
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
