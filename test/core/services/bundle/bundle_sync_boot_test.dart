library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_sync_boot.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_snapshot_store.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_sync_client.dart';

void main() {
  test('flushOnBoot nunca lança (sem rede) e registra a tentativa (ADR-03)',
      () async {
    final dir = Directory.systemTemp.createTempSync('bundle_boot');
    addTearDown(() => dir.deleteSync(recursive: true));

    await BundleSyncBoot.flushOnBoot(
      dir,
      clientFactory: () => _networkDownClient(dir),
    );
    // Estrutura criada mesmo sem rede: próximo boot serve o snapshot local.
    expect(Directory('${dir.path}/bundle').existsSync(), isTrue);
    final stateFile = File('${dir.path}/bundle/bundle_sync_state.json');
    expect(stateFile.existsSync(), isTrue,
        reason: 'tentativa registrada inibe retry <24h (ADR-03)');
    final raw =
        jsonDecode(stateFile.readAsStringSync()) as Map<String, dynamic>;
    expect(raw['catalog']['manifestDigest'], '');
    expect(raw['bible']['manifestDigest'], '');
  });

  test('flushOnBoot com client que lança não propaga e não corrompe storage',
      () async {
    final dir = Directory.systemTemp.createTempSync('bundle_boot_throw');
    addTearDown(() => dir.deleteSync(recursive: true));

    await BundleSyncBoot.flushOnBoot(
      dir,
      clientFactory: () => _ThrowingClient(),
    );
    expect(Directory('${dir.path}/bundle').existsSync(), isTrue);
  });

  test('flushOnBoot com rede OK aplica bundles e persiste estado', () async {
    final dir = Directory.systemTemp.createTempSync('bundle_boot_ok');
    addTearDown(() => dir.deleteSync(recursive: true));

    var called = false;
    // Fake que grava o estado como o client real faria após aplicar.
    final bundleDir = Directory('${dir.path}/bundle')
      ..createSync(recursive: true);
    final stateFile = File('${bundleDir.path}/bundle_sync_state.json');
    await BundleSyncBoot.flushOnBoot(
      dir,
      clientFactory: () => _OkClient(() async {
        called = true;
        await stateFile.writeAsString(jsonEncode({
          'version': 1,
          'catalog': {
            'schema': 2,
            'artifact': 'catalog',
            'manifestDigest': 'a' * 64,
            'checkedAtEpochMs': 1,
            'appliedAtEpochMs': 1,
          },
          'bible': {
            'schema': 2,
            'artifact': 'bible',
            'manifestDigest': 'b' * 64,
            'checkedAtEpochMs': 1,
            'appliedAtEpochMs': 1,
          },
        }));
      }),
    );
    expect(called, isTrue);
    final raw = jsonDecode(stateFile.readAsStringSync()) as Map<String, dynamic>;
    expect(raw['catalog'], isNotNull);
    expect(raw['bible'], isNotNull);
  });
}

/// Cliente real (Dio) apontando pra host morto — falha de rede autêntica,
/// registra o estado de tentativa pelo caminho normal do client.
BundleSyncClient _networkDownClient(Directory dir) {
  final bundleDir = Directory('${dir.path}/bundle')..createSync(recursive: true);
  return BundleSyncClient(
    dio: Dio(BaseOptions(
      connectTimeout: const Duration(milliseconds: 50),
      receiveTimeout: const Duration(milliseconds: 50),
    )),
    origin: 'https://bundles.invalid.test',
    store: BundleSnapshotStore(bundleDir),
    stateFile: File('${bundleDir.path}/bundle_sync_state.json'),
  );
}

class _ThrowingClient implements BundleSyncClientBase {
  @override
  Future<BundleCheckResult> checkForUpdates({bool force = false}) async {
    throw const FileSystemException('boom sanitizado');
  }
}

class _OkClient implements BundleSyncClientBase {
  final Future<void> Function() onCheck;
  _OkClient(this.onCheck);

  @override
  Future<BundleCheckResult> checkForUpdates({bool force = false}) async {
    await onCheck();
    return const BundleCheckResult(
      ok: true,
      checked: ['catalog', 'bible'],
      applied: ['catalog', 'bible'],
    );
  }
}
