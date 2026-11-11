library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:louvorja_piano_mobile/presentation/bible/bible_download_controller.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bloc/bible_bloc.dart';

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
  final _download = BibleDownloadController.instance;
  int? _lastRunning;

  @override
  void initState() {
    super.initState();
    BibleVersionDownloadMark.warmUp();
    _download.addListener(_onDownload);
  }

  void _onDownload() {
    if (mounted) setState(() {});
  }

  void _start(BibleState state) {
    if (_download.running || state is! BibleLoaded) return;
    _lastRunning = state.selectedVersionId;
    _download.start(versionId: state.selectedVersionId, books: state.books);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.read<BibleBloc>().state;
    final currentVersion = state is BibleLoaded
        ? state.selectedVersionId
        : null;
    final downloading = _download.running;
    final downloaded =
        !downloading &&
        (BibleVersionDownloadMark.isDownloaded(currentVersion ?? -1) ||
            (_lastRunning != null && _lastRunning == currentVersion &&
                BibleVersionDownloadMark.isDownloaded(_lastRunning!)));

    return IconButton(
      tooltip: downloaded
          ? 'Versão disponível offline'
          : 'Baixar Bíblia para offline',
      icon: downloading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: _download.total > 0
                    ? _download.done / _download.total
                    : null,
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
      onPressed: downloaded || downloading
          ? null
          : () => _start(context.read<BibleBloc>().state),
    );
  }

  @override
  void dispose() {
    // O download continua no controller; só para de ouvir o progresso.
    _download.removeListener(_onDownload);
    super.dispose();
  }
}
