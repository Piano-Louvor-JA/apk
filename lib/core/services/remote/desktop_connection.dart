library;

import 'dart:async';
import 'dart:io';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

enum DesktopConnectionStatus {
  disconnected,
  connecting,
  connected,

  /// Peer sumiu e todas as tentativas de reconexão falharam.
  closed,
}

/// Cliente WebSocket do APK → servidor do desktop (Electron).
///
/// Responsabilidades (SPEC controle-remoto-apk):
/// - conectar no `ws://host:port` do desktop com token de emparelhamento;
/// - expor streams de estado/ack/erro recebidos;
/// - responder pong aos pings do servidor;
/// - reconectar automaticamente (3 tentativas com backoff) em queda.
class DesktopConnection {
  DesktopConnection({
    this.heartbeat = const Duration(seconds: 15),
    this.reconnectDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 7),
    ],
  });

  final Duration heartbeat;
  final List<Duration> reconnectDelays;

  WebSocket? _ws;
  String? _host;
  int? _port;
  String? _token;
  var _attempt = 0;
  var _closingByUser = false;
  Timer? _heartbeatTimer;
  DateTime? _lastPeerActivity;

  final _statusCtrl = StreamController<DesktopConnectionStatus>.broadcast();
  final _statesCtrl = StreamController<RemotePlayerState>.broadcast();
  final _acksCtrl = StreamController<RemoteAck>.broadcast();
  final _errorsCtrl = StreamController<RemoteError>.broadcast();

  static final _allForTest = <DesktopConnection>[];

  Stream<DesktopConnectionStatus> get status => _statusCtrl.stream;
  Stream<RemotePlayerState> get states => _statesCtrl.stream;
  Stream<RemoteAck> get acks => _acksCtrl.stream;
  Stream<RemoteError> get errors => _errorsCtrl.stream;

  bool get isConnected => _ws?.readyState == WebSocket.open;

  /// Conecta no desktop. `false` = não conseguiu nem na primeira tentativa
  /// (sem reconexão — quem chama decide informar o usuário).
  Future<bool> connect({
    required String host,
    required int port,
    required String token,
  }) async {
    _host = host;
    _port = port;
    _token = token;
    _closingByUser = false;
    _statusCtrl.add(DesktopConnectionStatus.connecting);
    try {
      _ws = await WebSocket.connect('ws://$host:$port');
    } catch (_) {
      _statusCtrl.add(DesktopConnectionStatus.disconnected);
      return false;
    }
    _attempt = 0;
    _statusCtrl.add(DesktopConnectionStatus.connected);
    _lastPeerActivity = DateTime.now();
    _listen();
    _startHeartbeat();
    return true;
  }

  /// Envia a identificação do aparelho ao desktop (logo após conectar).
  void sendHello({required String device, String? appVersion}) {
    _ws?.add(RemoteHello(device: device, appVersion: appVersion).encode());
  }

  void _listen() {
    _ws!.listen(
      (data) {
        _lastPeerActivity = DateTime.now();
        final msg = RemoteProtocol.parse(data as String);
        if (msg == null) return;
        switch (msg) {
          case RemotePlayerState():
            _statesCtrl.add(msg);
          case RemoteAck():
            _acksCtrl.add(msg);
          case RemoteError():
            _errorsCtrl.add(msg);
          case RemotePing():
            _ws?.add(const RemotePong().encode());
          case RemotePong():
            break;
          case RemoteHello():
            break; // servidor não envia hello; resposta do APK é no connect
          case RemoteCommand():
            break; // cliente não recebe comandos no v1
        }
      },
      onDone: _onDown,
      onError: (_) => _onDown(),
      cancelOnError: true,
    );
  }

  void _onDown() {
    _stopHeartbeat();
    if (_statusCtrl.isClosed) return;
    _statusCtrl.add(DesktopConnectionStatus.disconnected);
    if (_closingByUser) return;
    _scheduleReconnect();
  }

  Future<void> _scheduleReconnect() async {
    final delay = _attempt < reconnectDelays.length
        ? reconnectDelays[_attempt]
        : null;
    if (delay == null) {
      _statusCtrl.add(DesktopConnectionStatus.closed);
      return;
    }
    _attempt++;
    await Future<void>.delayed(delay);
    if (_closingByUser || _host == null) return;
    _statusCtrl.add(DesktopConnectionStatus.connecting);
    try {
      _ws = await WebSocket.connect('ws://$_host:$_port');
    } catch (_) {
      _statusCtrl.add(DesktopConnectionStatus.disconnected);
      await _scheduleReconnect();
      return;
    }
    _attempt = 0;
    _statusCtrl.add(DesktopConnectionStatus.connected);
    _lastPeerActivity = DateTime.now();
    _listen();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(heartbeat, (_) {
      final last = _lastPeerActivity;
      if (last != null && DateTime.now().difference(last) > heartbeat * 2) {
        _ws?.close(); // dispara onDone → reconexão
        return;
      }
      _ws?.add(const RemotePing().encode());
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Envia comando. Token vai na primeira mensagem de cada conexão
  /// (auth implícito); depois, dispensável mas barato.
  ///
  /// Se o socket caiu (reconexão em curso), espera até 2s pela
  /// reconexão antes de desistir — comando de operador nunca é
  /// descartado silenciosamente (bug: botões "não faziam nada").
  Future<void> send(RemoteCommand command) async {
    if (!isConnected) {
      for (var i = 0; i < 10 && !isConnected; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    if (!isConnected) return;
    if (_token != null && command.token == null) {
      // token NÃO é final no RemoteCommand — injeta sem reconstruir
      // (reconstruir dropava os campos v2: bible.open chegava sem
      // bookId, media.search sem query — bug de 3 horas de caça).
      command.token = _token;
    }
    _ws?.add(command.encode());
  }

  Future<void> disconnect() async {
    _closingByUser = true;
    _stopHeartbeat();
    await _ws?.close();
    _ws = null;
    _statusCtrl.add(DesktopConnectionStatus.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _statusCtrl.close();
    await _statesCtrl.close();
    await _acksCtrl.close();
    await _errorsCtrl.close();
  }
}

/// Fecha todas as conexões criadas no teste (evita pendurar o runner).
Future<void> desktopCloseAllForTest() async {
  for (final c in DesktopConnection._allForTest) {
    await c.dispose();
  }
  DesktopConnection._allForTest.clear();
}
