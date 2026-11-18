library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_snapshot_store.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_sync_contract.dart';

final _fixtureDir = Directory('test/fixtures/bundle');
Uint8List _fixtureBytes(String name) =>
    File('${_fixtureDir.path}/$name').readAsBytesSync();

List<ManifestEntry> _catalogEntries() => parseManifest(
  (_readJsonFile('manifest_real_entries.json') as List)
      .cast<Map<String, dynamic>>(),
)!.catalog;

List<ManifestEntry> _bibleEntries() => parseManifest(
  (_readJsonFile('manifest_real_entries.json') as List)
      .cast<Map<String, dynamic>>(),
)!.bible;

dynamic _readJsonFile(String name) =>
    jsonDecode(File('${_fixtureDir.path}/$name').readAsStringSync());

/// Monta um ZIP no formato do contrato: arquivos reais do probe +
/// _bundle_manifest.json {schema_version:1, kind, files:[{name,bytes,sha256}]}.
Uint8List buildBundleZip(
  BundleKind kind,
  List<String> names, {
  Map<String, List<int>> overrideFiles = const {},
  Map<String, Map<String, dynamic>> overrideManifestEntries = const {},
  bool omitManifest = false,
}) {
  final encoder = ZipEncoder();
  final archive = Archive();
  final meta = _readJsonFile(
    kind == BundleKind.catalog
        ? 'bundle_manifest_files_catalog.json'
        : 'bundle_manifest_files_bible.json',
  ) as List;

  void addFile(String name, List<int> bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  for (final name in names) {
    final bytes = overrideFiles[name] ?? _fixtureBytes('real_$name');
    addFile(name, bytes);
  }
  if (!omitManifest) {
    final entryList = [
      for (final f in meta.cast<Map<String, dynamic>>())
        if (names.contains(f['name']))
          overrideManifestEntries[f['name']] ?? f,
    ];
    final manifest = jsonEncode({
      'schema_version': 1,
      'kind': kind.name,
      'files': entryList,
    });
    addFile('_bundle_manifest.json', utf8.encode(manifest));
  }
  return Uint8List.fromList(encoder.encode(archive));
}

void main() {
  late Directory tmp;
  late BundleSnapshotStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bundle_store_test');
    store = BundleSnapshotStore(tmp);
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  group('store: atomicidade por rename', () {
    test('commit único por artifact — read vê tudo ou nada', () async {
      final snapshot = {'config': '{"a":1}', 'album_1': '{"b":2}'};
      await store.commit(BundleKind.catalog, snapshot);
      expect(store.readJson(BundleKind.catalog, 'config'), {'a': 1});
      expect(store.readJson(BundleKind.catalog, 'album_1'), {'b': 2});
    });

    test('commit substitui o namespace do artifact (não merge)', () async {
      await store.commit(BundleKind.catalog, {'config': '{"v":1}'});
      await store.commit(BundleKind.catalog, {'pt_categories': '[]'});
      expect(store.readJson(BundleKind.catalog, 'config'), isNull);
      expect(store.readJson(BundleKind.catalog, 'pt_categories'), []);
    });

    test('crash antes do commit preserva a versão anterior (RED 7)', () async {
      await store.commit(BundleKind.catalog, {'config': '{"v":1}'});
      // simula crash: escreve temp e NÃO commita
      final staging = Directory('${tmp.path}/bundle_catalog.staging');
      staging.createSync(recursive: true);
      File('${staging.path}/part.json').writeAsStringSync('{"partial":true}');
      expect(store.readJson(BundleKind.catalog, 'config'), {'v': 1});
    });

    test('readJson tolera snapshot ausente/corrompido (offline-first)', () {
      expect(store.readJson(BundleKind.bible, 'bible_10_100_1'), isNull);
      File(
        '${tmp.path}/bundle_bundle.json',
      ).writeAsStringSync('não é json {');
      expect(store.readJson(BundleKind.bible, 'any'), isNull);
    });
  });

  group('stageBundle (ADR-10) — RF-21 / RED 3,4,5,6', () {
    test('ZIP real-formato válido: valida MD5 entry-wise e essenciais',
        () async {
      final zip = buildBundleZip(BundleKind.catalog, [
        'config.json',
        'pt_categories.json',
        'pt_musics.json',
        'album_1.json',
      ]);
      final staged = stageBundle(zip, BundleKind.catalog, _catalogEntries());
      expect(staged.keys, containsAll(['config', 'pt_categories', 'pt_musics', 'album_1']));
    });

    test('UM arquivo com MD5 divergente invalida o bundle INTERO (RED 3)', () async {
      final zip = buildBundleZip(
        BundleKind.catalog,
        ['config.json', 'pt_categories.json', 'pt_musics.json', 'album_1.json'],
        overrideFiles: {
          'config.json': utf8.encode('{"tampered":true}'),
        },
      );
      expect(
        () => stageBundle(zip, BundleKind.catalog, _catalogEntries()),
        throwsA(isA<BundleValidationException>()),
      );
    });

    test('entry do subset AUSENTE no ZIP invalida (RED 4 — incompleto)', () async {
      final zip = buildBundleZip(BundleKind.catalog, [
        'config.json',
        'pt_categories.json',
        'pt_musics.json',
        // album_1.json ausente
      ]);
      expect(
        () => stageBundle(zip, BundleKind.catalog, _catalogEntries()),
        throwsA(isA<BundleValidationException>()),
      );
    });

    test('_bundle_manifest com kind errado ou schema_version != 1 invalida (RED 5)',
        () async {
      final badKind = buildBundleZip(BundleKind.bible, [
        'bible_10_100_1.json',
        'bible_10_100_2.json',
        'bible_10_100_3.json',
      ]);
      expect(
        () => stageBundle(badKind, BundleKind.catalog, _catalogEntries()),
        throwsA(isA<BundleValidationException>()),
      );

      final names = [
        'config.json',
        'pt_categories.json',
        'pt_musics.json',
        'album_1.json',
      ];
      final badSchema = buildBundleZip(
        BundleKind.catalog,
        names,
        overrideManifestEntries: const {},
      );
      // schema_version é injetado no helper; valida via manifesto alterado:
      final encoder = ZipEncoder();
      final archive = Archive();
      for (final n in names) {
        final b = _fixtureBytes('real_$n');
        archive.addFile(ArchiveFile(n, b.length, b));
      }
      archive.addFile(
        ArchiveFile(
          '_bundle_manifest.json',
          2,
          utf8.encode(jsonEncode({'schema_version': 99, 'kind': 'catalog'})),
        ),
      );
      expect(
        () => stageBundle(
          Uint8List.fromList(encoder.encode(archive)),
          BundleKind.catalog,
          _catalogEntries(),
        ),
        throwsA(isA<BundleValidationException>()),
      );
      expect(badSchema, isNotNull);
    });

    test('_bundle_manifest AUSENTE invalida', () async {
      final zip = buildBundleZip(
        BundleKind.catalog,
        ['config.json', 'pt_categories.json', 'pt_musics.json', 'album_1.json'],
        omitManifest: true,
      );
      expect(
        () => stageBundle(zip, BundleKind.catalog, _catalogEntries()),
        throwsA(isA<BundleValidationException>()),
      );
    });

    test('ZIP com caminho inseguro ou entrada não-JSON invalida (RED 6)', () async {
      final encoder = ZipEncoder();
      final archive = Archive()
        ..addFile(ArchiveFile('../evil.json', 2, utf8.encode('{}')));
      final unsafe = Uint8List.fromList(encoder.encode(archive));
      expect(
        () => stageBundle(unsafe, BundleKind.catalog, _catalogEntries()),
        throwsA(isA<BundleValidationException>()),
      );

      final archive2 = Archive()
        ..addFile(ArchiveFile('data.bin', 3, utf8.encode('abc')));
      final notJson = Uint8List.fromList(encoder.encode(archive2));
      expect(
        () => stageBundle(notJson, BundleKind.catalog, _catalogEntries()),
        throwsA(isA<BundleValidationException>()),
      );
    });

    test('ZIP truncado/corrompido invalida (RED 6)', () async {
      final zip = buildBundleZip(BundleKind.catalog, [
        'config.json',
        'pt_categories.json',
        'pt_musics.json',
        'album_1.json',
      ]);
      final truncated = Uint8List.sublistView(zip, 0, zip.length ~/ 3);
      expect(
        () => stageBundle(truncated, BundleKind.catalog, _catalogEntries()),
        throwsA(isA<BundleValidationException>()),
      );
    });

    test('essenciais do catalog ausentes invalidam (config/pt_categories/pt_musics)',
        () async {
      // só album_1 — sem essenciais
      final entriesWithoutEssentials = _catalogEntries()
          .where((e) => e.file == 'album_1.json')
          .toList();
      final zip = buildBundleZip(BundleKind.catalog, ['album_1.json']);
      expect(
        () => stageBundle(zip, BundleKind.catalog, entriesWithoutEssentials),
        throwsA(isA<BundleValidationException>()),
      );
    });

    test('bible válido: 3 capítulos reais; es_musics (fora do padrão) é ignorado',
        () async {
      final zip = buildBundleZip(
        BundleKind.bible,
        ['bible_10_100_1.json', 'bible_10_100_2.json', 'bible_10_100_3.json'],
      );
      final staged = stageBundle(zip, BundleKind.bible, _bibleEntries());
      expect(staged.length, 3);
      expect(jsonDecode(staged['bible_10_100_1']!), isA<Map<String, dynamic>>());
    });

    test('sha256 interno dos files[] é conferido (reforço ADR-10 item 6)', () async {
      final names = [
        'config.json',
        'pt_categories.json',
        'pt_musics.json',
        'album_1.json',
      ];
      final filesMeta = (_readJsonFile(
        'bundle_manifest_files_catalog.json',
      ) as List).cast<Map<String, dynamic>>();
      final tamperedSha = {
        for (final f in filesMeta)
          f['name'] as String: {...f, 'sha256': 'f' * 64},
      };
      final zip = buildBundleZip(
        BundleKind.catalog,
        names,
        overrideManifestEntries: tamperedSha,
      );
      expect(
        () => stageBundle(zip, BundleKind.catalog, _catalogEntries()),
        throwsA(isA<BundleValidationException>()),
      );
    });
  });
}
