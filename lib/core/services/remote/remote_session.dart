library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_slide_gallery.dart';
import 'package:louvorja_piano_mobile/core/services/remote/desktop_connection.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_device_name.dart';
import 'package:louvorja_piano_mobile/core/services/remote/web_link_server.dart';

enum RemoteMode { idle, desktop, web }

/// Orquestra o controle remoto do APK — singleton global (como StageSession).
///
/// Dois modos mutuamente exclusivos:
/// - [RemoteMode.desktop]: APK = cliente WS do servidor do Electron;
/// - [RemoteMode.web]: APK = servidor WS; a página web conecta nele.
///
/// Em AMBOS o APK é o CONTROLADOR: comandos saem do APK (send), estado
/// chega do alvo (states). A UI escuta `states` e `status`.
class RemoteSession {
  /// Público para testes injetarem instâncias isoladas; no app o canônico
  /// é [RemoteSession.instance] (padrão StageSession).
  RemoteSession();
  static final RemoteSession instance = RemoteSession();

  DesktopConnection? _desktop;
  WebLinkServer? _web;
  StreamSubscription<RemotePlayerState>? _desktopStateSub;
  StreamSubscription<RemoteVideoFrame>? _desktopFrameSub;

  /// Último quadro do vídeo/YouTube aberto no desktop, já decodificado: a
  /// prévia troca só a imagem, sem reconstruir a barra a cada quadro.
  final ValueNotifier<Uint8List?> videoFrame = ValueNotifier(null);
  StreamSubscription<DesktopConnectionStatus>? _desktopStatusSub;
  StreamSubscription<RemoteError>? _desktopErrorSub;
  RemoteMode _mode = RemoteMode.idle;

  final _statesCtrl = StreamController<RemotePlayerState>.broadcast();
  final _statusCtrl = StreamController<RemoteSessionStatus>.broadcast();

  Stream<RemotePlayerState> get states => _statesCtrl.stream;
  Stream<RemoteSessionStatus> get status => _statusCtrl.stream;

  RemoteMode get mode => _mode;

  RemoteSessionStatus _lastStatus = RemoteSessionStatus.disconnected;

  /// Status mais recente (mantido em sync com o stream [status]).
  RemoteSessionStatus get currentStatus => _lastStatus;

  /// true quando o APK está efetivamente controlando um alvo:
  /// - desktop: conexão estabelecida com o Electron;
  /// - web: servidor de pé E o browser conectou nele.
  ///
  /// É ESTE getter (não `mode != idle`) que a UI deve usar para decidir
  /// se mostra a ferramenta/espelho — no modo web o servidor fica escutando
  /// sem cliente, e isso NÃO é "conectado".
  bool get isControlling =>
      _mode != RemoteMode.idle && _lastStatus == RemoteSessionStatus.connected;

  /// Conecta no desktop (Electron). Reconexão automática é da connection.
  Future<bool> connectDesktop({
    required String host,
    required int port,
    required String token,
  }) async {
    await _teardown();
    lastState = null;
    final conn = DesktopConnection();

    // Assina ANTES de abrir o socket. O desktop manda state imediatamente
    // no upgrade WS; assinar depois perde esse frame em Stream.broadcast.
    _desktopStateSub = conn.states.listen((s) {
      _receive(s);
    });
    _desktopStatusSub = conn.status.listen((s) {
      if (s == DesktopConnectionStatus.closed) {
        unawaited(_dropDesktop());
        return;
      }
      _emitStatus(s.toSessionStatus());
    });
    _desktopFrameSub = conn.frames.listen((frame) {
      final bytes = RemoteSlideGallery.decode(frame.data);
      if (bytes != null) videoFrame.value = bytes;
    });
    _desktopErrorSub = conn.errors.listen((error) {
      // Fechamento normal do Electron: derruba UI remota imediatamente.
      if (error.code == 'desktop_closed') unawaited(_dropDesktop());
    });

    final ok = await conn.connect(host: host, port: port, token: token);
    if (!ok) {
      await _desktopStateSub?.cancel();
      await _desktopFrameSub?.cancel();
      await _desktopStatusSub?.cancel();
      await _desktopErrorSub?.cancel();
      _desktopStateSub = null;
      _desktopFrameSub = null;
      _desktopStatusSub = null;
      _desktopErrorSub = null;
      await conn.dispose();
      return false;
    }
    _desktop = conn;
    _mode = RemoteMode.desktop;
    _emitStatus(RemoteSessionStatus.connected);
    // Identifica o aparelho para o desktop mostrar quem conectou.
    final device = await RemoteDeviceName.get() ?? 'Piano LouvorJA';
    final version = await RemoteDeviceName.appVersion();
    conn.sendHello(device: device, appVersion: version);
    return true;
  }

  /// Sobe o servidor WS para o web conectar. Retorna a URL `ws://…?t=…`
  /// (pra QR/link) ou null se não há rede.
  Future<String?> startWebLink({required String token}) async {
    await _teardown();
    final server = WebLinkServer();
    final url = await server.start(token: token);
    if (url == null) {
      await server.stop();
      return null;
    }
    _web = server;
    _mode = RemoteMode.web;
    server.states.listen((s) {
      _receive(s);
    });
    server.clientEvents.listen((up) {
      _emitStatus(
        up ? RemoteSessionStatus.connected : RemoteSessionStatus.listening,
      );
    });
    _emitStatus(RemoteSessionStatus.listening);
    return url;
  }

  /// Envia um comando do operador ao ALVO (desktop ou web) — o APK é
  /// sempre o controlador.
  Future<void> send(RemoteCommand command) async {
    switch (_mode) {
      case RemoteMode.desktop:
        await _desktop?.send(command);
      case RemoteMode.web:
        _web?.sendCommand(command);
      case RemoteMode.idle:
        break;
    }
  }

  /// Estado mais recente vindo do alvo (desktop push ou web push).
  /// Usado pela UI e como cache para resync em reconexão.
  RemotePlayerState? lastState;

  // (v1: o APK é controlador — estado flui alvo→APK. pushState reservado v2.)

  /// Hook de teste: injeta um estado como se tivesse vindo do alvo.
  void debugInjectStateForTest({
    String? title,
    required bool playing,
    bool canPrevious = false,
    bool canNext = false,
    RemoteMediaState? mediaModule,
    int volume = 80,
    Duration duration = const Duration(minutes: 3),
  }) {
    final state = RemotePlayerState(
      hymnId: 1,
      title: title,
      mode: 'audio',
      playing: playing,
      position: const Duration(seconds: 34),
      duration: duration,
      slideIndex: 1,
      slideCount: 5,
      volume: volume,
      canPrevious: canPrevious,
      canNext: canNext,
      mediaModule: mediaModule,
    );
    _receive(state);
  }

  /// Todo estado do alvo passa por aqui: a galeria de miniaturas é guardada
  /// mesmo sem nenhuma tela de player aberta.
  void _receive(RemotePlayerState state) {
    lastState = state;
    // Vídeo fechado: o quadro antigo não pode aparecer no próximo vídeo.
    if (state.videoControls == null) videoFrame.value = null;
    RemoteSlideGallery.remember(state);
    _statesCtrl.add(state);
  }

  @visibleForTesting
  void debugEmitStateForTest(RemotePlayerState state) => _receive(state);

  Future<void> disconnect() async {
    await _dropDesktop();
  }

  /// Limpa imediatamente UI/estado remoto quando o desktop encerra.
  Future<void> _dropDesktop() async {
    await _teardown();
    lastState = null;
    _mode = RemoteMode.idle;
    _emitStatus(RemoteSessionStatus.disconnected);
  }

  void _emitStatus(RemoteSessionStatus s) {
    _lastStatus = s;
    _statusCtrl.add(s);
  }

  Future<void> _teardown() async {
    videoFrame.value = null;
    await _desktopFrameSub?.cancel();
    _desktopFrameSub = null;
    await _desktopStateSub?.cancel();
    await _desktopStatusSub?.cancel();
    await _desktopErrorSub?.cancel();
    _desktopStateSub = null;
    _desktopStatusSub = null;
    _desktopErrorSub = null;
    await _desktop?.dispose();
    _desktop = null;
    await _web?.stop();
    _web = null;
  }

  Future<void> dispose() async {
    // Singleton: controllers NÃO fecham (vivem com o app). Só derruba o
    // transporte — conexões podem ser refeitas depois.
    await _teardown();
    _mode = RemoteMode.idle;
    _emitStatus(RemoteSessionStatus.disconnected);
  }
}

enum RemoteSessionStatus { disconnected, connecting, connected, listening }

extension on DesktopConnectionStatus {
  RemoteSessionStatus toSessionStatus() => switch (this) {
    DesktopConnectionStatus.disconnected => RemoteSessionStatus.disconnected,
    DesktopConnectionStatus.connecting => RemoteSessionStatus.connecting,
    DesktopConnectionStatus.connected => RemoteSessionStatus.connected,
    DesktopConnectionStatus.closed => RemoteSessionStatus.disconnected,
  };
}
