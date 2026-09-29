library;

import 'dart:convert';

/// Headers HTTP exigidos pela API LouvorJA (descoberto no spike 2026-08-17):
/// - MP3 retorna 406 sem UA "Web0S" + Accept de áudio + Referer.
/// - JSON responde com UA+Accept application/json.
/// - URLs com acento/espaço devem ser percent-encoded no path.
abstract final class PalcoProxyHeaders {
  static const _uaWebOs = 'Mozilla/5.0 (Web0S)';

  static Map<String, String> forUrl(String url) {
    final h = <String, String>{'User-Agent': _uaWebOs};
    final lower = url.toLowerCase();
    final isAudio = lower.endsWith('.mp3') || lower.contains('/musics/');
    final isJson = lower.contains('/json_db/');
    final isVideo =
        lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.contains('video');
    if (isAudio) {
      h['Accept'] = 'audio/mpeg,audio/*,*/*;q=0.9';
      h['Referer'] = 'https://api.louvorja.com.br/';
    } else if (isVideo) {
      h['Accept'] = 'video/mp4,video/*,*/*;q=0.9';
    } else if (isJson) {
      h['Accept'] = 'application/json';
    } else {
      h['Accept'] = '*/*';
    }
    return h;
  }

  /// Re-encoda o path de uma URL que chegou decodificada
  /// (acentos/espaços → %XX), preservando host e query.
  /// Normaliza o path com encodagem percent (espaço/acentos → %XX).
  /// Uri.parse já encoda na maioria dos casos; esta função garante o
  /// contrato também para URLs que chegaram decodificadas (ex: lidas de
  /// query param), via decode+encode explícito.
  static String reencodePath(String url) {
    final uri = Uri.parse(url);
    if (!uri.hasScheme) return url;
    final decoded = Uri.decodeComponent(uri.path);
    final segments = decoded
        .split('/')
        .map((s) => Uri.encodeComponent(s))
        .join('/');
    final q = uri.hasQuery ? '?${uri.query}' : '';
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}$segments$q';
  }

  /// Codifica [url] para o parâmetro ?url= do proxy do sender.
  static String wrapForProxy(String senderBase, String url) {
    final b = senderBase.endsWith('/')
        ? senderBase.substring(0, senderBase.length - 1)
        : senderBase;
    return '$b/proxy?url=${Uri.encodeComponent(url)}';
  }

  /// Decodifica o parâmetro ?url= de uma requisição ao proxy.
  static String? unwrapFromProxy(String requestQuery) {
    if (!requestQuery.startsWith('url=')) return null;
    return Uri.decodeComponent(requestQuery.substring(4));
  }
}

/// Content-Type por extensão (proxy serve arquivos locais /media/).
abstract final class PalcoContentType {
  static const _map = <String, String>{
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.bmp': 'image/bmp',
    '.svg': 'image/svg+xml',
    '.mp3': 'audio/mpeg',
    '.mp4': 'video/mp4',
    '.webm': 'video/webm',
    '.json': 'application/json',
  };

  static String forPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return 'application/octet-stream';
    return _map[path.substring(dot).toLowerCase()] ??
        'application/octet-stream';
  }
}

/// Utilitário de resposta de mídia com suporte a Range (vídeo seek).
class PalcoRangeResponse {
  PalcoRangeResponse({
    required this.status,
    required this.contentType,
    required this.contentLength,
    this.contentRange,
  });

  final int status; // 200 ou 206
  final String contentType;
  final int contentLength;
  final String? contentRange; // ex: bytes 0-999/2204842

  Map<String, String> get headers => {
    'Content-Type': contentType,
    'Content-Length': contentLength.toString(),
    'Accept-Ranges': 'bytes',
    if (contentRange != null) 'Content-Range': contentRange!,
    'Access-Control-Allow-Origin': '*',
  };

  /// Interpreta um header Range (bytes=start-end | bytes=start-) contra
  /// [totalLength]. Retorna null se inválido → responder 416.
  static (int, int)? parseRange(String? rangeHeader, int totalLength) {
    if (rangeHeader == null || !rangeHeader.startsWith('bytes=')) return null;
    final spec = rangeHeader.substring(6).split('-');
    final start = int.tryParse(spec[0]);
    if (start == null || start >= totalLength) return null;
    final end = (spec.length > 1 && spec[1].isNotEmpty)
        ? int.tryParse(spec[1])
        : totalLength - 1;
    if (end == null || end < start) return null;
    return (start, end.clamp(start, totalLength - 1));
  }

  static PalcoRangeResponse forRange(
    String? rangeHeader,
    int totalLength,
    String contentType,
  ) {
    final range = parseRange(rangeHeader, totalLength);
    if (range == null) {
      return PalcoRangeResponse(
        status: 200,
        contentType: contentType,
        contentLength: totalLength,
      );
    }
    final (start, end) = range;
    return PalcoRangeResponse(
      status: 206,
      contentType: contentType,
      contentLength: end - start + 1,
      contentRange: 'bytes $start-$end/$totalLength',
    );
  }

  String encodeHeaders() => jsonEncode(headers);
}
