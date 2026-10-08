// Sync v2 fase 2 (apk#107) — cliente do estado do operador: outbox local +
// flush batch no POST /v1/custom/sync + pull LWW da resposta.
//
// Réplica Flutter do app#350 (sync-outbox-service.ts + operator-state-apply.ts),
// com as adaptações declaradas da plataforma:
// - storage: SharedPreferences (web/app usam localStorage)
// - rede: fetch injetável CustomFetch (mesmo padrão do CustomAuthApiImpl)
// - sessão: token via CustomSessionStore lido pelo chamador (secure storage —
//   o cliente recebe apenas uma função sessionToken() e nunca persiste token)
// - prefs: whitelist com as keys LOCAIS do APK (SettingsController)
//
// Regras offline-first (inegociáveis, spec SYNC-V2 §RF-01..03):
// - enqueue NUNCA toca rede
// - coalescing por namespace::key (última escrita vence na fila)
// - flush sem sessão real NÃO envia — fica na fila
// - falha de rede mantém a fila íntegra
// - pull aplicado NUNCA grava de volta no outbox (sem loop de sync)
library;

import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

/// Assinatura de fetch injetável (mesma do CustomAuthApiImpl). Retorna o
/// body decodificado da resposta ou null quando vazio.
typedef OperatorStateFetch =
    Future<Map<String, dynamic>?> Function(
      String method,
      String url, {
      Map<String, dynamic>? body,
      String? bearerToken,
    });

/// Payload do estado dos agendados (mesmo wire do scheduledState do app:
/// `{categories, items}` — tojson de ScheduledCategory/ScheduledItem).
class ScheduledStatePayload {
  const ScheduledStatePayload({
    required this.categories,
    required this.items,
  });

  final List<ScheduledCategory> categories;
  final List<ScheduledItem> items;

  Map<String, dynamic> toJson() => {
    'categories': categories.map((e) => e.toJson()).toList(),
    'items': items.map((e) => e.toJson()).toList(),
  };

  /// Valida a forma do payload vindo do servidor. Divergência → inválido
  /// (item ignorado no pull, sem quebrar).
  static bool isValid(Object? value) =>
      value is Map<String, dynamic> &&
      value['categories'] is List<dynamic> &&
      value['items'] is List<dynamic>;
}

/// Entrada da outbox (mesma forma do OperatorStateItem da API — campo
/// `updated_at` no push; servidor devolve `updated_at_ms` no pull).
class OutboxEntry {
  const OutboxEntry({
    required this.clientUuid,
    required this.namespace,
    required this.key,
    required this.valueJson,
    required this.updatedAt,
    this.deletedAt,
  });

  final String clientUuid;
  final String namespace;
  final String key;
  final String valueJson;
  final int updatedAt;
  final int? deletedAt;

  Map<String, dynamic> toPushJson() => {
    'client_uuid': clientUuid,
    'namespace': namespace,
    'key': key,
    'value_json': valueJson,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };

  static OutboxEntry fromStorage(Map<String, dynamic> map) => OutboxEntry(
    clientUuid: map['client_uuid'] as String,
    namespace: map['namespace'] as String,
    key: map['key'] as String,
    valueJson: map['value_json'] as String,
    updatedAt: (map['updated_at'] as num).toInt(),
    deletedAt: map['deleted_at'] as int?,
  );

  Map<String, dynamic> toStorage() => {
    'client_uuid': clientUuid,
    'namespace': namespace,
    'key': key,
    'value_json': valueJson,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

/// Whitelist das preferências do operador que SINCRONIZAM entre dispositivos
/// (apk#107). FORA desta lista NUNCA viaja — protege estado transitório e
/// namespaces próprias do sync. Token/sessão NEM participam deste storage
/// (vivem em FlutterSecureStorage via CustomSessionStore).
abstract final class SyncablePrefKeys {
  static const all = <String>{
    'themeMode',
    'accent',
    'interaction',
    'glassIntensity',
  };
}

class OperatorStateClient {
  OperatorStateClient(
    this._prefs, {
    OperatorStateFetch? fetch,
    Future<String?> Function()? sessionToken,
    String? apiBaseUrl,
  }) : _fetch = fetch ?? _defaultFetch,
       _sessionToken = sessionToken,
       _apiBaseUrl = apiBaseUrl;

  final SharedPreferences _prefs;
  final OperatorStateFetch _fetch;
  final Future<String?> Function()? _sessionToken;
  final String? _apiBaseUrl;

  static const outboxStorageKey = 'louvorja.sync.outbox.v1';
  static const _updatedAtPrefix = 'louvorja.sync.operator.updatedAt';
  static const _scheduledMeta = 'scheduled::items';
  static const _prefsMeta = 'prefs::values';

  /// Resolvido por quem usa (mesma regra de CustomCollectionsPage._apiBase).
  static String apiBaseFromDatabase(String urlDatabase) =>
      urlDatabase.endsWith('/json_db')
      ? urlDatabase.substring(0, urlDatabase.length - '/json_db'.length)
      : urlDatabase;

  static Future<Map<String, dynamic>?> _defaultFetch(
    String method,
    String url, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    // Sem Dio injetado no default (o app injeta via CustomCollectionsPage
    // pattern); cliente default sem fetch = nunca envia. Injeção obrigatória
    // no wiring de produção.
    return null;
  }

  String? get _baseUrl {
    if (_apiBaseUrl != null) return _apiBaseUrl;
    return apiBaseFromDatabase(
      // mesma origem do json_db — declarada no dart-define do build
      const String.fromEnvironment('LOUVORJA_URL_DATABASE'),
    );
  }

  // ── Outbox ──────────────────────────────────────────────────────────────

  Map<String, Map<String, dynamic>> _readOutbox() {
    final raw = _prefs.getString(outboxStorageKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, (v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeOutbox(Map<String, Map<String, dynamic>> box) async {
    await _prefs.setString(outboxStorageKey, jsonEncode(box));
  }

  int outboxCount() => _readOutbox().length;

  static String _coalesceKey(String namespace, String key) =>
      '$namespace::$key';

  static String _uuid() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // v4
    b[8] = (b[8] & 0x3f) | 0x80; // variant
    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _enqueue(String namespace, String key, Object? value) async {
    final box = _readOutbox();
    final k = _coalesceKey(namespace, key);
    final existing = box[k];
    box[k] = {
      'client_uuid':
          existing?['client_uuid'] as String? ?? _uuid(),
      'namespace': namespace,
      'key': key,
      'value_json': jsonEncode(value),
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      'deleted_at': null,
    };
    await _writeOutbox(box);
  }

  /// Enfileira o estado atual dos agendados (local-first, sem rede).
  Future<void> enqueueScheduled(ScheduledStatePayload state) =>
      _enqueue('scheduled', 'items', state.toJson());

  /// Enfileira mutações de preferências (lote `prefs::values`).
  ///
  /// O lote é um MAPA acumulado: enfileirar `{a:1}` e depois `{b:2}` resulta
  /// num único item `{a:1, b:2}` (coalescing preserva as mutações anteriores
  /// ainda não enviadas).
  Future<void> enqueuePrefs(Map<String, Object?> values) async {
    final box = _readOutbox();
    final existing = box[_prefsMeta];
    final merged = <String, Object?>{
      if (existing != null)
        ...jsonDecode(existing['value_json'] as String) as Map<String, dynamic>,
      ...values,
    };
    await _enqueue('prefs', 'values', merged);
  }

  // ── Flush (push batch + pull da resposta) ───────────────────────────────

  Future<void> _setMeta(String namespace, int atMs) =>
      _prefs.setInt('$_updatedAtPrefix.$namespace', atMs);

  /// Envia a fila num batch. Retorna o operator_state do servidor (pull)
  /// quando algo foi enviado; null quando nada saiu (fila vazia, sem sessão
  /// ou falha — itens permanecem na fila).
  Future<List<Map<String, dynamic>>?> flush() async {
    final box = _readOutbox();
    if (box.isEmpty) return null;
    final token = await _sessionToken?.call();
    if (token == null) return null;
    final base = _apiBaseUrl ?? _baseUrl;
    if (base == null || base.isEmpty) return null;

    final entries = box.values.map(OutboxEntry.fromStorage).toList();

    Map<String, dynamic>? response;
    try {
      response = await _fetch(
        'POST',
        '$base/v1/custom/sync',
        body: {
          'collections': <Object>[],
          'operator_state': entries.map((e) => e.toPushJson()).toList(),
        },
        bearerToken: token,
      );
    } catch (_) {
      return null; // rede — itens permanecem na fila
    }
    if (response == null) return null;

    // enviado com sucesso: limpa SOMENTE os itens que foram no batch
    final sentUuids = entries.map((e) => e.clientUuid).toSet();
    final rest = _readOutbox()
      ..removeWhere((_, e) => sentUuids.contains(e['client_uuid'] as String));
    await _writeOutbox(rest);

    // LWW por namespace: cada produtor marca o SEU relógio (se veio no batch)
    final names = entries
        .map((e) => _coalesceKey(e.namespace, e.key))
        .toSet();
    final newestLocal = entries.fold<int>(
      DateTime.now().toUtc().millisecondsSinceEpoch,
      (max, e) => e.updatedAt > max ? e.updatedAt : max,
    );
    if (names.contains(_scheduledMeta)) {
      await _setMeta('scheduled', newestLocal);
    }
    if (names.contains(_prefsMeta)) {
      await _setMeta('prefs', newestLocal);
    }

    final serverItems = (response['operator_state'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    await applyOperatorState(_prefs, serverItems);
    return serverItems;
  }

  /// Reinicializa caches de teste (nenhum estado estático hoje — hook de
  /// paridade com o padrão dos outros clientes de sync).
  static void resetForTest() {}
}

/// Pull LWW: aplica operator_state do servidor no local.
///
/// - servidor com updated_at_ms MAIOR que o meta local → aplica
/// - servidor mais VELHO → local vence (nada muda)
/// - sem meta local (novo dispositivo) → aplica direto
/// - namespace desconhecida / payload inválido / tombstone → ignorado
Future<void> applyOperatorState(
  SharedPreferences prefs,
  List<Map<String, dynamic>> items,
) async {
  for (final item in items) {
    if (item['deleted_at'] != null) continue;
    final namespace = item['namespace'] as String?;
    final key = item['key'] as String?;
    final updatedAtMs = (item['updated_at_ms'] as num?)?.toInt();
    if (namespace == null || key == null || updatedAtMs == null) continue;

    final metaKey = '$namespace::$key';
    Object? value;
    try {
      value = jsonDecode(item['value_json'] as String);
    } catch (_) {
      continue;
    }

    switch (metaKey) {
      case 'scheduled::items':
        if (!ScheduledStatePayload.isValid(value)) continue;
        if (updatedAtMs <= _metaOf(prefs, 'scheduled')) continue; // LWW
        final state = value! as Map<String, dynamic>;
        final repo = ScheduledRepository(prefs);
        await repo.saveCategories(
          (state['categories'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(ScheduledCategory.fromJson)
              .toList()
              .cast<ScheduledCategory>(),
        );
        await repo.saveItems(
          (state['items'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(ScheduledItem.fromJson)
              .toList()
              .cast<ScheduledItem>(),
        );
        await prefs.setInt(
          '${OperatorStateClient._updatedAtPrefix}.scheduled',
          updatedAtMs,
        );
      case 'prefs::values':
        if (value is! Map<String, dynamic>) continue;
        if (updatedAtMs <= _metaOf(prefs, 'prefs')) continue; // LWW
        var applied = false;
        for (final entry in value.entries) {
          // whitelist: fora nunca viaja — nem do servidor mais novo
          if (!SyncablePrefKeys.all.contains(entry.key)) continue;
          await _applyPref(prefs, entry.key, entry.value);
          applied = true;
        }
        if (applied) {
          await prefs.setInt(
            '${OperatorStateClient._updatedAtPrefix}.prefs',
            updatedAtMs,
          );
        }
      // namespace desconhecida → ignorada sem quebrar (forward-compatible)
    }
  }
}

int _metaOf(SharedPreferences prefs, String namespace) =>
    prefs.getInt('${OperatorStateClient._updatedAtPrefix}.$namespace') ?? 0;

/// Aplica uma preferência no storage local, respeitando o tipo esperado por
/// chave (SettingsController usa String para os enums e int pro glass).
Future<void> _applyPref(
  SharedPreferences prefs,
  String key,
  Object? value,
) async {
  switch (key) {
    case 'glassIntensity':
      if (value is num) {
        await prefs.setInt(key, value.toInt().clamp(0, 100));
      }
    case 'themeMode' || 'accent' || 'interaction':
      if (value is String) await prefs.setString(key, value);
  }
}
