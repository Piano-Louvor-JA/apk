import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Renderização nativa de PDF: uma página por vez, sem rede nem upload.
class LiturgyPdfDocument {
  const LiturgyPdfDocument(this.path);
  final String path;
  static const _channel = MethodChannel('app.louvorja/liturgy-documents');
  Future<int> pageCount() async =>
      await _channel.invokeMethod<int>('pdfInfo', {'path': path}) ?? 0;
  Future<Uint8List> render(int page, {int width = 1600}) async {
    final bytes = await _channel.invokeMethod<Uint8List>('pdfPage', {
      'path': path,
      'page': page,
      'width': width,
    });
    if (bytes == null) throw StateError('PDF sem página');
    return bytes;
  }
}
