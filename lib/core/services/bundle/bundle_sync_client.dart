library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:louvorja_piano_mobile/core/services/bundle/bundle_snapshot_store.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_sync_contract.dart';

/// Resultado de um ciclo `checkForUpdates` (paridade web/desktop).
class BundleCheckResult {
  final bool ok;
  /// Kinds checados neste ciclo (vazio = janela 24h bloqueou tudo).
  final List<String> checked;
  /// Kinds com NOVO bundle aplicado.
  final List<String> applied;
  /// Motivo sanitizado da falha (sem token/PII).
  final String? reason;

  const BundleCheckResult({
    required this.ok,
    this.checked = const [],
    this.applied = const [],
    this.reason,
  });
}

/// Contrato do ciclo de sync (permite fake/spy em testes e boot).
abstract class BundleSyncClientBase {
  Future<BundleCheckResult> checkForUpdates({bool force = false});
}

/// Client bundle-first — SPEC v1.2.0 ADR-09/10/11 (+ ADR-02/03 v1.0.0).
///
/// Teto de requests: cold full = 1 manifest + 1 ZIP por artifact divergente
/// (máx 3); run ≥24h sem mudança = 1 manifest, 0 ZIP; boot <24h = 0.
///
/// Qualquer falha preserva snapshot/estado anteriores e registra a tentativa
/// (sem retry automático antes de 24h — ADR-03). Nunca lança.
class BundleSyncClient implements BundleSyncClientBase {
  /// ADR-11: origem /db/* PRÓPRIA — default público upstream documentado.
  static const String defaultBundlesOrigin = 'https://api.louvorja.com.br';

  static const _checkIntervalMs = 24 * 60 * 60 * 1000;
  static const _stateVersion = 1;

  final Dio dio;
  final String origin;
  final BundleSnapshotStore store;
  final File stateFile;
  final DateTime Function() now;
  final void Function(String message)? debugLog;

  BundleSyncClient({
    required this.dio,
    required this.origin,
    required this.store,
    required this.stateFile,
    DateTime Function()? now,
    this.debugLog,
  }) : now = now ?? DateTime.now;

  String get manifestUrl => '$origin/db/manifest';
  String bundleUrl(BundleKind kind) => '$origin/db/${kind.name}-bundle';

  /// Estado por artifact; null = nunca sincronizado.
  @visibleForTesting
  Map<String, BundleArtifactState?> readStates() {
    if (!stateFile.existsSync()) {
      return {for (final k in BundleKind.values) k.name: null};
    }
    try {
      final raw = jsonDecode(stateFile.readAsStringSync());
      if (raw is! Map<String, dynamic>) {
        return {for (final k in BundleKind.values) k.name: null};
      }
      return {
        for (final k in BundleKind.values)
          k.name: BundleArtifactState.fromJson(
              k, raw[k.name] as Map<String, dynamic>?),
      };
    } catch (_) {
      return {for (final k in BundleKind.values) k.name: null};
    }
  }

  Future<void> _writeState(
    BundleKind kind,
    String digest, {
    required bool applied,
  }) async {
    final states = readStates();
    final prior = states[kind.name];
    final ts = now().millisecondsSinceEpoch;
    final next = BundleArtifactState(
      artifact: kind,
      manifestDigest: applied ? digest : (prior?.manifestDigest ?? digest),
      checkedAtEpochMs: ts,
      appliedAtEpochMs: applied ? ts : (prior?.appliedAtEpochMs ?? 0),
    );
    states[kind.name] = next;
    final payload = {
      'version': _stateVersion,
      for (final e in states.entries)
        e.key: (e.value ?? next).toJson(),
    };
    final tmp = File('${stateFile.path}.tmp');
    await tmp.writeAsString(jsonEncode(payload), flush: true);
    tmp.renameSync(stateFile.path);
  }

  /// Janela 24h (RF-20): sem estado ou `now - checkedAt >= 24h`.
  bool _shouldCheck(BundleArtifactState? state) =>
      state == null ||
      now().millisecondsSinceEpoch - state.checkedAtEpochMs >=
          _checkIntervalMs;

  /// Ciclo completo. Nunca lança — falha vira `ok: false` com motivo
  /// sanitizado e o cache/estado anteriores permanecem intactos.
  Future<BundleCheckResult> checkForUpdates({bool force = false}) async {
    final states = readStates();
    final due = <BundleKind>[];
    for (final kind in BundleKind.values) {
      if (force || _shouldCheck(states[kind.name])) due.add(kind);
    }
    if (due.isEmpty) {
      return const BundleCheckResult(ok: true, checked: [], applied: []);
    }

    // 1 manifest por ciclo (compartilhado pelos artifacts due).
    ParsedManifest? manifest;
    try {
      manifest = await _fetchManifest();
    } catch (e) {
      // Registro a tentativa mesmo sem estado anterior (inibe retry <24h).
      for (final kind in due) {
        await _writeState(kind, '', applied: false);
      }
      return BundleCheckResult(
          ok: false, reason: _sanitizedReason('manifest', e));
    }

    final digests = {
      BundleKind.catalog: manifestDigest(manifest.catalog),
      BundleKind.bible: manifestDigest(manifest.bible),
    };

    final checkedNames = <String>[];
    final appliedNames = <String>[];
    var failed = false;

    for (final kind in due) {
      checkedNames.add(kind.name);
      // RF-20: digest igual ao aplicado => atualiza só checkedAt, 0 ZIP.
      if (states[kind.name]?.manifestDigest == digests[kind]) {
        await _writeState(kind, digests[kind]!, applied: false);
        continue;
      }

      try {
        final zipBytes = await _fetchBundle(kind);
        final subset =
            kind == BundleKind.catalog ? manifest.catalog : manifest.bible;
        // ADR-10: validação completa em staging ANTES de qualquer commit.
        final staged = stageBundle(zipBytes, kind, subset);
        await store.commit(kind, staged);
        // Estado novo SÓ depois da aplicação atômica (RF-21/RED 7).
        await _writeState(kind, digests[kind]!, applied: true);
        appliedNames.add(kind.name);
      } catch (e) {
        failed = true;
        await _writeState(kind, '', applied: false);
        debugLog?.call('bundle-sync: ${kind.name} indisponível: '
            '${_sanitizedReason(kind.name, e)}');
      }
    }

    return failed
        ? BundleCheckResult(
            ok: false,
            checked: checkedNames,
            applied: appliedNames,
            reason: 'bundle-apply-failed',
          )
        : BundleCheckResult(ok: true, checked: checkedNames, applied: appliedNames);
  }

  Future<ParsedManifest> _fetchManifest() async {
    final response = await dio.get<List<int>>(
      manifestUrl,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/json'},
      ),
    );
    final body = utf8.decode(response.data!);
    final parsed = parseManifest(jsonDecode(body));
    if (parsed == null) {
      throw const BundleValidationException('manifest-invalid');
    }
    return parsed;
  }

  Future<Uint8List> _fetchBundle(BundleKind kind) async {
    final response = await dio.get<List<int>>(
      bundleUrl(kind),
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/zip'},
      ),
    );
    final contentType =
        (response.headers.value(Headers.contentTypeHeader) ?? '').toLowerCase();
    if (!contentType.contains('zip')) {
      throw const BundleValidationException('bundle-content-type');
    }
    return Uint8List.fromList(response.data!);
  }

  /// Motivo sanitizado: classe do erro + status; nunca corpo/token.
  String _sanitizedReason(String tag, Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status != null) return '$tag-http-$status';
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return '$tag-network';
      }
      return '$tag-transport';
    }
    if (error is BundleValidationException) return '$tag-${error.reason}';
    if (error is SocketException || error is HttpException) {
      return '$tag-network';
    }
    return '$tag-unknown';
  }
}
