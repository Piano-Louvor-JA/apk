library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_sync_contract.dart';

/// Utilidades de fixture para os testes de bundle — DERIVADAS DO PROBE REAL
/// (2026-11-06, api.louvorja.com.br): bytes verbatim dos ZIPs reais +
/// entries verbatim do manifest real (nada sintético do envelope antigo).
final fixtureDir = Directory('test/fixtures/bundle');

dynamic readFixtureJson(String name) =>
    jsonDecode(File('${fixtureDir.path}/$name').readAsStringSync());

Uint8List readFixtureBytes(String name) =>
    File('${fixtureDir.path}/$name').readAsBytesSync();

List<Map<String, dynamic>> realManifestEntries() =>
    (readFixtureJson('manifest_real_entries.json') as List)
        .cast<Map<String, dynamic>>();

List<ManifestEntry> catalogSubset() =>
    parseManifest(realManifestEntries())!.catalog;

List<ManifestEntry> bibleSubset() =>
    parseManifest(realManifestEntries())!.bible;

/// Monta um ZIP no formato real do contrato: arquivos reais do probe +
/// `_bundle_manifest.json` {schema_version:1, kind, files:[{name,bytes,sha256}]
/// com as entries `files[]` REAIS do ZIP upstream (sha256 conferidos).
Uint8List buildBundleZip(
  BundleKind kind,
  List<String> names, {
  Map<String, List<int>> overrideFiles = const {},
  Map<String, Map<String, dynamic>> overrideManifestEntries = const {},
  bool omitManifest = false,
  int schemaVersion = 1,
}) {
  final encoder = ZipEncoder();
  final archive = Archive();
  final filesMeta = readFixtureJson(
    kind == BundleKind.catalog
        ? 'bundle_manifest_files_catalog.json'
        : 'bundle_manifest_files_bible.json',
  ) as List;

  for (final name in names) {
    final bytes = overrideFiles[name] ?? readFixtureBytes('real_$name');
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  if (!omitManifest) {
    final files = [
      for (final f in filesMeta.cast<Map<String, dynamic>>())
        if (names.contains(f['name']))
          overrideManifestEntries[f['name']] ?? f,
    ];
    final manifestBytes = utf8.encode(
      jsonEncode({
        'schema_version': schemaVersion,
        'kind': kind.name,
        'files': files,
      }),
    );
    archive.addFile(
      ArchiveFile('_bundle_manifest.json', manifestBytes.length, manifestBytes),
    );
  }
  return Uint8List.fromList(encoder.encode(archive));
}
