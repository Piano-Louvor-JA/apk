library;

import 'dart:io';
import 'dart:typed_data';

/// Lê a duração de mídia local sem plugin.
///
/// MP4/MOV/M4A: parse do atom `mvhd` (timescale + duration) — Dart puro.
/// Outros formatos: 0 (best-effort). Nunca lança.
abstract final class MediaDurationReader {
  /// Duração em ms; 0 se não conseguiu ler.
  static Future<int> readMs(String path) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    final raf = await file.open();
    try {
      return await _parseMp4(raf);
    } catch (_) {
      return 0;
    } finally {
      await raf.close();
    }
  }

  /// ByteData respeitando o length do Uint8List do RandomAccessFile.
  static ByteData _bd(Uint8List b) => ByteData.sublistView(b, 0, b.length);

  /// Percorre a árvore de atoms do topo procurando `moov` → `mvhd`.
  static Future<int> _parseMp4(RandomAccessFile raf) async {
    final size = await raf.length();
    var offset = 0;
    while (offset + 8 <= size) {
      await raf.setPosition(offset);
      final header = await raf.read(8);
      if (header.length < 8) return 0;
      final bd = _bd(header);
      var atomSize = bd.getUint32(0, Endian.big);
      final type = String.fromCharCodes(header.sublist(4, 8));
      var headerLen = 8;
      if (atomSize == 1) {
        final ext = await raf.read(8);
        if (ext.length < 8) return 0;
        atomSize = _bd(ext).getUint64(0, Endian.big);
        headerLen = 16;
      } else if (atomSize == 0) {
        atomSize = size - offset;
      }
      if (atomSize < headerLen) return 0;

      if (type == 'moov') {
        final dur = await _findMvhd(raf, offset + headerLen, offset + atomSize);
        if (dur > 0) return dur;
      }
      offset += atomSize;
    }
    return 0;
  }

  /// Dentro do moov, procura mvhd (nível 1).
  static Future<int> _findMvhd(RandomAccessFile raf, int start, int end) async {
    var offset = start;
    while (offset + 8 <= end) {
      await raf.setPosition(offset);
      final header = await raf.read(8);
      if (header.length < 8) return 0;
      final bd = _bd(header);
      final atomSize = bd.getUint32(0, Endian.big);
      final type = String.fromCharCodes(header.sublist(4, 8));
      if (atomSize < 8) return 0;

      if (type == 'mvhd') {
        // mvhd: version(1) flags(3) | v0: ctime(4) mtime(4) timescale(4)
        // duration(4) | v1: ctime(8) mtime(8) timescale(4) duration(8)
        final body = await raf.read(atomSize - 8);
        if (body.length < 4) return 0;
        final v = _bd(body);
        final version = v.getUint8(0);
        if (version == 0) {
          if (body.length < 20) return 0;
          final timescale = v.getUint32(12, Endian.big);
          final duration = v.getUint32(16, Endian.big);
          return _toMs(timescale, duration);
        }
        if (body.length < 32) return 0;
        final timescale = v.getUint32(20, Endian.big);
        final duration = v.getUint64(24, Endian.big);
        return _toMs(timescale, duration);
      }
      offset += atomSize;
    }
    return 0;
  }

  static int _toMs(int timescale, int duration) {
    if (timescale <= 0 || duration <= 0) return 0;
    return (duration * 1000 / timescale).round();
  }
}
