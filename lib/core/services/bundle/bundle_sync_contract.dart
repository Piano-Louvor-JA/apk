library;

import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// Contrato bundle-first — SPEC piano-bundle-sync v1.2.0 (ADR-09/10/11).
///
/// Contrato real do upstream (probe 2026-11-06, api.louvorja.com.br):
/// - `GET {bundles-origin}/db/manifest` → 200, JSON **array** de entries
///   `{file, table, path, hash}` — `hash` = MD5 32-hex lowercase dos bytes
///   do arquivo. NÃO existe envelope `{schema, artifacts}` nem MD5 do ZIP.
/// - `path` é INFORMATIVO (auditoria): o cliente NUNCA faz GET de `path`
///   nem constrói URL a partir de campos do payload. As únicas URLs são as
///   fixas `/db/manifest`, `/db/catalog-bundle`, `/db/bible-bundle`
///   concatenadas à origem configurada (ADR-09/ADR-11).
enum BundleKind { catalog, bible }

/// Entry válida do manifest (subset já particionado por padrão de chave).
class ManifestEntry {
  final String file;
  final String hash;

  const ManifestEntry({required this.file, required this.hash});

  /// Chave de storage = nome do arquivo sem `.json` (ex: `album_1`).
  String get key => file.endsWith('.json') ? file.substring(0, file.length - 5) : file;
}

/// Manifest validado, particionado por artifact.
class ParsedManifest {
  final List<ManifestEntry> catalog;
  final List<ManifestEntry> bible;

  const ParsedManifest({required this.catalog, required this.bible});
}

/// Estado persistido por artifact (schema 2 — ADR-09).
class BundleArtifactState {
  static const int schemaVersion = 2;

  final BundleKind artifact;
  /// SHA-256 da serialização canônica do subset aplicado. `''` = tentativa
  /// com falha (válida apenas para inibir retry automático <24h).
  final String manifestDigest;
  final int checkedAtEpochMs;
  final int appliedAtEpochMs;

  const BundleArtifactState({
    required this.artifact,
    required this.manifestDigest,
    required this.checkedAtEpochMs,
    required this.appliedAtEpochMs,
  });

  int get schema => schemaVersion;

  @override
  bool operator ==(Object other) =>
      other is BundleArtifactState &&
      other.artifact == artifact &&
      other.manifestDigest == manifestDigest &&
      other.checkedAtEpochMs == checkedAtEpochMs &&
      other.appliedAtEpochMs == appliedAtEpochMs;

  @override
  int get hashCode =>
      Object.hash(artifact, manifestDigest, checkedAtEpochMs, appliedAtEpochMs);

  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        'artifact': artifact.name,
        'manifestDigest': manifestDigest,
        'checkedAtEpochMs': checkedAtEpochMs,
        'appliedAtEpochMs': appliedAtEpochMs,
      };

  /// Decodifica com validação estrita; null quando incompatível/corrompido.
  static BundleArtifactState? fromJson(
      BundleKind artifact, Map<String, dynamic>? json) {
    if (json == null) return null;
    if (json['schema'] != schemaVersion) return null;
    if (json['artifact'] != artifact.name) return null;
    final digest = json['manifestDigest'];
    final checked = json['checkedAtEpochMs'];
    final applied = json['appliedAtEpochMs'];
    if (digest is! String) return null;
    if (digest.isNotEmpty && !_sha256Pattern.hasMatch(digest)) return null;
    if (checked is! int || applied is! int) return null;
    return BundleArtifactState(
      artifact: artifact,
      manifestDigest: digest,
      checkedAtEpochMs: checked,
      appliedAtEpochMs: applied,
    );
  }
}

final RegExp _md5Pattern = RegExp(r'^[a-f0-9]{32}$');
final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
final RegExp _controlChars = RegExp(r'[\x00-\x1f]');

/// Subset bible: `^bible_[a-z0-9]+_\d+_\d+$` — versão alfanumérica,
/// livro e capítulo numéricos (3 segmentos; chaves de 2 segmentos não casam).
bool isBibleKey(String key) => _bibleKeyPattern.hasMatch(key);
final _bibleKeyPattern = RegExp(r'^bible_[a-z0-9]+_\d+_\d+$');

/// Subset catalog: índices pt/es, hinários, `music_<id>`, `album_<id>`,
/// `config`. `pt_bible_book`/`pt_bible_version` são ÍNDICES (subset catalog).
bool isCatalogKey(String key) => _catalogKeyPattern.hasMatch(key);
final _catalogKeyPattern = RegExp(
  r'^(?:pt|es)_(?:categories|musics|hymnal|hymnal_\d+|bible_book|bible_version)$'
  r'|^music_\d+$'
  r'|^album_\d+$'
  r'|^config$',
);

bool _isSafeJsonName(String file) =>
    file.endsWith('.json') &&
    !file.contains('/') &&
    !file.contains('..') &&
    !file.contains(r'\') &&
    !_controlChars.hasMatch(file);

/// ADR-09: valida o array entry-wise INTEIRO. Uma única violação (entry
/// inválida, hash não-MD5, `file` duplicado/inseguro) invalida o manifest
/// completo → sync aborta, cache mantido, 0 GET de ZIP (RF-19).
///
/// Entradas fora dos padrões catalog/bible são IGNORADAS (log sanitizado),
/// sem fail. `table`/`path` são conferidos por tipo apenas — nunca viram URL.
ParsedManifest? parseManifest(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;
  final catalog = <ManifestEntry>[];
  final bible = <ManifestEntry>[];
  final seen = <String>{};

  for (final entry in raw) {
    if (entry is! Map) return null;
    final file = entry['file'];
    final hash = entry['hash'];
    final table = entry['table'];
    final path = entry['path'];
    if (file is! String || hash is! String) return null;
    if (table is! String || path is! String) return null;
    if (!_isSafeJsonName(file)) return null;
    if (!_md5Pattern.hasMatch(hash)) return null;
    if (seen.contains(file)) return null;
    seen.add(file);

    final key = file.substring(0, file.length - 5);
    final parsed = ManifestEntry(file: file, hash: hash);
    if (isCatalogKey(key)) {
      catalog.add(parsed);
    } else if (isBibleKey(key)) {
      bible.add(parsed);
    }
    // fora dos padrões: ignorada sem falha
  }

  if (catalog.isEmpty || bible.isEmpty) return null;
  return ParsedManifest(catalog: catalog, bible: bible);
}

/// Serialização canônica do subset: linhas `file\tmd5\n` ordenadas
/// byte-a-byte (UTF-8) por `file` — paridade literal com web/desktop.
String canonicalManifestSerialization(List<ManifestEntry> entries) {
  final sorted = [...entries]..sort((a, b) => a.file.compareTo(b.file));
  return sorted.map((e) => '${e.file}\t${e.hash}\n').join();
}

/// `manifestDigest` = SHA-256 (hex lowercase) da serialização canônica.
/// Qualquer mudança em UM hash/entrada muda o digest (gate condicional).
String manifestDigest(List<ManifestEntry> entries) =>
    crypto.sha256.convert(utf8.encode(canonicalManifestSerialization(entries)))
        .toString();
