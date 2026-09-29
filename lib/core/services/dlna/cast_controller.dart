library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'dlna_renderer_client.dart';
import 'multicast_lock.dart';
import 'slide_http_server.dart';
import 'ssdp_discovery.dart';

/// Orquestra o Palco: descobre TVs, serve slides e projeta.
///
/// Fluxo validado no PoC (LG real 2026-08-16):
/// connect → serveSlide(bytes) → projectImage(url) → TV exibe.
/// Debounce embutido: trocas rápidas de slide só projetam a última.
class CastController {
  final SlideHttpServer _server = SlideHttpServer();
  DlnaRendererClient? _client;
  DlnaRenderer? _renderer;
  bool _connected = false;
  StageImageFormat _format = StageImageFormat.png;
  DateTime _lastProjectAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastUrl;

  bool get isConnected => _connected;
  String? get rendererName => _renderer?.friendlyName;
  StageImageFormat get imageFormat => _format;

  /// Último erro do SOAP (diagnóstico do porquê a projeção falhou).
  String? get lastError => _client?.lastError;

  /// Escaneia a LAN e devolve renderers com controlURL resolvido.
  static Future<List<DlnaRenderer>> discoverTvs() async {
    // Android: mantém multicast ativo só durante o scan (economia bateria).
    await MulticastLock.acquire();
    try {
      final found = await SsdpDiscovery.scan();
      final resolved = <DlnaRenderer>[];
      for (final r in found) {
        if (await r.resolve()) resolved.add(r);
      }
      return resolved;
    } finally {
      await MulticastLock.release();
    }
  }

  /// Conecta num renderer: sobe o HTTP server local.
  Future<bool> connect(DlnaRenderer renderer) async {
    final base = await _server.start();
    if (base == null) {
      debugPrint(
        '[DLNA] connect() FALHOU: SlideHttpServer.start() = null '
        '(bind ou _localIp falhou)',
      );
      return false;
    }
    debugPrint(
      '[DLNA] connect OK: server em $base, controlURL='
      '${renderer.avTransportControlUrl}',
    );
    _renderer = renderer;
    _client = DlnaRendererClient(renderer.avTransportControlUrl!);
    _format = renderer.preferredImageFormat;
    // Anuncia o IP do celular NA SUB-REDE da TV (evita anunciar IP de
    // VPN/segunda interface que a TV não alcança).
    SlideHttpServer.rendererSubnetHint = renderer.ip;
    _connected = true;
    return true;
  }

  /// Projeta os bytes do slide atual. Retorna false se falhou o SOAP
  /// (TV desligou/mudou de rede) — chamador pode sugerir reconexão.
  Future<bool> projectSlide(
    Uint8List pngBytes, {
    String title = 'Slide',
  }) async {
    if (!_connected || _client == null) return false;
    final url = await _server.serveSlide(pngBytes);
    if (url == null) return false;
    if (url == _lastUrl) return true; // já projetando este slide

    // Debounce: TV processa ~1 set/seg bem; rajadas só a última importa.
    final now = DateTime.now();
    final sinceLast = now.difference(_lastProjectAt);
    if (sinceLast < const Duration(milliseconds: 250)) {
      await Future<void>.delayed(const Duration(milliseconds: 250) - sinceLast);
    }
    _lastProjectAt = DateTime.now();

    final ok = await _client!.projectImage(
      url,
      title: title,
      jpeg: _format == StageImageFormat.jpeg,
    );
    _lastUrl = ok ? url : null;
    return ok;
  }

  Future<void> disconnect() async {
    await _client?.stop();
    _client?.dispose();
    await _server.stop();
    _client = null;
    _renderer = null;
    _connected = false;
    _lastUrl = null;
  }
}
