library;

import 'dart:async';
import 'dart:io';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

/// Servidor WebSocket do APK para CONTROLAR a página web pelo celular.
///
/// Inversão do fluxo desktop: o browser não aceita conexão de entrada,
/// então o APK é o servidor (`ws://IP:PORT?t=TOKEN`) e a página conecta.
/// Mas o sentido das mensagens é o MESMO do protocolo:
/// - APK → web: RemoteCommand (o celular é o controle)
/// - web → APK: RemotePlayerState / ack / ping
///
/// Auth: token na query string (`?t=`) validado no handshake — token
/// errado = upgrade recusado (401), sem nunca abrir o socket.
class WebLinkServer {
  HttpServer? _server;
  WebSocket? _client;
  String? _token;

  final _statesCtrl = StreamController<RemotePlayerState>.broadcast();
  final _acksCtrl = StreamController<RemoteAck>.broadcast();
  final _errorsCtrl = StreamController<RemoteError>.broadcast();
  final _clientEventsCtrl = StreamController<bool>.broadcast();

  Stream<RemotePlayerState> get states => _statesCtrl.stream;
  Stream<RemoteAck> get acks => _acksCtrl.stream;
  Stream<RemoteError> get errors => _errorsCtrl.stream;

  /// true = cliente conectou; false = desconectou.
  Stream<bool> get clientEvents => _clientEventsCtrl.stream;

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;
  bool get hasClient => _client != null;

  /// Sobe o servidor em porta alta. Retorna a URL completa com token
  /// (`ws://IP:PORT?t=TOKEN`) para exibir/QR no app, ou null sem rede.
  Future<String?> start({required String token}) async {
    _token = token;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    } catch (_) {
      return null;
    }
    _server!.listen((request) async {
      // Auth no handshake: ?t=TOKEN obrigatório e exato.
      final provided = request.uri.queryParameters['t'];
      if (provided == null || !RemotePairing.matches(_token ?? '', provided)) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }
      // 1 cliente web por vez (1 operador controla).
      if (_client != null) {
        request.response.statusCode = HttpStatus.conflict;
        await request.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(request);
      _client = ws;
      _clientEventsCtrl.add(true);
      ws.listen(
        (data) => _handleFrame(data as String),
        onDone: _onClientDown,
        onError: (_) => _onClientDown(),
        cancelOnError: true,
      );
    }, onError: (_) {});
    final ip = await _localIp();
    if (ip == null) {
      await stop();
      return null;
    }
    return 'ws://$ip:${_server!.port}?t=$token';
  }

  void _handleFrame(String raw) {
    final msg = RemoteProtocol.parse(raw);
    if (msg == null) return;
    switch (msg) {
      case RemotePlayerState():
        _statesCtrl.add(msg);
      case RemoteAck():
        _acksCtrl.add(msg);
      case RemoteError():
        _errorsCtrl.add(msg);
      case RemotePing():
        _reply(const RemotePong());
      default:
        break; // web não envia comandos ao controlador no v1
    }
  }

  void _reply(RemoteMessage msg) => _client?.add(msg.encode());

  void _onClientDown() {
    _client = null;
    _clientEventsCtrl.add(false);
  }

  /// Envia um comando do operador para a página web conectada.
  bool sendCommand(RemoteCommand command) {
    if (_client == null) return false;
    _client!.add(command.encode());
    return true;
  }

  Future<void> stop() async {
    await _client?.close();
    _client = null;
    await _server?.close(force: true);
    _server = null;
  }

  Future<String?> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
      // Ambiente sem IP externo (emulador/teste): loopback mantém o fluxo
      // utilizável em dev; em device real sempre há IP de LAN/Wi-Fi.
      return InternetAddress.loopbackIPv4.address;
    } catch (_) {
      return null;
    }
  }
}
