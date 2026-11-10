library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:louvorja_piano_mobile/core/services/bundle/bundle_snapshot_store.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_sync_client.dart';

/// Boot do bundle-first (paridade com OperatorStateBoot do apk#107):
/// dispara o sync no boot SEM travar a UI — flush `unawaited`, qualquer
/// erro é engolido com log sanitizado (telemetria nunca recebe corpo).
class BundleSyncBoot {
  /// Executa o ciclo (respeitando a janela de 24h) contra a origem bundles
  /// configurada. Storage em `<base>/bundle/`.
  ///
  /// Nunca lança — sem rede o app continua offline-first no snapshot local.
  static Future<void> flushOnBoot(
    Directory baseDir, {
    BundleSyncClientBase Function()? clientFactory,
  }) async {
    try {
      final bundleDir = Directory('${baseDir.path}/bundle')
        ..createSync(recursive: true);
      final store = BundleSnapshotStore(bundleDir);
      final stateFile = File('${bundleDir.path}/bundle_sync_state.json');

      final client = clientFactory != null
          ? clientFactory()
          : BundleSyncClient(
              dio: Dio(),
              origin: _resolveOrigin(),
              store: store,
              stateFile: stateFile,
              debugLog: kDebugMode ? _debugLog : null,
            );

      final result = await client.checkForUpdates();
      // Sem rede/manifest: o PRÓPRIO client já registrou a tentativa por
      // artifact (digest vazio) inibindo retry <24h (ADR-03). Se nem isso
      // foi possível (ex: storage readonly), segue offline-first sem estado.
      if (kDebugMode) {
        debugPrint(
          '[bundle-sync] ok=${result.ok} '
          'checked=${result.checked.join(',')} '
          'applied=${result.applied.join(',')}',
        );
      }
    } catch (e) {
      // Boot nunca quebra por sync: mantém snapshot/estado anteriores.
      _debugLog('boot flush falhou (sanitizado): ${e.runtimeType}');
    }
  }

  static String _resolveOrigin() => BundleSyncClient.defaultBundlesOrigin;

  static void _debugLog(String message) {
    debugPrint('[bundle-sync] $message');
  }
}
