library;

import '../net/local_ipv4.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

/// Servidor HTTP local que serve o slide atual (PNG) para a TV baixar.
///
/// A TV faz HEAD antes do GET (validação LG do PoC) — ambos suportados.
/// A imagem fica em memória; trocar slide = trocar os bytes servidos.
class SlideHttpServer {
  SlideHttpServer({Future<String?> Function()? localIpResolver})
    : _resolveIp = localIpResolver ?? _localIp;

  final Future<String?> Function() _resolveIp;

  HttpServer? _server;
  Uint8List? _currentSlide;
  int _slideCounter = 0;
  bool _jpegMode = false;

  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;

  /// Sobe em porta alta; resolve o IP local pra URL pública na LAN.
  Future<String?> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _server!.listen(_handle, onError: (_) {});
      final ip = await _resolveIp();
      _cachedLocalIp = ip;
      if (ip == null) {
        debugPrint('[DLNA] SlideHttpServer: _localIp() = null (sem IP LAN)');
        return null;
      }
      return 'http://$ip:${_server!.port}';
    } catch (e) {
      debugPrint('[DLNA] SlideHttpServer.start() exceção: $e');
      return null;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _currentSlide = null;
  }

  /// Atualiza o slide servido. Retorna a URL com counter (bust cache da TV).
  Future<String?> serveSlide(Uint8List imageBytes, {bool jpeg = false}) async {
    _currentSlide = imageBytes;
    _jpegMode = jpeg;
    _slideCounter++;
    final ip = await _resolveIp();
    if (ip == null || _server == null) return null;
    return 'http://$ip:${_server!.port}/slide'
        '${jpeg ? '.jpg' : '.png'}?v=$_slideCounter';
  }

  Future<void> _handle(HttpRequest req) async {
    debugPrint(
      '[DLNA] server ${req.method} ${req.uri.path}'
      '${req.uri.query.isNotEmpty ? '?${req.uri.query}' : ''} de '
      '${req.connectionInfo?.remoteAddress.address}',
    );
    final res = req.response;
    final bytes = _currentSlide;
    if (bytes == null) {
      res.statusCode = 404;
      await res.close();
      return;
    }
    res.headers.contentType = ContentType.parse(
      _jpegMode ? 'image/jpeg' : 'image/png',
    );
    res.headers.set('Content-Length', bytes.length);
    if (req.method == 'HEAD') {
      await res.close();
      return;
    }
    res.add(bytes);
    await res.close();
  }

  /// IP do celular na MESMA sub-rede da TV (prefixo /24 do renderer).
  ///
  /// Bug real (2026-08-16): com VPN ativa (Tailscale 100.x) ou múltiplas
  /// interfaces, o app anunciava um IP que a TV não alcança — a TV aceitava
  /// o Set, dava timeout no download e o app reportava "TV desconectou".
  /// Agora: se o renderer está em 192.168.1.x, anunciamos o IP do celular
  /// também em 192.168.1.x.
  static String? rendererSubnetHint;
  static String? _cachedLocalIp;

  static String? get localIp => _cachedLocalIp;

  /// F3.3ab: resolve o IP LAN sem subir servidor (usado pelo bottom sheet
  /// do cast antes de qualquer conexão).
  static Future<String?> resolveLocalIp() async {
    if (_cachedLocalIp != null) return _cachedLocalIp;
    final ip = await _localIp();
    _cachedLocalIp = ip;
    return ip;
  }

  static Future<String?> _localIp() async {
    final hint = rendererSubnetHint;
    return pickLocalIpv4(preferPrefix: hint?.split('.').take(3).join('.'));
  }
}
