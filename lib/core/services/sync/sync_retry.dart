// SPEC 7 (apk#92) — fila de retry de sincronização quando a rede volta.
//
// A outbox do sync v2 (OperatorStateClient) já é íntegra offline: enqueue
// nunca toca rede e flush que falha mantém a fila. Falta o gatilho: quando a
// conectividade retorna, o flush dispara SEM ação do usuário (aceite da SPEC 7).
//
// Regras:
// - só dispara na transição offline → online (nunca em rede instável repetida)
// - flush que lança é engolido (fila permanece pra próxima tentativa)
// - startOffline fixa o estado inicial pra testes; produção começa online
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'operator_state_client.dart';

/// Observa transições offline→online e dispara o flush da outbox.
class SyncRetry {
  SyncRetry(
    this._prefs, {
    required Future<void> Function() flush,
    bool startOffline = false,
  }) : _flush = flush,
       _offline = startOffline;

  final SharedPreferences _prefs;
  final Future<void> Function() _flush;
  bool _offline;

  /// true quando há itens pendentes na outbox (informativo p/ telemetria/UI).
  bool get hasPending {
    final raw = _prefs.getString(OperatorStateClient.outboxStorageKey);
    if (raw == null) return false;
    try {
      final entries = jsonDecode(raw);
      return entries is Map && entries.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Chamar a cada mudança de conectividade. Dispara o flush apenas na
  /// transição para ONLINE.
  void onNetworkBack(bool connected) {
    if (connected == false) {
      _offline = true;
      return;
    }
    if (!_offline) return; // já estávamos online: nada a fazer
    _offline = false;
    // fire-and-forget: flush nunca bloqueia nem derruba o app.
    Future<void>(() async {
      try {
        await _flush();
      } catch (_) {
        // rede/sessão falhou de novo — fila permanece íntegra
      }
    });
  }
}
