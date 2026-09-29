library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;

import 'palco_models.dart';
import 'palco_proxy.dart';
import 'palco_sender.dart';

/// Alvo Palco descoberto na rede (mDNS ou manual).
class PalcoTarget {
  const PalcoTarget({required this.name, required this.ip, this.wsPort = 7081});
  final String name;
  final String ip;
  final int wsPort;
}

/// Controla o Palco via WS — API espelhada no CastController (DLNA) para
/// que StageSession trate os dois transportes igual.
///
/// Fluxo (validado no spike): start() → TV conecta no WS → send(projection).
/// A TV é "display burro": aqui só enviamos mensagens e ouvimos eventos
/// (unlocked/ended/remote-key) — quem decide é o módulo chamador.
class PalcoController extends ChangeNotifier {
  PalcoController({PalcoSender? sender}) : _sender = sender ?? PalcoSender();
  final PalcoSender _sender;
  StreamSubscription<PalcoMessage>? _eventsSub;

  /// Porta WS efetiva do sender (efêmera em teste).
  int get wsPort => _sender.effectiveWsPort;

  PalcoTarget? target;
  String? _httpBase;

  bool get isConnected => _sender.clientCount > 0;
  bool get isRunning => _sender.isRunning;

  /// F3.3x: IP da TV conectada (visto pelo socket WS no momento do connect).
  String? get receiverIp => _sender.receiverIp;
  int get clientCount => _sender.clientCount;

  /// Eventos receiver→sender expostos (unlocked, ended, remote-key...).
  Stream<PalcoMessage> get events => _sender.events;

  /// Liga o sender (HTTP+WS). A TV conecta sozinha ao abrir o app dela
  /// (host informado por QR/config) — nada de push pra TV aqui.
  Future<bool> connect(PalcoTarget tv) async {
    _sender.rendererSubnetHint = tv.ip;
    final base = await _sender.start();
    if (base == null) return false;
    _httpBase = base;
    target = tv;
    _eventsSub?.cancel();
    // F3.3x: qualquer evento do receiver notifica — isConnected/receiverIp
    // mudam quando a TV conecta, e a UI precisa reagir.
    _eventsSub = _sender.events.listen((m) {
      _handleRemoteEvent(m);
      notifyListeners();
    }, onError: (_) {});
    debugPrint('[PALCO] conectado (sender ativo, TV=$tv.ip)');
    notifyListeners();
    return true;
  }

  Future<void> disconnect() async {
    await _eventsSub?.cancel();
    _eventsSub = null;
    await _sender.stop();
    _httpBase = null;
    target = null;
    notifyListeners();
  }

  /// Base HTTP do sender (pra construir URLs de proxy/mídia).
  String? get httpBase => _httpBase;

  /// URL de mídia externa envelopada no proxy do sender.
  String proxyUrl(String externalUrl) => _httpBase == null
      ? externalUrl
      : PalcoProxyHeaders.wrapForProxy(_httpBase!, externalUrl);

  /// Mídia local (bytes) servida e URL pronta pra mensagem.
  String? serveMedia(String name, List<int> bytes) {
    if (_httpBase == null) return null;
    _sender.serveMedia(name, bytes);
    return '$_httpBase/media/$name';
  }

  void clearMedia() => _sender.clearMedia();

  // ---- Envios (espelham o protocolo v2) ----

  void project({
    required String text,
    String footer = '',
    String? background,
    String? footerRef,
    String? footerColor,
    int? footerWeight,
    String? footerVersion,
    bool? textShadow,
    double? shadowBlur,
    double? shadowIntensity,
    bool? textBox,
    double? boxOpacity,
    Map<String, dynamic>? boxBorder,
    String? textAlign,
    String? textVerticalAlign,
    double? fontSize,
    int? fontWeight,
  }) {
    _sender.send(
      PalcoMessage.projection(
        text: text,
        footer: footer,
        background: background,
        footerRef: footerRef,
        footerColor: footerColor,
        footerWeight: footerWeight,
        footerVersion: footerVersion,
        textShadow: textShadow,
        shadowBlur: shadowBlur,
        shadowIntensity: shadowIntensity,
        textBox: textBox,
        boxOpacity: boxOpacity,
        boxBorder: boxBorder,
        textAlign: textAlign,
        textVerticalAlign: textVerticalAlign,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }

  void projectIdle() {
    _sender.send(PalcoMessage.idleRequest);
  }

  void setPalcoBackground(String? url) {
    _sender.send(PalcoMessage.bgPalco(url));
  }

  void playAudio(
    String url, {
    String? title,
    String? subtitle,
    String? cover,
    String? background,
    Duration? position,
  }) {
    // Paths locais (file path do celular) NÃO vão ao proxy — o receiver
    // não os alcança. O chamador (StageSession) deve ter convertido via
    // serveMedia; se chegou aqui, é bug: não manda URL quebrada.
    final isHttp = url.startsWith('http://') || url.startsWith('https://');
    final target = isHttp ? proxyUrl(url) : url;
    _sender.send(
      PalcoMessage.audio(
        target,
        title: title,
        subtitle: subtitle,
        cover: cover,
        background: background,
        positionMs: position?.inMilliseconds,
      ),
    );
  }

  void pauseAudio() => _sender.send(
    const PalcoMessage(type: 'audio', fields: {'action': 'pause'}),
  );

  void resumeAudio() => _sender.send(
    const PalcoMessage(type: 'audio', fields: {'action': 'play'}),
  );

  void stopAudio() => _sender.send(
    const PalcoMessage(type: 'audio', fields: {'action': 'stop'}),
  );

  /// Seek no receiver (segundos). F3.3: modo tv usa a TV como relógio.
  void seekAudio(double seconds) => _sender.send(
    PalcoMessage(
      type: 'audio',
      fields: {'action': 'seek', 'position': seconds},
    ),
  );

  // ---- Controle remoto (receivers desktop/web) ----

  final Map<String, Completer<Map<String, dynamic>>> _ackWaiters = {};

  /// Estado do último player reportado por receiver desktop/web.
  Map<String, dynamic> _remoteState = const {};
  Map<String, dynamic> get remotePlayerState => _remoteState;

  /// Roles conectados agora (ex: {'tv': 1, 'desktop': 1}).
  Map<String, int> get receiverRoles => _sender.roleCounts;

  /// Emite quando receivers/roles mudam (UI atualiza lista de alvos).
  Stream<void> get receiversChanged => _sender.rolesChanged;

  void _handleRemoteEvent(PalcoMessage m) {
    if (m.type == 'remote.ack') {
      final id = m.remoteAckId;
      if (id != null) {
        final waiter = _ackWaiters.remove(id);
        if (waiter != null && !waiter.isCompleted) {
          waiter.complete(m.remoteState);
        }
      }
      if (m.remoteState.isNotEmpty) {
        _remoteState = m.remoteState;
        notifyListeners();
      }
    } else if (m.type == 'remote.state') {
      _remoteState = m.remoteState;
      notifyListeners();
    }
  }

  /// Envia comando de controle remoto a receivers [role] ('desktop'|'web').
  /// Retorna o estado reportado no ack, ou null se não há receiver/timeout.
  Future<Map<String, dynamic>?> sendRemoteCommand(
    String command, {
    String role = 'desktop',
    double? value,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final id = 'rc_${DateTime.now().microsecondsSinceEpoch}';
    final waiter = Completer<Map<String, dynamic>>();
    _ackWaiters[id] = waiter;
    final sent = _sender.sendToRole(
      role,
      PalcoMessage.remoteCommand(command, id: id, value: value),
    );
    if (!sent) {
      _ackWaiters.remove(id);
      return null;
    }
    try {
      return await waiter.future.timeout(timeout, onTimeout: () => const {});
    } catch (_) {
      return null;
    }
  }

  /// Vídeo: URL já servida pelo sender (/media) NÃO passa pelo proxy;
  /// externa (http/https de fora) é envelopada. Bug duplo-wrap quebrava
  /// o play de .mp4 local (URL triplamente embrulhada → 404 no receiver).
  void playVideo(String url) {
    final isSenderMedia = _httpBase != null && url.startsWith(_httpBase!);
    _sender.send(PalcoMessage.video(isSenderMedia ? url : proxyUrl(url)));
  }

  void stopVideo() => _sender.send(
    const PalcoMessage(type: 'video', fields: {'action': 'stop'}),
  );

  /// Pausa/continua o vídeo na TV (toggle — mesmo comportamento da
  /// tecla OK do controle remoto da TV).
  void toggleVideoPause() => _sender.send(
    const PalcoMessage(type: 'video', fields: {'action': 'pause'}),
  );

  void startTimer({
    required int duration,
    String mode = 'countdown',
    String label = '',
    String? color,
    double? fontSize,
    int? fontWeight,
    bool? textShadow,
    double? shadowBlur,
    double? shadowIntensity,
    String? textAlign,
    String? textVerticalAlign,
  }) => _sender.send(
    PalcoMessage.timer(
      action: 'start',
      duration: duration,
      mode: mode,
      label: label,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      textShadow: textShadow,
      shadowBlur: shadowBlur,
      shadowIntensity: shadowIntensity,
      textAlign: textAlign,
      textVerticalAlign: textVerticalAlign,
    ),
  );

  void stopTimer() => _sender.send(PalcoMessage.timer(action: 'stop'));
}

/// Destino do áudio quando o Palco está ativo (F3.2).
enum PalcoAudioRoute {
  /// Áudio só no celular (comportamento pré-F3.2).
  local,

  /// Áudio SÓ na TV — celular vira controle (player local parado).
  tv,

  /// Espelho: toca no celular E na TV (drift aceitável, sem sync de clock).
  mirror,
}
