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
import 'package:louvorja_piano_mobile/core/platform_header.dart';
import 'package:louvorja_piano_mobile/core/services/sync/operator_state_client.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';

abstract final class OperatorStateBoot {
  static OperatorStateClient? _client;

  /// Cliente com Dio default e sessão do secure storage. Construção lazy:
  /// o boot só monta quando o primeiro uso acontece (flush/hook).
  static OperatorStateClient client(
    SharedPreferences prefs, {
    Dio? dio,
    Future<String?> Function()? sessionToken,
    String? apiBaseUrl,
    Future<void> Function()? onApplied,
  }) {
    return _client ??= _build(
      prefs,
      dio: dio,
      sessionToken: sessionToken,
      apiBaseUrl: apiBaseUrl,
      onApplied: onApplied,
    );
  }

  static OperatorStateClient _build(
    SharedPreferences prefs, {
    Dio? dio,
    Future<String?> Function()? sessionToken,
    String? apiBaseUrl,
    Future<void> Function()? onApplied,
  }) {
    final http =
        dio ??
        Dio(
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
      final res = await http.request<Map<String, dynamic>>(
        url,
        data: body,
        options: Options(
          method: method,
          headers: {
            ...clientPlatformHeaders(),
            if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
          },
        ),
      );
      return res.data;
    }

    return OperatorStateClient(
      prefs,
      fetch: fetch,
      apiBaseUrl:
          apiBaseUrl ??
          OperatorStateClient.apiBaseFromDatabase(ApiConfig.urlDatabase),
      sessionToken:
          sessionToken ??
          () async => (await CustomSessionStore().read())?.token,
      onApplied: onApplied,
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

  /// Testes: descarta o singleton (SharedPreferences mockado por teste).
  static void resetForTest() => _client = null;
}
