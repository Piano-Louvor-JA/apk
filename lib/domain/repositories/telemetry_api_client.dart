library;

/// Contrato da telemetria de dispositivos online (regra 11 do AGENTS.md: API
/// sempre via interface). Endpoint: POST /v1/telemetry/heartbeat — contrato
/// em pianolouvorja/api/src/v1/telemetry/telemetry.routes.ts.
abstract interface class TelemetryApiClient {
  /// Envia o sinal de "online". `true` quando a API aceitou; falha nunca
  /// derruba o app (o loop tenta no proximo ciclo).
  Future<bool> sendHeartbeat(Map<String, Object?> body);
}
