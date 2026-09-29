library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/bible_version.dart';
import '../services/connectivity_service.dart';

/// Versões da Bíblia visíveis: online = todas do idioma;
/// offline = apenas as com download completo marcado em disco.
///
/// Marcação: catalog_bible_version_downloaded_{id}.json no documents dir
/// (gravado pelo BibleDownloadButton ao concluir).
class BibleOfflineVersions {
  static String? _docsDir;
  static bool? _offlineCache;

  static Future<String> _dir() async =>
      _docsDir ??= (await getApplicationDocumentsDirectory()).path;

  /// Síncrono para uso no build; resultado em cache pós-primeira chamada.
  static List<BibleVersion> filter(List<BibleVersion> versions) {
    if (kIsWeb) return versions;
    final offline = _offlineCache;
    if (offline == false) return versions;

    final dir = _docsDir;
    if (dir == null) {
      // Primeira chamada (sem cache ainda): aquece em background e mantém
      // todas — nunca mente offline removendo versões sem veredito.
      _warmUp(versions);
      return versions;
    }
    if (offline != true) return versions;

    return versions
        .where(
          (v) => File(
            '$dir/catalog_bible_version_downloaded_${v.id}.json',
          ).existsSync(),
        )
        .toList();
  }

  static Future<void> _warmUp(List<BibleVersion> versions) async {
    try {
      await _dir();
      _offlineCache = !(await ConnectivityService().isConnected);
    } catch (_) {
      _offlineCache = false;
    }
  }

  /// Invalida caches (após download concluir ou conectividade mudar).
  static void invalidate() {
    _offlineCache = null;
  }
}
