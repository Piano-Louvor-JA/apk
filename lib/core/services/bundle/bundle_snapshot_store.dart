library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

import 'package:louvorja_piano_mobile/core/services/bundle/bundle_sync_contract.dart';

/// Falha de validação do bundle (ADR-10). Nada foi aplicado.
class BundleValidationException implements Exception {
  final String reason;
  const BundleValidationException(this.reason);

  @override
  String toString() => 'BundleValidationException: $reason';
}

/// Storage de snapshots por artifact com commit ATÔMICO por rename.
///
/// Layout no diretório base:
/// - `bundle_<kind>.staging/` — diretório temporário em construção;
/// - `bundle_<kind>/` — namespace definitivo do artifact (um JSON por chave);
/// - `bundle_bundle.json` — snapshot legado (não usado; tolerado).
///
/// "O bundle substitui o namespace do artifact (não merge)": o commit move o
/// staging pronto por cima do namespace anterior num único rename — o leitor
/// vê a versão anterior OU a nova, nunca um estado parcial (RED 7). O estado
/// (`manifestDigest`) é gravado pelo client SOMENTE depois do commit.
class BundleSnapshotStore {
  /// Um ZIP de bible com 15k capítulos expande p/ ~100MB de JSON — o snapshot
  /// compacto em um único arquivo mantém o commit atômico barato.
  static const _snapshotFile = 'bundle_snapshot.json';

  final Directory? baseDir;
  final bool isNoop;

  BundleSnapshotStore(Directory dir) : baseDir = dir, isNoop = false;

  const BundleSnapshotStore.noop() : baseDir = null, isNoop = true;

  Directory? _namespaceDir(BundleKind kind) {
    final dir = baseDir;
    if (dir == null) return null;
    return Directory('${dir.path}/bundle_${kind.name}');
  }

  File? _snapshotFileFor(BundleKind kind) => baseDir == null
      ? null
      : File('${_namespaceDir(kind)!.path}/$_snapshotFile');

  /// Lê o valor parseado de uma chave do snapshot aplicado (offline-first).
  /// Null quando o snapshot não existe, está corrompido ou a chave falta —
  /// o chamador cai no fluxo legado (RF-06).
  dynamic readJson(BundleKind kind, String key) {
    if (isNoop) return null;
    final file = _snapshotFileFor(kind);
    if (file == null || !file.existsSync()) return null;
    try {
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map<String, dynamic>) return null;
      final value = raw[key];
      return value is String ? jsonDecode(value) : null;
    } catch (_) {
      return null; // snapshot corrompido nunca quebra a leitura
    }
  }

  /// Chaves presentes no snapshot aplicado (telemetria/QA).
  List<String> keys(BundleKind kind) {
    if (isNoop) return const [];
    final file = _snapshotFileFor(kind);
    if (file == null || !file.existsSync()) return const [];
    try {
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map<String, dynamic>) return const [];
      return raw.keys.toList();
    } catch (_) {
      return const [];
    }
  }

  /// Commit único por artifact: grava o snapshot num arquivo temporário no
  /// MESMO diretório (mesma partição = rename atômico) e renomeia por cima.
  Future<void> commit(BundleKind kind, Map<String, String> snapshot) async {
    if (isNoop) return;
    final dir = _namespaceDir(kind);
    if (dir == null) return;
    dir.createSync(recursive: true);
    final target = _snapshotFileFor(kind)!;
    final tmp = File('${dir.path}/$_snapshotFile.tmp');
    await tmp.writeAsString(jsonEncode(snapshot), flush: true);
    tmp.renameSync(target.path);
  }

  /// Staging para validação pré-commit (ADR-10): grava num diretório
  /// temporário distinto; o commit só acontece com o ZIP 100% válido.
  @visibleForTesting
  Directory stagingDir(BundleKind kind) {
    final base = baseDir!;
    final dir = Directory('${base.path}/bundle_${kind.name}.staging');
    dir.createSync(recursive: true);
    return dir;
  }
}

/// ADR-10 — valida o ZIP em staging ANTES de qualquer commit:
/// 1. estrutura segura (sem caminho absoluto, `..`, `\`; entradas .json);
/// 2. `_bundle_manifest.json` com `schema_version === 1` e `kind` do artifact;
/// 3. completude: todo entry do subset do manifest presente no ZIP;
/// 4. congruência entry-wise: MD5 dos bytes extraídos === hash do manifest
///    (UM arquivo divergente invalida o bundle INTERO — nada parcial);
/// 4b. reforço: SHA-256 interno de `files[]` conferido quando disponível;
/// 5. essenciais: catalog exige `pt_categories`/`pt_musics`/`config`;
///    bible exige ao menos 1 capítulo;
/// 6. arquivos fora do padrão do artifact são ignorados.
///
/// Retorna o snapshot validado (chave → JSON texto) pronto para commit.
Map<String, String> stageBundle(
  Uint8List zipBytes,
  BundleKind kind,
  List<ManifestEntry> subset,
) {
  final archive = _decodeZip(zipBytes);

  for (final file in archive.files) {
    final name = file.name;
    if (name.startsWith('/') || name.contains('..') || name.contains(r'\')) {
      throw const BundleValidationException('bundle-path-forbidden');
    }
  }

  final manifestRaw = archive.findFile('_bundle_manifest.json');
  if (manifestRaw == null) {
    throw const BundleValidationException('bundle-manifest-missing');
  }
  Map<String, dynamic> bundleManifest;
  try {
    final decoded = jsonDecode(utf8.decode(manifestRaw.content as List<int>));
    if (decoded is! Map<String, dynamic>) {
      throw const BundleValidationException('bundle-manifest-invalid');
    }
    bundleManifest = decoded;
  } on FormatException {
    throw const BundleValidationException('bundle-manifest-invalid');
  }
  if (bundleManifest['schema_version'] != 1) {
    throw const BundleValidationException('bundle-manifest-schema');
  }
  if (bundleManifest['kind'] != kind.name) {
    throw const BundleValidationException('bundle-manifest-kind');
  }

  // sha256 interno por arquivo (reforço, não substituto do MD5 externo).
  final internalSha = <String, String>{};
  final filesField = bundleManifest['files'];
  if (filesField is List) {
    for (final f in filesField) {
      if (f is Map<String, dynamic> &&
          f['name'] is String &&
          f['sha256'] is String) {
        internalSha[f['name'] as String] = f['sha256'] as String;
      }
    }
  }

  final expected = {for (final e in subset) e.file: e.hash};
  final staged = <String, String>{};

  for (final file in archive.files) {
    final name = file.name;
    if (name == '_bundle_manifest.json') continue;
    if (!name.endsWith('.json')) {
      continue; // fora do padrão: ignorado (item 6)
    }
    final bytes = file.content as List<int>;
    if (expected.containsKey(name)) {
      // Congruência entry-wise (item 4) — MD5 dos bytes vs manifest externo.
      final md5Hex = crypto.md5.convert(bytes).toString();
      if (md5Hex != expected[name]) {
        throw const BundleValidationException('bundle-entry-md5-mismatch');
      }
      // Reforço: sha256 do _bundle_manifest interno, quando presente.
      final sha = internalSha[name];
      if (sha != null &&
          crypto.sha256.convert(bytes).toString() != sha) {
        throw const BundleValidationException('bundle-entry-sha256-mismatch');
      }
      final text = utf8.decode(bytes);
      // JSON inválido invalida o bundle inteiro (RED 6).
      try {
        jsonDecode(text);
      } on FormatException {
        throw const BundleValidationException('bundle-json-invalid');
      }
      final key = name.substring(0, name.length - 5);
      if (staged.containsKey(key)) {
        throw const BundleValidationException('bundle-key-duplicate');
      }
      staged[key] = text;
    }
  }

  // Completude subset ⊆ ZIP (item 3).
  if (staged.length < expected.length) {
    throw const BundleValidationException('bundle-incomplete');
  }

  // Essenciais (item 5).
  if (kind == BundleKind.catalog) {
    for (final essential in ['pt_categories', 'pt_musics', 'config']) {
      if (!staged.containsKey(essential)) {
        throw BundleValidationException(
            'bundle-essential-missing:$essential');
      }
    }
  } else if (!staged.keys.any(isBibleKey)) {
    throw const BundleValidationException('bundle-essential-missing:chapter');
  }

  return staged;
}

Archive _decodeZip(Uint8List bytes) {
  try {
    return ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const BundleValidationException('bundle-zip-corrupt');
  }
}
