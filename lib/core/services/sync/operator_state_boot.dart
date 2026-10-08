// Boot do sync v2 (apk#107): instancia o cliente do estado do operador com
// Dio + sessão real e expõe os hooks usados pelo main.dart.
//
// Mantido fora do main.dart pra ser testável sem widget tree (os caminhos de
// rede/injeção seguem o padrão CustomCollectionsPage: Dio default + CustomFetch).
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import 'package:louvorja_piano_mobile/core/services/sync/operator_state_client.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_retry.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';

abstract final class OperatorStateBoot {
  static OperatorStateClient? _client;

  /// Cliente com Dio default e sessão do secure storage. Construção lazy:
  /// o boot só monta quando o primeiro uso acontece (flush/hook).
  static OperatorStateClient client(SharedPreferences prefs) {
    return _client ??= _build(prefs);
  }

  static OperatorStateClient _build(SharedPreferences prefs) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    Future<Map<String, dynamic>?> fetch(
      String method,
      String url, {
      Map<String, dynamic>? body,
      String? bearerToken,
    }) async {
      final res = await dio.request<Map<String, dynamic>>(
        url,
        data: body,
        options: Options(
          method: method,
          headers: {
            if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
          },
        ),
      );
      return res.data;
    }

    return OperatorStateClient(
      prefs,
      fetch: fetch,
      apiBaseUrl: OperatorStateClient.apiBaseFromDatabase(
        ApiConfig.urlDatabase,
      ),
      sessionToken: () async => (await CustomSessionStore().read())?.token,
    );
  }

  /// Hook de prefs (chamado pelos setters do SettingsController).
  static Future<void> enqueuePrefsChange(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) => client(prefs).enqueuePrefs({key: value});

  /// Flush no boot: nunca lança e nunca bloqueia o arranque do app.
  static Future<void> flushOnBoot(SharedPreferences prefs) async {
    try {
      await client(prefs).flush();
    } catch (_) {
      // rede/sessão indisponível — fila permanece pra próxima tentativa
    }
  }

  /// SPEC 7 (apk#92): retry de sincronização quando a rede volta.
  ///
  /// Liga o stream do [OfflineStatusController] ao [SyncRetry]: a transição
  /// offline→online dispara o flush da outbox sem ação do usuário.
  static SyncRetry bindSyncRetry(
    SharedPreferences prefs, {
    required Stream<bool> offlineStream,
  }) {
    final retry = SyncRetry(prefs, flush: () => client(prefs).flush());
    _retrySub = offlineStream.listen(retry.onNetworkBack);
    return retry;
  }

  /// Testes: cancela a assinatura do retry.
  static void unbindSyncRetry() {
    _retrySub?.cancel();
    _retrySub = null;
  }

  static StreamSubscription<bool>? _retrySub;

  /// Testes: descarta o singleton (SharedPreferences mockado por teste).
  static void resetForTest() => _client = null;
}
