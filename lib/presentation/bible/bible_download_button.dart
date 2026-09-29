library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:louvorja_piano_mobile/core/services/bible_download_service.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';
import 'package:louvorja_piano_mobile/data/repositories/bible_repository_impl.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bloc/bible_bloc.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';

/// Indica se uma versão da Bíblia já foi baixada completamente.
class BibleVersionDownloadMark {
  static String? _docsDir;

  static Future<String> _dir() async =>
      _docsDir ??= (await getApplicationDocumentsDirectory()).path;

  static String pathFor(int versionId) =>
      '${_docsDir ?? ''}/catalog_bible_version_downloaded_$versionId.json';

  static bool isDownloaded(int versionId) {
    if (kIsWeb) return false;
    final dir = _docsDir;
    if (dir == null) return false;
    return File(pathFor(versionId)).existsSync();
  }

  /// Marca (chamado ao concluir download).
  static Future<void> markDownloaded(int versionId) async {
    if (kIsWeb) return;
    final dir = await _dir();
    File(
      '$dir/catalog_bible_version_downloaded_$versionId.json',
    ).writeAsStringSync('{"versionId": $versionId}');
  }

  static void warmUp() {
    if (_docsDir == null && !kIsWeb) {
      _dir().then((_) {});
    }
  }
}

/// Botão "Baixar Bíblia para offline" na AppBar da Bíblia.
///
/// Baixa TODOS os capítulos da versão selecionada (livros da tela atual).
/// Cada capítulo gravado pelo getChapter no CatalogCache — offline total
/// após conclusão. Progresso em diálogo não bloqueante (pode fechar).
class BibleDownloadButton extends StatefulWidget {
  const BibleDownloadButton({super.key});

  @override
  State<BibleDownloadButton> createState() => _BibleDownloadButtonState();
}

class _BibleDownloadButtonState extends State<BibleDownloadButton> {
  bool _downloading = false;
  int _done = 0;
  int _total = 0;
  int? _downloadedVersion;

  @override
  void initState() {
    super.initState();
    BibleVersionDownloadMark.warmUp();
  }

  Future<void> _start(BibleState state) async {
    if (_downloading || state is! BibleLoaded) return;
    final versionId = state.selectedVersionId;
    final books = state.books;

    setState(() => _downloading = true);
    try {
      final api = LouvorjaApiImpl(
        baseUrls: ApiConfig.databaseUrls(),
        filesUrls: ApiConfig.filesUrls(),
        apiToken: const String.fromEnvironment('API_TOKEN', defaultValue: ''),
      );
      final dir = await getApplicationDocumentsDirectory();
      final repo = BibleRepositoryImpl(api, CatalogCache(dir));

      final svc = BibleDownloadService(repo);
      final (ok, failed) = await svc.downloadVersion(
        versionId: versionId,
        books: books,
        onProgress: (d, t) {
          if (mounted)
            setState(() {
              _done = d;
              _total = t;
            });
        },
      );
      // Marca a versão como baixada: offline o dropdown mostra só as que
      // têm conteúdo no disco; o botão vira check (pedido Rafael 2026-08-16).
      if (ok > 0) {
        await BibleVersionDownloadMark.markDownloaded(versionId);
        if (mounted) setState(() => _downloadedVersion = versionId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$ok capítulos disponíveis offline${failed > 0 ? ' ($failed falhas)' : ''}',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('errors.connection'.tr())));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.read<BibleBloc>().state;
    final currentVersion = state is BibleLoaded
        ? state.selectedVersionId
        : null;
    final downloaded = _downloadedVersion != null
        ? _downloadedVersion == currentVersion
        : BibleVersionDownloadMark.isDownloaded(currentVersion ?? -1);

    return IconButton(
      tooltip: downloaded
          ? 'Versão disponível offline'
          : 'Baixar Bíblia para offline',
      icon: _downloading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: _total > 0 ? _done / _total : null,
                color: theme.colorScheme.primary,
              ),
            )
          : downloaded
          ? Icon(
              TablerIcons.circleCheck,
              size: 20,
              color: theme.colorScheme.primary,
            )
          : const Icon(TablerIcons.cloudDownload),
      onPressed: downloaded || _downloading
          ? null
          : () => _start(context.read<BibleBloc>().state),
    );
  }

  @override
  void dispose() {
    // Progresso é best-effort; download segue no isolado do repo.
    super.dispose();
  }
}
