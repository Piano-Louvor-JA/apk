import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/lyric_slides.dart'
    as slides;
import 'package:louvorja_piano_mobile/core/services/dlna/stage_slide_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const slide = slides.LyricSlide(
    text: 'Rocha Eterna\nSanto é o Senhor',
    order: 1,
  );

  test('render produz PNG real na resolução default (FHD)', () async {
    final bytes = await StageSlidePainter.render(
      slide: slide,
      settings: const StageSettings(),
    );
    expect(bytes.length, greaterThan(1000));
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]); // PNG magic
  });

  test('render com resolução alvo menor (TV legada 640x480)', () async {
    final bytes = await StageSlidePainter.render(
      slide: slide,
      settings: const StageSettings(),
      targetWidth: 640,
      targetHeight: 480,
    );
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('render sem sombra e com caixinha (estilos F3.3m no raster)', () async {
    const styled = StageSettings(
      textShadow: false,
      textBox: true,
      boxOpacity: 0.6,
      boxBorder: true,
      textAlign: 'center',
    );
    final bytes = await StageSlidePainter.render(
      slide: slide,
      settings: styled,
    );
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('renderGeneric: title+body+footer rasteriza', () async {
    final bytes = await StageSlidePainter.renderGeneric(
      title: 'Leitura',
      body: 'Sl 23:1 — O Senhor é o meu pastor',
      footer: 'Culto de domingo',
      settings: const StageSettings(),
    );
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('renderGeneric: sem body e sem footer rasteriza (ramos nulos)', () async {
    final bytes = await StageSlidePainter.renderGeneric(
      title: 'Idle',
      settings: const StageSettings(),
    );
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('paintSolid pinta cor sólida no canvas (função pública)', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    StageSlidePainter.paintSolid(
      canvas,
      const Size(64, 64),
      const Color(0xFF112233),
    );
    final picture = recorder.endRecording();
    expect(picture, isNotNull);
  });
}
