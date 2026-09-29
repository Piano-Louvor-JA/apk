library;

import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

/// F3.4 fase 3a (RF-003): WAKE remoto pro Palco Android TV.
///
/// O WakeService na TV escuta :7082; `WAKE\n` traz o app pro foreground.
/// Falha silenciosa por design: LG/webOS não tem o serviço (porta fechada)
/// e o fluxo segue exatamente como hoje — zero regressão.
class PalcoWake {
  /// Envia WAKE pra TV. Retorna true se entregou (não garante launch).
  static Future<bool> send(String ip) async {
    Socket? sock;
    try {
      sock = await Socket.connect(
        ip,
        7082,
        timeout: const Duration(milliseconds: 1200),
      );
      sock.write('WAKE\n');
      await sock.flush();
      debugPrint('[WAKE] enviado pra $ip');
      return true;
    } catch (_) {
      // porta fechada (LG/outra TV) — normal, silencioso
      return false;
    } finally {
      sock?.destroy();
    }
  }
}
