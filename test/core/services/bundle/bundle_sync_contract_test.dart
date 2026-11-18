library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_sync_contract.dart';

/// Fixtures DERIVADAS DO PROBE REAL (2026-11-06, api.louvorja.com.br):
/// bytes verbatim dos ZIPs reais + entries verbatim do manifest real.
final _fixtureDir = Directory('test/fixtures/bundle');

dynamic _readJson(String name) =>
    jsonDecode(File('${_fixtureDir.path}/$name').readAsStringSync());

void main() {
  group('padrões de chave (ADR-09)', () {
    test('bible exige 3 segmentos (versão alfanumérica, livro e capítulo)', () {
      expect(isBibleKey('bible_10_100_1'), isTrue);
      expect(isBibleKey('bible_10_100_12'), isTrue);
      expect(isBibleKey('bible_acf_1_1'), isTrue);
      // 2 segmentos — bug latente do desktop #559, não pode repetir aqui.
      expect(isBibleKey('bible_10_100'), isFalse);
      expect(isBibleKey('bible_10_100_1_extra'), isFalse);
      expect(isBibleKey('bible_10_100_x'), isFalse);
    });

    test('catalog cobre índices, hinários, music_, album_ e config', () {
      expect(isCatalogKey('pt_categories'), isTrue);
      expect(isCatalogKey('pt_musics'), isTrue);
      expect(isCatalogKey('pt_hymnal'), isTrue);
      expect(isCatalogKey('pt_hymnal_1996'), isTrue);
      // pt_bible_book/pt_bible_version são ÍNDICES do subset catalog.
      expect(isCatalogKey('pt_bible_book'), isTrue);
      expect(isCatalogKey('pt_bible_version'), isTrue);
      expect(isCatalogKey('music_123'), isTrue);
      expect(isCatalogKey('album_1'), isTrue);
      expect(isCatalogKey('config'), isTrue);
      expect(isCatalogKey('bible_10_100_1'), isFalse);
      expect(isCatalogKey('unknown_thing'), isFalse);
    });
  });

  group('parseManifest (ADR-09) — RF-19 / RED 1', () {
    List<Map<String, dynamic>> realEntries() =>
        (_readJson('manifest_real_entries.json') as List)
            .cast<Map<String, dynamic>>();

    test('valida o array real do probe e particiona os subsets', () {
      final parsed = parseManifest(realEntries());
      expect(parsed, isNotNull);
      expect(
        parsed!.catalog.map((e) => e.file).toList(),
        unorderedEquals([
          'album_1.json',
          'config.json',
          'pt_categories.json',
          'pt_musics.json',
        ]),
      );
      expect(parsed.bible.map((e) => e.file), [
        'bible_10_100_1.json',
        'bible_10_100_2.json',
        'bible_10_100_3.json',
      ]);
    });

    test('entry fora dos padrões é IGNORADA sem invalidar (log sanitizado)', () {
      final entries = realEntries()
        ..add({
          'file': 'strange_table.json',
          'table': 'strange_table',
          'path': '/db/strange_table',
          'hash': '0a191817499d3db8c1bd89156996b7af',
        });
      final parsed = parseManifest(entries);
      expect(parsed, isNotNull);
      expect(parsed!.catalog.length, 4);
      expect(parsed.bible.length, 3);
    });

    test('manifest não-array / vazio → null (sync aborta, 0 ZIP)', () {
      expect(parseManifest(<String, dynamic>{}), isNull);
      expect(parseManifest(<dynamic>[]), isNull);
      expect(parseManifest('nope'), isNull);
      expect(parseManifest(null), isNull);
    });

    test('hash não-MD5 em UMA entry invalida o manifest INTEIRO', () {
      for (final bad in ['XYZ', '0A191817499D3DB8C1BD89156996B7AF', 'z']) {
        final entries = realEntries()..first['hash'] = bad;
        expect(parseManifest(entries), isNull, reason: 'hash=$bad');
      }
    });

    test('file duplicado invalida o manifest inteiro', () {
      final entries = realEntries()..add(Map.of(realEntries().first));
      expect(parseManifest(entries), isNull);
    });

    test('file inseguro (/, .., \\, controle, sem .json) invalida', () {
      for (final bad in [
        '../evil.json',
        'a/b.json',
        'a\\b.json',
        'a\x00b.json',
        'sem_extensao',
      ]) {
        final entries = realEntries()..first['file'] = bad;
        expect(parseManifest(entries), isNull, reason: 'file=$bad');
      }
    });

    test('tipos errados (table/path não-string) invalidam', () {
      final entries = realEntries()..first['table'] = 42;
      expect(parseManifest(entries), isNull);
      final entries2 = realEntries()..first['path'] = null;
      expect(parseManifest(entries2), isNull);
    });
  });

  group('manifestDigest (ADR-09) — serialização canônica', () {
    test('golden vs implementação independente (Python) do probe real', () {
      final parsed = parseManifest(
        (_readJson('manifest_real_entries.json') as List)
            .cast<Map<String, dynamic>>(),
      )!;
      final goldenCatalog = File(
        '${_fixtureDir.path}/golden_catalog_digest.txt',
      ).readAsStringSync().trim();
      final goldenBible = File(
        '${_fixtureDir.path}/golden_bible_digest.txt',
      ).readAsStringSync().trim();

      expect(manifestDigest(parsed.catalog), goldenCatalog);
      expect(manifestDigest(parsed.bible), goldenBible);
    });

    test('serialização canônica: linhas "file\\tmd5\\n" ordenadas byte-a-byte', () {
      final canon = File(
        '${_fixtureDir.path}/canonical_catalog.txt',
      ).readAsStringSync();
      final parsed = parseManifest(
        (_readJson('manifest_real_entries.json') as List)
            .cast<Map<String, dynamic>>(),
      )!;
      expect(canonicalManifestSerialization(parsed.catalog), canon);
      // Ordenação independente da ordem de entrada.
      final shuffled = [...parsed.catalog.reversed];
      expect(
        canonicalManifestSerialization(shuffled),
        canonicalManifestSerialization(parsed.catalog),
      );
    });

    test('UM hash divergente muda o digest (gate condicional)', () {
      final parsed = parseManifest(
        (_readJson('manifest_real_entries.json') as List)
            .cast<Map<String, dynamic>>(),
      )!;
      final before = manifestDigest(parsed.catalog);
      parsed.catalog.first = ManifestEntry(
        file: parsed.catalog.first.file,
        hash: '115b3ef31c499af129e3de5a55e56270',
      );
      expect(manifestDigest(parsed.catalog), isNot(before));
    });
  });

  group('BundleArtifactState (schema 2)', () {
    test('serializa/desserializa e valida digest 64-hex (ou vazio = falha)', () {
      final state = BundleArtifactState(
        artifact: BundleKind.catalog,
        manifestDigest: 'a' * 64,
        checkedAtEpochMs: 123,
        appliedAtEpochMs: 456,
      );
      final decoded = BundleArtifactState.fromJson(
        state.artifact,
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, state);
      expect(decoded!.schema, 2);

      // digest vazio = tentativa com falha (válido p/ inibir retry <24h).
      final failed = BundleArtifactState(
        artifact: BundleKind.catalog,
        manifestDigest: '',
        checkedAtEpochMs: 1,
        appliedAtEpochMs: 0,
      );
      expect(
        BundleArtifactState.fromJson(
          BundleKind.catalog,
          jsonDecode(jsonEncode(failed.toJson())) as Map<String, dynamic>,
        ),
        failed,
      );

      expect(
        BundleArtifactState.fromJson(
          BundleKind.catalog,
          jsonDecode(
            jsonEncode({
              'schema': 1,
              'artifact': 'catalog',
              'manifestDigest': 'a' * 64,
              'checkedAtEpochMs': 1,
              'appliedAtEpochMs': 1,
            }),
          ) as Map<String, dynamic>,
        ),
        isNull, // schema 1 legado: incompatível
      );
      expect(
        BundleArtifactState.fromJson(
          BundleKind.catalog,
          jsonDecode(
            jsonEncode({
              'schema': 2,
              'artifact': 'catalog',
              'manifestDigest': 'zz',
              'checkedAtEpochMs': 1,
              'appliedAtEpochMs': 1,
            }),
          ) as Map<String, dynamic>,
        ),
        isNull,
      );
    });
  });
}
