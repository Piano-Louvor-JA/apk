import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/pptx_slide_extractor.dart';

Uint8List _img(int size) => Uint8List.fromList(List.filled(size, 0x89));

/// Monta um .pptx com presentation.xml/rels completos — cobre o caminho de
/// ordem REAL (sldIdLst → slide rels → primeira imagem grande do slide).
File _makeRealPptx(String path) {
  final archive = Archive();

  const big = 30 * 1024;
  archive.addFile(ArchiveFile('ppt/media/image1.png', big, _img(big)));
  archive.addFile(ArchiveFile('ppt/media/image2.png', big, _img(big)));
  archive.addFile(ArchiveFile('ppt/media/image3.png', big, _img(big)));

  archive.addFile(
    ArchiveFile('ppt/presentation.xml', utf8.encode('''<?xml version="1.0"?>
<p:presentation xmlns:p="urn:a" xmlns:r="urn:b">
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId2"/>
    <p:sldId id="257" r:id="rId3"/>
    <p:sldId id="258" r:id="rId4"/>
  </p:sldIdLst>
</p:presentation>''').length, utf8.encode('''<?xml version="1.0"?>
<p:presentation xmlns:p="urn:a" xmlns:r="urn:b">
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId2"/>
    <p:sldId id="257" r:id="rId3"/>
    <p:sldId id="258" r:id="rId4"/>
  </p:sldIdLst>
</p:presentation>''')),
  );

  archive.addFile(
    ArchiveFile('ppt/_rels/presentation.xml.rels', utf8.encode('''<?xml version="1.0"?>
<Relationships>
  <Relationship Id="rId1" Target="slideMasters/slideMaster1.xml"/>
  <Relationship Id="rId2" Target="slides/slide1.xml"/>
  <Relationship Id="rId3" Target="slides/slide2.xml"/>
  <Relationship Id="rId4" Target="slides/slide3.xml"/>
</Relationships>''').length, utf8.encode('''<?xml version="1.0"?>
<Relationships>
  <Relationship Id="rId1" Target="slideMasters/slideMaster1.xml"/>
  <Relationship Id="rId2" Target="slides/slide1.xml"/>
  <Relationship Id="rId3" Target="slides/slide2.xml"/>
  <Relationship Id="rId4" Target="slides/slide3.xml"/>
</Relationships>''')),
  );

  // Ordem REAL: slide1→image2, slide2→image1, slide3→image3 (embaralhado).
  archive.addFile(
    ArchiveFile('ppt/slides/_rels/slide1.xml.rels', utf8.encode('''<?xml version="1.0"?>
<Relationships><Relationship Id="rId1" Target="../media/image2.png"/></Relationships>''').length, utf8.encode('''<?xml version="1.0"?>
<Relationships><Relationship Id="rId1" Target="../media/image2.png"/></Relationships>''')),
  );
  archive.addFile(
    ArchiveFile('ppt/slides/_rels/slide2.xml.rels', utf8.encode('''<?xml version="1.0"?>
<Relationships><Relationship Id="rId1" Target="../media/image1.png"/></Relationships>''').length, utf8.encode('''<?xml version="1.0"?>
<Relationships><Relationship Id="rId1" Target="../media/image1.png"/></Relationships>''')),
  );
  archive.addFile(
    ArchiveFile('ppt/slides/_rels/slide3.xml.rels', utf8.encode('''<?xml version="1.0"?>
<Relationships><Relationship Id="rId1" Target="../media/image3.png"/></Relationships>''').length, utf8.encode('''<?xml version="1.0"?>
<Relationships><Relationship Id="rId1" Target="../media/image3.png"/></Relationships>''')),
  );

  File(path).writeAsBytesSync(ZipEncoder().encode(archive));
  return File(path);
}

void main() {
  test('ordem real via presentation.xml: slide1→image2, slide2→image1', () {
    final f = _makeRealPptx('/tmp/test_real_order.pptx');
    final slides = PptxSlideExtractor.extract(f.path);

    expect(slides.map((s) => s.name).toList(), [
      'image2.png',
      'image1.png',
      'image3.png',
    ]);
  });

  test('presentation.xml sem sldId cai no fallback numérico', () {
    final archive = Archive();
    const big = 30 * 1024;
    archive.addFile(ArchiveFile('ppt/media/image2.png', big, _img(big)));
    archive.addFile(ArchiveFile('ppt/media/image1.png', big, _img(big)));
    archive.addFile(
      ArchiveFile('ppt/presentation.xml', utf8.encode('<p:presentation/>').length, utf8.encode('<p:presentation/>')),
    );
    final f = File('/tmp/test_no_sldid.pptx');
    f.writeAsBytesSync(ZipEncoder().encode(archive));

    final slides = PptxSlideExtractor.extract(f.path);
    expect(slides.map((s) => s.name).toList(), ['image1.png', 'image2.png']);
  });

  test('slide sem .rels é pulado na ordem real (restantes mantêm ordem)', () {
    final archive = Archive();
    const big = 30 * 1024;
    archive.addFile(ArchiveFile('ppt/media/image1.png', big, _img(big)));
    archive.addFile(ArchiveFile('ppt/media/image2.png', big, _img(big)));
    archive.addFile(
      ArchiveFile('ppt/presentation.xml', utf8.encode('''<?xml version="1.0"?>
<p:presentation xmlns:p="urn:a" xmlns:r="urn:b">
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId2"/>
    <p:sldId id="257" r:id="rId3"/>
  </p:sldIdLst>
</p:presentation>''').length, utf8.encode('''<?xml version="1.0"?>
<p:presentation xmlns:p="urn:a" xmlns:r="urn:b">
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId2"/>
    <p:sldId id="257" r:id="rId3"/>
  </p:sldIdLst>
</p:presentation>''')),
    );
    archive.addFile(
      ArchiveFile('ppt/_rels/presentation.xml.rels', utf8.encode('''<?xml version="1.0"?>
<Relationships>
  <Relationship Id="rId2" Target="slides/slide1.xml"/>
  <Relationship Id="rId3" Target="slides/slide2.xml"/>
</Relationships>''').length, utf8.encode('''<?xml version="1.0"?>
<Relationships>
  <Relationship Id="rId2" Target="slides/slide1.xml"/>
  <Relationship Id="rId3" Target="slides/slide2.xml"/>
</Relationships>''')),
    );
    // só slide2 tem .rels
    archive.addFile(
      ArchiveFile('ppt/slides/_rels/slide2.xml.rels', utf8.encode('''<?xml version="1.0"?>
<Relationships><Relationship Id="rId1" Target="../media/image1.png"/></Relationships>''').length, utf8.encode('''<?xml version="1.0"?>
<Relationships><Relationship Id="rId1" Target="../media/image1.png"/></Relationships>''')),
    );
    final f = File('/tmp/test_partial_rels.pptx');
    f.writeAsBytesSync(ZipEncoder().encode(archive));

    final slides = PptxSlideExtractor.extract(f.path);
    // slide1 sem .rels é pulado; slide2 entra; resultado não vazio = ordem real
    expect(slides, isNotEmpty);
    expect(slides.single.name, 'image1.png');
  });
}
