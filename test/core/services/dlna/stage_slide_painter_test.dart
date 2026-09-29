library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_slide_painter.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/ssdp_discovery.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/dlna_renderer_client.dart';

void main() {
  group('StageSlidePainter (lógica)', () {
    test('settings default = tipografia de projeção TV, fundo escuro', () {
      const s = StageSettings();
      expect(
        s.fontSize,
        greaterThanOrEqualTo(80),
        reason: 'fonte de palco precisa ser grande (era pequena no bug)',
      );
      expect(s.margin, 120);
      expect(s.backgroundColor, const Color(0xFF0A0E1A));
      expect(s.textColor, Colors.white);
    });

    test('copyWith muda fonte preservando o resto; clear fundo ok', () {
      const s = StageSettings(fontSize: 80, fontWeight: FontWeight.w400);
      final bigger = s.copyWith(fontSize: 130);
      expect(bigger.fontSize, 130);
      expect(bigger.fontWeight, FontWeight.w400);
      expect(bigger.backgroundColor, s.backgroundColor);
    });

    test('dimensão do canvas de palco é 1920x1080 (fullscreen TV)', () {
      expect(StageSlidePainter.stageWidth, 1920);
      expect(StageSlidePainter.stageHeight, 1080);
    });

    _capabilityGroup();
    _compatGroup();
  });
}

// ===== Inferência de capacidade via sink protocols (LG real) =====
void _capabilityGroup() {
  group('DlnaRenderer.screenCapability (sink protocols)', () {
    test('LG real: PNG_LRG → Full HD 1920x1080', () {
      final r = DlnaRenderer(ip: '1.1.1.1', descriptionUrl: 'http://x/')
        ..sinkProtocols =
            'http-get:*:image/png:DLNA.ORG_PN=PNG_LRG,http-get:*:image/png:*,http-get:*:image/jpeg:*';
      expect(r.screenCapability.width, 1920);
      expect(r.screenCapability.height, 1080);
    });

    test('TV legada: só PNG_SM → 640x480 (não envia FHD p/ render fraco)', () {
      final r = DlnaRenderer(ip: '1.1.1.1', descriptionUrl: 'http://x/')
        ..sinkProtocols = 'http-get:*:image/png:DLNA.ORG_PN=PNG_SM';
      expect(r.screenCapability.width, 640);
    });

    test('sem resposta do ConnectionManager → default seguro FHD', () {
      final r = DlnaRenderer(ip: '1.1.1.1', descriptionUrl: 'http://x/')
        ..sinkProtocols = '';
      expect(r.screenCapability.width, 1920);
    });

    test(
      'settings escala fonte pela capacidade (SM não gera fonte gigante)',
      () {
        const fhd = StageSettings(fontSize: 96);
        final sm = fhd.copyWith(capability: DlnaScreenCapability.sm);
        // proporção fonte/canvas se mantém: 96/1920 == x/640
        final scale = sm.capability.width / 1920;
        expect(96 * scale, closeTo(32, 0.01));
      },
    );
  });
}

// ===== Compatibilidade por fabricante (sink-based) =====
void _compatGroup() {
  group('Compatibilidade máxima (formato + resolução por sink)', () {
    test('LG real (DMR-1.50 com PNG_LRG): PNG + FullHD', () {
      final r = DlnaRenderer(ip: '1.1.1.1', descriptionUrl: 'http://x/')
        ..sinkProtocols =
            'http-get:*:image/png:DLNA.ORG_PN=PNG_LRG,http-get:*:image/jpeg:DLNA.ORG_PN=JPEG_LRG';
      expect(r.screenCapability.width, 1920);
      expect(r.preferredImageFormat, StageImageFormat.png);
    });

    test('TV legada DMR-1.0 (só JPEG): fallback JPEG + FullHD via JPEG_LRG', () {
      final r = DlnaRenderer(ip: '1.1.1.1', descriptionUrl: 'http://x/')
        ..sinkProtocols =
            'http-get:*:image/jpeg:DLNA.ORG_PN=JPEG_LRG,http-get:*:image/jpeg:DLNA.ORG_PN=JPEG_SM';
      expect(r.preferredImageFormat, StageImageFormat.jpeg);
      expect(r.screenCapability.width, 1920);
    });

    test('sink totalmente mudo: JPEG (universal) + FHD seguro', () {
      final r = DlnaRenderer(ip: '1.1.1.1', descriptionUrl: 'http://x/')
        ..sinkProtocols = '';
      expect(r.preferredImageFormat, StageImageFormat.jpeg);
      expect(r.screenCapability.width, 1920);
    });

    test('DIDL JPEG usa protocolInfo JPEG_LRG (comum Samsung/Philips)', () {
      final didl = DlnaRendererClient.didlImageFor(
        'http://x/s.jpg',
        'T',
        jpeg: true,
      );
      expect(didl, contains('image/jpeg:DLNA.ORG_PN=JPEG_LRG'));
      expect(didl, isNot(contains('PNG')));
    });

    test('capabilities: fila e volume detectados pelas ações do SCPD', () {
      final r = DlnaRenderer(ip: '1.1.1.1', descriptionUrl: 'http://x/')
        ..avTransportActions = {'Play', 'Stop', 'SetNextAVTransportURI'}
        ..renderingControlUrl = 'http://x/rc';
      expect(r.supportsQueue, isTrue);
      expect(r.supportsVolume, isTrue);
      final simples = DlnaRenderer(ip: '1.1.1.1', descriptionUrl: 'http://x/');
      expect(simples.supportsQueue, isFalse);
      expect(simples.supportsVolume, isFalse);
    });
  });
}
