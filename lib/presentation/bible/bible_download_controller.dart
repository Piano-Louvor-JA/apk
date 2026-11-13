library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import 'package:louvorja_piano_mobile/core/services/bible_download_service.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';
import 'package:louvorja_piano_mobile/data/repositories/bible_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bible_download_button.dart';

/// Messenger do app: avisos que precisam aparecer fora da tela que os
/// disparou (ex.: download da Bíblia terminando em outra tela).
final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Download da Bíblia para offline, vivo no app inteiro: continua quando
/// a pessoa sai da tela da Bíblia, e o botão reencontra o progresso ao
/// voltar (antes o progresso se perdia e dava pra baixar de novo).
class BibleDownloadController extends ChangeNotifier {
  BibleDownloadController._();
  static final instance = BibleDownloadController._();

  int? versionId;
  int done = 0;
  int total = 0;
  bool get running => versionId != null;

  Future<void> start({
    required int versionId,
    required List<BibleBook> books,
  }) async {
    if (running) return;
    this.versionId = versionId;
    done = 0;
    total = 0;
    notifyListeners();
    String message;
    try {
      final api = LouvorjaApiImpl(
        baseUrls: ApiConfig.databaseUrls(),
        filesUrls: ApiConfig.filesUrls(),
        apiToken: const String.fromEnvironment('API_TOKEN', defaultValue: ''),
      );
      final dir = await getApplicationDocumentsDirectory();
      final repo = BibleRepositoryImpl(api, CatalogCache(dir));
      final (ok, failed) = await BibleDownloadService(repo).downloadVersion(
        versionId: versionId,
        books: books,
        onProgress: (d, t) {
          done = d;
          total = t;
          notifyListeners();
        },
      );
      if (ok > 0) await BibleVersionDownloadMark.markDownloaded(versionId);
      message =
          '$ok capítulos disponíveis offline${failed > 0 ? ' ($failed falhas)' : ''}';
    } catch (_) {
      message = 'errors.connection'.tr();
    } finally {
      this.versionId = null;
      notifyListeners();
    }
    appScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
