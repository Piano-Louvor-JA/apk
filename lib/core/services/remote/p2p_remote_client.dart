// Cliente WebRTC do Controle Remoto P2P (web ↔ APK) — handshake 2-QR.
//
// Web mostra QR com o OFFER → APK escaneia → cria ANSWER → mostra QR +
// texto copiável (pro usuário colar no web sem webcam) → conectado.
// DataChannel roda o mesmo protocolo JSON do WS (RemoteCommand/State).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

class P2pRemoteClient {
  RTCPeerConnection? _pc;
  RTCDataChannel? _channel;

  final void Function(Map<String, dynamic> message)? onMessage;
  final void Function()? onOpen;
  final void Function()? onClose;

  P2pRemoteClient({this.onMessage, this.onOpen, this.onClose});

  bool get isOpen => _channel?.state == RTCDataChannelState.RTCDataChannelOpen;

  /// Passo 2: recebe o offer (JSON do QR do web), retorna o answer p/ QR.
  Future<String?> acceptOffer(String offerJson) async {
    try {
      final desc = jsonDecode(offerJson) as Map<String, dynamic>;
      _pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      });
      _pc!.onDataChannel = _bind;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(desc['sdp'] as String, desc['type'] as String),
      );
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      // Espera ICE gathering (candidatos precisam ir no answer do QR).
      // flutter_webrtc: onIceGatheringState não dispara de forma confiável;
      // contamos candidatos via onCandidate + timeout como rede de segurança.
      await _waitIce(_pc!);
      final local = await _pc!.getLocalDescription();
      if (local == null) return null;
      return jsonEncode({'sdp': local.sdp, 'type': local.type});
    } catch (_) {
      return null;
    }
  }

  Future<void> _waitIce(RTCPeerConnection pc) async {
    final completer = Completer<void>();
    var done = false;
    // contagem não é necessária: idle timer cobre
    Timer? idle;
    void finish() {
      if (!done && !completer.isCompleted) {
        done = true;
        idle?.cancel();
        completer.complete();
      }
    }

    pc.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) finish();
    };
    // flutter_webrtc nativo entrega candidatos via onCandidate —
    // alguns builds não sinalizam gatheringState=complete.
    pc.onIceCandidate = (candidate) {
      // candidato recebido — reinicia idle timer
      // Sem novo candidato por 1.5s após o primeiro → considera completo.
      idle?.cancel();
      idle = Timer(const Duration(milliseconds: 1500), finish);
    };
    // timeout máximo: segue com o que tiver
    Timer(const Duration(seconds: 8), finish);
    await completer.future;
    // Evita disparo tardio de finish() depois do await.
    done = true;
  }

  void _bind(RTCDataChannel ch) {
    _channel = ch;
    ch.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) onOpen?.call();
      if (state == RTCDataChannelState.RTCDataChannelClosed) onClose?.call();
    };
    ch.onMessage = (data) {
      try {
        final m = jsonDecode(data.text) as Map<String, dynamic>;
        onMessage?.call(m);
      } catch (_) {}
    };
  }

  void send(Map<String, dynamic> payload) {
    if (isOpen) {
      _channel!.send(RTCDataChannelMessage(jsonEncode(payload)));
    }
  }

  void dispose() {
    _channel?.close();
    _pc?.dispose();
    _channel = null;
    _pc = null;
  }
}
