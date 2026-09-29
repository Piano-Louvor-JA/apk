library;

import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../domain/entities/lyric_slides.dart';
import 'ssdp_discovery.dart' show DlnaScreenCapability;

/// Renderiza o SLIDE DE PROJEÇÃO (Palco) na resolução da CAPACIDADE da
/// TV (descoberta via ConnectionManager#GetProtocolInfo no discovery) —
/// não é a tela do celular. Tipografia de projeção escalada.
class StageSlidePainter {
  static const stageWidth = 1920.0;
  static const stageHeight = 1080.0;

  /// Renderiza [slide] em PNG na resolução da CAPACIDADE da TV
  /// (sink protocols do GetProtocolInfo) conforme [settings].
  static Future<Uint8List> render({
    required LyricSlide slide,
    required StageSettings settings,
    String? backgroundUrl,
    int? targetWidth,
    int? targetHeight,
  }) async {
    final width = (targetWidth ?? settings.capability.width).toDouble();
    final height = (targetHeight ?? settings.capability.height).toDouble();
    final scale = width / 1920;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width, height);

    paintSolid(canvas, size, settings.backgroundColor);

    final painter = TextPainter(
      text: TextSpan(
        text: slide.text,
        style: TextStyle(
          fontSize: settings.fontSize * scale,
          fontWeight: settings.fontWeight,
          color: settings.textColor,
          height: 1.35,
          shadows: settings.textShadow
              ? [
                  Shadow(
                    color: Colors.black.withValues(
                      alpha: settings.shadowIntensity,
                    ),
                    blurRadius: settings.shadowBlur * scale,
                    offset: Offset(2 * scale, 2 * scale),
                  ),
                ]
              : null,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: width - settings.margin * 2 * scale);
    final offset = Offset(
      (width - painter.width) / 2,
      (height - painter.height) / 2,
    );
    painter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Renderiza conteúdo genérico (liturgia, versículo, idle do palco)
  /// na resolução da TV. [title] grande, [body] abaixo, rodapé opcional.
  static Future<Uint8List> renderGeneric({
    required String title,
    String? body,
    String? footer,
    required StageSettings settings,
    ui.Image? backgroundImage,
  }) async {
    final width = settings.capability.width.toDouble();
    final height = settings.capability.height.toDouble();
    final scale = width / 1920;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width, height);

    // Fundo: imagem personalizada (cover) > cor sólida.
    if (backgroundImage != null) {
      _paintCover(canvas, size, backgroundImage);
      // véu escuro p/ legibilidade do texto sobre foto.
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
    } else {
      paintSolid(canvas, size, settings.backgroundColor);
    }

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          fontSize: 84 * scale,
          fontWeight: FontWeight.w700,
          color: settings.textColor,
          height: 1.25,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 160 * scale);

    TextPainter? bodyPainter;
    if (body != null && body.isNotEmpty) {
      bodyPainter = TextPainter(
        text: TextSpan(
          text: body,
          style: TextStyle(
            fontSize: 56 * scale,
            fontWeight: FontWeight.w400,
            color: settings.textColor.withValues(alpha: 0.92),
            height: 1.45,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 240 * scale);
    }

    final totalH =
        titlePainter.height +
        (bodyPainter != null ? 40 * scale + bodyPainter.height : 0);
    var y = (height - totalH) / 2;
    canvas.save();
    canvas.translate((width - titlePainter.width) / 2, y);
    titlePainter.paint(canvas, Offset.zero);
    canvas.restore();
    if (bodyPainter != null) {
      y += titlePainter.height + 40 * scale;
      canvas.save();
      canvas.translate((width - bodyPainter.width) / 2, y);
      bodyPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    if (footer != null && footer.isNotEmpty) {
      final fp = TextPainter(
        text: TextSpan(
          text: footer,
          style: TextStyle(
            fontSize: 34 * scale,
            fontWeight: FontWeight.w300,
            color: settings.textColor.withValues(alpha: 0.65),
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 160 * scale);
      canvas.save();
      canvas.translate((width - fp.width) / 2, height - 110 * scale);
      fp.paint(canvas, Offset.zero);
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static void _paintCover(Canvas canvas, Size size, ui.Image image) {
    final srcScale = math.max(
      size.width / image.width,
      size.height / image.height,
    );
    final srcW = size.width / srcScale;
    final srcH = size.height / srcScale;
    final src = Rect.fromCenter(
      center: Offset(image.width / 2, image.height / 2),
      width: srcW,
      height: srcH,
    );
    canvas.drawImageRect(image, src, Offset.zero & size, Paint());
  }

  static void paintSolid(Canvas canvas, Size size, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRect(Offset.zero & size, paint);
  }
}

/// Configurações do Palco — persistíveis (SharedPreferences).
class StageSettings {
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final double margin;
  final Uint8List? backgroundImageBytes;

  // ===== F3.3m: estilos visuais do Palco =====
  /// Sombra da letra: on/off, blur (vh) e intensidade (0-1).
  final bool textShadow;
  final double shadowBlur; // vh (padrão 2.2)
  final double shadowIntensity; // 0-1 (padrão .8)
  /// Caixinha atrás da letra: on/off, opacidade do fundo e borda.
  final bool textBox;
  final double boxOpacity; // 0-1 (padrão .45)
  final bool boxBorder; // borda na caixinha
  /// Alinhamento do texto: left | center | right
  final String textAlign;

  /// Alinhamento vertical do texto: top | middle | bottom
  final String textVerticalAlign;

  /// Footer da Bíblia: cor/ peso da referência e exibição da versão.
  final Color footerRefColor;
  final int footerRefWeight;
  final bool showBibleVersion;

  // ===== F3.3o: tipografia PRÓPRIA da Bíblia (diferente da música) =====
  final double bibleFontSize;
  final int bibleFontWeight;
  final Color bibleTextColor;

  /// Capacidade da TV conectada (setada ao conectar; default FHD).
  final DlnaScreenCapability capability;

  const StageSettings({
    this.backgroundColor = const Color(0xFF0A0E1A),
    this.textColor = Colors.white,
    this.fontSize = 96,
    this.fontWeight = FontWeight.w600,
    this.margin = 120,
    this.backgroundImageBytes,
    this.textShadow = true,
    this.shadowBlur = 2.2,
    this.shadowIntensity = 0.8,
    this.textBox = false,
    this.boxOpacity = 0.45,
    this.boxBorder = true,
    this.textAlign = 'center',
    this.textVerticalAlign = 'middle',
    this.footerRefColor = const Color(0xFFFCCE02),
    this.footerRefWeight = 600,
    this.showBibleVersion = true,
    this.bibleFontSize = 84,
    this.bibleFontWeight = 500,
    this.bibleTextColor = Colors.white,
    this.capability = DlnaScreenCapability.fhd,
  });

  StageSettings copyWith({
    Color? backgroundColor,
    Color? textColor,
    double? fontSize,
    FontWeight? fontWeight,
    double? margin,
    Uint8List? backgroundImageBytes,
    bool clearBackgroundImage = false,
    bool? textShadow,
    double? shadowBlur,
    double? shadowIntensity,
    bool? textBox,
    double? boxOpacity,
    bool? boxBorder,
    Color? footerRefColor,
    int? footerRefWeight,
    bool? showBibleVersion,
    String? textAlign,
    String? textVerticalAlign,
    double? bibleFontSize,
    int? bibleFontWeight,
    Color? bibleTextColor,
    DlnaScreenCapability? capability,
  }) => StageSettings(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    textColor: textColor ?? this.textColor,
    fontSize: fontSize ?? this.fontSize,
    fontWeight: fontWeight ?? this.fontWeight,
    margin: margin ?? this.margin,
    backgroundImageBytes: clearBackgroundImage
        ? null
        : backgroundImageBytes ?? this.backgroundImageBytes,
    textShadow: textShadow ?? this.textShadow,
    shadowBlur: shadowBlur ?? this.shadowBlur,
    shadowIntensity: shadowIntensity ?? this.shadowIntensity,
    textBox: textBox ?? this.textBox,
    boxOpacity: boxOpacity ?? this.boxOpacity,
    boxBorder: boxBorder ?? this.boxBorder,
    textAlign: textAlign ?? this.textAlign,
    textVerticalAlign: textVerticalAlign ?? this.textVerticalAlign,
    footerRefColor: footerRefColor ?? this.footerRefColor,
    footerRefWeight: footerRefWeight ?? this.footerRefWeight,
    showBibleVersion: showBibleVersion ?? this.showBibleVersion,
    bibleFontSize: bibleFontSize ?? this.bibleFontSize,
    bibleFontWeight: bibleFontWeight ?? this.bibleFontWeight,
    bibleTextColor: bibleTextColor ?? this.bibleTextColor,
    capability: capability ?? this.capability,
  );
}
