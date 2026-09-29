library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'package:flutter/foundation.dart' show debugPrint;

import 'palco_models.dart';
import 'palco_proxy.dart';

/// Sender do Palco: HTTP (:7080, proxy + mídia local) + WS (:7081) no celular.
///
/// Reimplementação Dart do sender.py validado no spike ~/palco-spike
/// (LG UM7510, 2026-08-17). Mesmo protocolo — a TV (receiver webOS) conecta
/// aqui e recebe as mensagens v2.
///
/// Regras críticas herdadas do spike (NÃO regredir):
/// 1. WS SEM ping — webOS 4.x não responde pings e a conexão cai em loop.
/// 2. Mídia sempre com IP da sub-rede da TV (nunca localhost).
/// 3. Proxy: headers Web0S/Accept/Referer (API retorna 406 sem eles).
/// 4. Threading: cada request em handler isolado (HttpServer dart:io já é
///    concorrente por listen).
class PalcoSender {
  HttpServer? _http;
  HttpServer? _ws;
  final Set<WebSocket> _clients = {};
  final _events = StreamController<PalcoMessage>.broadcast();

  /// Role declarado por cada receiver via `hello` ('tv' | 'desktop' |
  /// 'web'). Receivers que não declaram ficam como 'tv' (comportamento
  /// atual das TVs).
  final Map<WebSocket, String> _clientRoles = {};

  /// Eventos receiver→sender (unlocked, ended, remote-key, ...).
  Stream<PalcoMessage> get events => _events.stream;
  int get clientCount => _clients.length;
  bool get isRunning => _ws != null;

  /// Quantos receivers de cada role estão conectados.
  Map<String, int> get roleCounts {
    final counts = <String, int>{};
    for (final role in _clientRoles.values) {
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return counts;
  }

  /// F3.3x: IP do último receiver conectado (visto pelo socket WS).
  /// Nulo até a TV conectar pela primeira vez.
  String? _receiverIp;
  String? get receiverIp => _receiverIp;

  /// Sub-rede da TV (hint para anunciar o IP certo — igual DLNA).
  String? rendererSubnetHint;

  static const int httpPort = 7080;
  static const int wsPort = 7081;

  PalcoSender({
    this.httpPortFixed = httpPort,
    this.wsPortFixed = wsPort,
    this.slotId = 'principal',
    this.slotLabel = 'Principal (espelho)',
    Uint8List? receiverPage,
  }) : _receiverPage = receiverPage;

  /// Receiver embutido (F3.4): carregado uma vez do asset
  /// assets/palco/receiver.html — servido em / e /receiver.html.
  /// Testes injetam bytes direto (rootBundle não funciona em unit test).
  Uint8List? _receiverPage;

  /// Portas fixas em produção; 0 (efêmera) em teste.
  final int httpPortFixed;
  final int wsPortFixed;

  /// Identidade persistente do slot; receiver mostra no idle para o operador.
  final String slotId;
  final String slotLabel;

  int get effectiveHttpPort => _http?.port ?? httpPortFixed;
  int get effectiveWsPort => _ws?.port ?? wsPortFixed;

  /// Sobe os servidores. Retorna a base HTTP (ex: http://192.168.1.5:7080)
  /// ou null se falhou (sem IP LAN).
  Future<String?> start() async {
    final ip = await _localIp();
    if (ip == null) {
      debugPrint('[PALCO] start(): sem IP LAN');
      return null;
    }
    try {
      _http = await HttpServer.bind(
        InternetAddress.anyIPv4,
        httpPortFixed,
        shared: true,
      );
      _http!.listen(_handleHttp, onError: (_) {});

      _ws = await HttpServer.bind(
        InternetAddress.anyIPv4,
        wsPortFixed,
        shared: true,
      );
      _ws!.listen(_handleWsUpgrade, onError: (_) {});

      debugPrint(
        '[PALCO] sender em http://$ip:$effectiveHttpPort + ws://$ip:$effectiveWsPort',
      );
      return 'http://$ip:$effectiveHttpPort';
    } catch (e) {
      debugPrint('[PALCO] start() FALHOU: $e (portas em uso?)');
      await stop();
      return null;
    }
  }

  Future<void> stop() async {
    for (final c in _clients.toList()) {
      await c.close();
    }
    _clients.clear();
    _clientRoles.clear();
    await _http?.close(force: true);
    await _ws?.close(force: true);
    _http = null;
    _ws = null;
  }

  // ---- WS ----

  void _handleWsUpgrade(HttpRequest req) {
    if (req.uri.path == '/palco') {
      WebSocketTransformer.upgrade(req)
          .then((ws) {
            _clients.add(ws);
            // F3.3x: IP do receiver (visto pelo socket) — exibido no app e
            // na TV pra debug/ares sem precisar de scan reverso.
            final remoteIp = req.connectionInfo?.remoteAddress.address;
            if (remoteIp != null && remoteIp != _receiverIp) {
              _receiverIp = remoteIp;
              debugPrint('[PALCO] receiver IP: $remoteIp');
            }
            debugPrint('[PALCO] receiver conectado (${_clients.length})');
            // F3.3x: diz à TV qual o IP DELA (visto pelo socket) — o receiver
            // exibe discretamente no idle (debug/ares).
            if (remoteIp != null) {
              try {
                ws.add(
                  jsonEncode(
                    PalcoMessage(
                      type: 'youare',
                      fields: {
                        'ip': remoteIp,
                        'slot': slotId,
                        'slotLabel': slotLabel,
                      },
                    ).toJson(),
                  ),
                );
              } catch (_) {}
            }
            ws.listen(
              (data) {
                try {
                  final m = PalcoMessage.fromJson(
                    jsonDecode(data as String) as Map<String, dynamic>,
                  );
                  // hello: registra o role do receiver (desktop/web/tv).
                  if (m.type == 'hello' && m.helloRole != null) {
                    _clientRoles[ws] = m.helloRole!;
                    debugPrint('[PALCO] receiver role: ${m.helloRole}');
                    notifyRoleChange();
                  }
                  _events.add(m);
                } catch (_) {}
              },
              onDone: () {
                _clients.remove(ws);
                _clientRoles.remove(ws);
                debugPrint('[PALCO] receiver saiu (${_clients.length})');
                notifyRoleChange();
              },
              onError: (_) {
                _clients.remove(ws);
                _clientRoles.remove(ws);
                notifyRoleChange();
              },
              // SEM ping: webOS 4.x não responde (lição do spike).
              cancelOnError: false,
            );
          })
          .catchError((_) {});
    } else {
      req.response.statusCode = 404;
      req.response.close();
    }
  }

  final _rolesChanged = StreamController<void>.broadcast();

  /// Emite quando a lista de receivers/roles muda (conexão, saída, hello).
  Stream<void> get rolesChanged => _rolesChanged.stream;

  void notifyRoleChange() {
    if (!_rolesChanged.isClosed) _rolesChanged.add(null);
  }

  /// Envia mensagem apenas a receivers com o role dado.
  /// Retorna false se nenhum receiver desse role está conectado.
  bool sendToRole(String role, PalcoMessage msg) {
    final targets = _clients
        .where((c) => (_clientRoles[c] ?? 'tv') == role)
        .toList();
    if (targets.isEmpty) return false;
    final data = jsonEncode(msg.toJson());
    for (final c in targets) {
      try {
        c.add(data);
      } catch (_) {}
    }
    return true;
  }

  /// Broadcast de mensagem para todos os receivers conectados.
  void send(PalcoMessage msg) {
    if (_clients.isEmpty) return;
    final data = jsonEncode(msg.toJson());
    for (final c in _clients.toList()) {
      try {
        c.add(data);
      } catch (_) {
        _clients.remove(c);
      }
    }
  }

  // ---- HTTP: proxy + mídia ----

  /// Bytes de mídia local servida em `/media/<nome>.<ext>` (PPT rasterizado etc).
  final Map<String, Uint8ListListEntry> _media = {};

  void serveMedia(String name, List<int> bytes) {
    _media[name] = Uint8ListListEntry(bytes);
  }

  void clearMedia() => _media.clear();

  Future<void> _handleHttp(HttpRequest req) async {
    final res = req.response;
    try {
      final path = req.uri.path;
      if (path == '/' || path == '/receiver.html' || path == '/index.html') {
        _receiverPage ??= (await rootBundle.load(
          'assets/palco/receiver.html',
        )).buffer.asUint8List();
        res.headers.contentType = ContentType.html;
        res.headers.set('Access-Control-Allow-Origin', '*');
        res.add(_receiverPage!);
        await res.close();
      } else if (path == '/logo-piano-louvorja.png') {
        // Fallback de cover (F3.3e): logo da org quando o item de audio
        // nao tem capa ou a capa falha no load.
        try {
          final png = (await rootBundle.load(
            'assets/palco/logo-piano-louvorja.png',
          )).buffer.asUint8List();
          res.headers.contentType = ContentType.parse('image/png');
          res.headers.set('Access-Control-Allow-Origin', '*');
          res.add(png);
        } catch (_) {
          res.statusCode = 404;
        }
        await res.close();
      } else if (path == '/bg-fallback.png') {
        // F3.3j: BG padrao do palco quando o audio nao tem imagem de fundo.
        try {
          final png = (await rootBundle.load(
            'assets/palco/bg-fallback.png',
          )).buffer.asUint8List();
          res.headers.contentType = ContentType.parse('image/png');
          res.headers.set('Access-Control-Allow-Origin', '*');
          res.add(png);
        } catch (_) {
          res.statusCode = 404;
        }
        await res.close();
      } else if (path == '/splash-palco.png') {
        // F3.3j: splash screen do receiver (exibida ao carregar).
        try {
          final png = (await rootBundle.load(
            'assets/palco/splash-palco.png',
          )).buffer.asUint8List();
          res.headers.contentType = ContentType.parse('image/png');
          res.headers.set('Access-Control-Allow-Origin', '*');
          res.add(png);
        } catch (_) {
          res.statusCode = 404;
        }
        await res.close();
      } else if (path == '/logo-louvor-ja.svg') {
        try {
          final svg = (await rootBundle.load(
            'assets/palco/logo-louvor-ja.svg',
          )).buffer.asUint8List();
          res.headers.contentType = ContentType.parse('image/svg+xml');
          res.add(svg);
        } catch (_) {
          res.statusCode = 404;
        }
        await res.close();
      } else if (path == '/status') {
        res.headers.contentType = ContentType.json;
        // CORS obrigatório: o receiver usa fetch(:7080/status) na
        // auto-descoberta — sem isso o scan é bloqueado (F3.3).
        res.headers.set('Access-Control-Allow-Origin', '*');
        res.write('{"unlocked":true,"clients":${_clients.length}}');
        await res.close();
      } else if (path.startsWith('/media/')) {
        await _serveMedia(req, path);
      } else if (path == '/proxy') {
        await _serveProxy(req);
      } else if (path.startsWith('/images/')) {
        // /images/... proxy para API (receiver pede covers/backgrounds).
        // Bug 2026-08-18: o receiver resolve covers relativos contra a
        // origem (http://host:7080/images/generico_116.jpg) — sem query
        // ?url=, o _serveProxy devolvia 400/404 e a capa ficava quebrada.
        // Monta a URL da API a partir do path e proxya.
        final rel = path.substring(1); // images/... ou covers/...
        await _serveProxy(
          req,
          overrideQuery:
              'url='
              '${Uri.encodeComponent('https://api.louvorja.com.br/file/$rel')}',
        );
      } else if (path.startsWith('/covers/')) {
        // covers/... (F3.3e): mesma rota — capa de album relativa.
        final rel = path.substring(1);
        await _serveProxy(
          req,
          overrideQuery:
              'url='
              '${Uri.encodeComponent('https://api.louvorja.com.br/file/$rel')}',
        );
      } else {
        res.statusCode = 404;
        await res.close();
      }
    } catch (e) {
      try {
        res.statusCode = 502;
        res.write('palco error: $e');
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> _serveMedia(HttpRequest req, String path) async {
    final name = path.substring('/media/'.length).split('/').last;
    final entry = _media[name];
    if (entry == null) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    final bytes = entry.bytes;
    final r = PalcoRangeResponse.forRange(
      req.headers.value(HttpHeaders.rangeHeader),
      bytes.length,
      PalcoContentType.forPath(name),
    );
    _applyRangeHeaders(req, r);
    final (start, end) =
        PalcoRangeResponse.parseRange(
          req.headers.value(HttpHeaders.rangeHeader),
          bytes.length,
        ) ??
        (0, bytes.length - 1);
    req.response.add(bytes.sublist(start, end + 1));
    await req.response.close();
  }

  Future<void> _serveProxy(HttpRequest req, {String? overrideQuery}) async {
    final target = PalcoProxyHeaders.unwrapFromProxy(
      overrideQuery ?? req.uri.query,
    );
    if (target == null) {
      req.response.statusCode = 400;
      await req.response.close();
      return;
    }
    final url = PalcoProxyHeaders.reencodePath(target);
    final hc = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final fr = await hc.getUrl(Uri.parse(url));
      PalcoProxyHeaders.forUrl(url).forEach(fr.headers.set);
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) fr.headers.set(HttpHeaders.rangeHeader, range);
      final fres = await fr.close();
      req.response.statusCode = fres.statusCode;
      // HttpClient do Dart descomprime gzip automaticamente (autoUncompress),
      // mas os headers da origem chegam intactos — repassar content-encoding
      // faz o browser tentar descomprimir duas vezes
      // (ERR_CONTENT_DECODING_FOUND, bug F3.4 2026-08-18: BG/áudio 200 mas morto).
      const drop = {
        'content-encoding',
        'content-length',
        HttpHeaders.transferEncodingHeader,
      };
      fres.headers.forEach((n, v) {
        if (drop.contains(n.toLowerCase())) return;
        // Headers com não-ASCII (Content-Disposition com acento no
        // filename, ex: "É Jesus.mp3") quebram headers.set → 502
        // (bug 2026-08-18: áudio 502, imagens ok por não terem acento).
        final flat = v.join(', '); // List<String> multi-valor plano
        if (flat.codeUnits.any((c) => c > 127)) return;
        req.response.headers.set(n, v);
      });
      req.response.headers.set('Access-Control-Allow-Origin', '*');
      await fres.pipe(req.response);
    } catch (e) {
      try {
        req.response.statusCode = 502;
        req.response.write('proxy error: $e');
        await req.response.close();
      } catch (_) {}
    } finally {
      hc.close(force: true);
    }
  }

  void _applyRangeHeaders(HttpRequest req, PalcoRangeResponse r) {
    req.response.statusCode = r.status;
    req.response.headers.contentType = ContentType.parse(r.contentType);
    req.response.headers.set(
      HttpHeaders.contentLengthHeader,
      r.contentLength.toString(),
    );
    req.response.headers.set('Accept-Ranges', 'bytes');
    req.response.headers.set('Access-Control-Allow-Origin', '*');
    if (r.contentRange != null) {
      req.response.headers.set(HttpHeaders.contentRangeHeader, r.contentRange!);
    }
  }

  Future<String?> _localIp() async {
    final hint = rendererSubnetHint;
    final candidates = <String>[];
    for (final iface in await NetworkInterface.list()) {
      for (final addr in iface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          candidates.add(addr.address);
        }
      }
    }
    if (hint != null && candidates.isNotEmpty) {
      final prefix = hint.split('.').take(3).join('.');
      final match = candidates.where((c) => c.startsWith('$prefix.')).toList();
      if (match.isNotEmpty) return match.first;
    }
    return candidates.isEmpty ? null : candidates.first;
  }
}

class Uint8ListListEntry {
  Uint8ListListEntry(this.bytes);
  final List<int> bytes;
}
