// coverage:ignore-file
// Executor de itens da liturgia -- depende de plataforma (player, url_launcher)
library;

import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_external_player.dart';

import 'dart:async';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_web_control_page.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_pdf_page.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_target.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:louvorja_piano_mobile/core/services/palco/pptx_slide_extractor.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_gallery_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_playback.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/scheduled_resolver.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_service.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';
import 'package:louvorja_piano_mobile/core/utils/scripture_format.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_catalog_repository.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bible_page.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bloc/bible_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_text_control_page.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

import 'package:louvorja_piano_mobile/core/services/download_url_builder.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart'
    show PalcoAudioRoute;
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

/// Monta a URL de stream do hino da liturgia (percent-encode por segmento).
///
/// Bug real: paths da API tem espaco/acento; sem encode o request quebra
/// (intermittencia de audio reportada no culto). Mesma regra do download.
String buildLiturgyMusicUrl(String relativeUrl) {
  if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
    return relativeUrl;
  }
  return DownloadUrlBuilder.build(relativeUrl);
}

/// A preferência do item seleciona a mesma faixa vocal/instrumental do desktop.
String resolveLiturgyMusicPath(Hymn hymn, LiturgyItem item) =>
    (item.musicMode == 'instrumental' ? hymn.urlInstrumental : hymn.urlMusic) ??
    '';

/// Executa a acao correspondente ao tipo do item da liturgia.
///
/// music -> toca audio via HymnAudioPlayer (carrega music_{id} da API)
/// site/online_video -> abre URL no navegador
/// video/images/pdf/presentation/other_files -> abre arquivo local
/// scheduled -> mostra detalhes do agendamento
class LiturgyItemExecutor {
  LiturgyItemExecutor._();

  /// Executa a acao do item. Retorna uma mensagem de feedback.
  static Future<String> execute(
    BuildContext context,
    LiturgyItem item, {
    DateTime? date,
    VoidCallback? onStarted,
    ValueChanged<LiturgyItem>? onAnnotationChanged,
  }) async {
    if ({
          LiturgyItemType.audio,
          LiturgyItemType.video,
          LiturgyItemType.onlineVideo,
        }.contains(item.type) &&
        item.playerId?.isNotEmpty == true &&
        item.playerId != 'default') {
      final path = item.type == LiturgyItemType.onlineVideo
          ? LiturgyWebTarget.parse(item.url ?? '')?.url
          : item.filePath ?? item.filePaths.firstOrNull;
      if (path == null) return 'liturgy.parity.fileUnavailable'.tr();
      try {
        await LiturgyExternalPlayer.open(path, item.playerId!);
        onStarted?.call();
        return '';
      } catch (_) {
        return 'liturgy.parity.fileUnavailable'.tr();
      }
    }
    switch (item.type) {
      case LiturgyItemType.music:
        return _executeMusic(context, item, onStarted: onStarted);

      case LiturgyItemType.site:
        return _executeUrl(context, item, onStarted: onStarted);

      case LiturgyItemType.video:
        final path = item.filePath;
        if (path == null || path.isEmpty || !File(path).existsSync())
          return 'liturgy.parity.fileUnavailable'.tr();
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => LiturgyWebControlPage(
                title: item.name,
                url: path,
                local: true,
              ),
            ),
          ),
        );
        onStarted?.call();
        return '';
      case LiturgyItemType.onlineVideo:
        return _executeUrl(context, item, onStarted: onStarted);
      case LiturgyItemType.pdf:
        final path = item.filePath;
        if (path == null || path.isEmpty || !File(path).existsSync())
          return 'liturgy.parity.fileUnavailable'.tr();
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => LiturgyPdfPage(path: path, title: item.name),
            ),
          ),
        );
        onStarted?.call();
        return '';
      case LiturgyItemType.otherFiles:
        return _executeFile(context, item, onStarted: onStarted);
      case LiturgyItemType.images:
        final paths = item.filePaths.isNotEmpty
            ? item.filePaths
            : [if (item.filePath?.isNotEmpty == true) item.filePath!];
        if (paths.isEmpty) return 'liturgy.parity.fileUnavailable'.tr();
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  LiturgyGalleryPage(title: item.name, paths: paths),
            ),
          ),
        );
        onStarted?.call();
        return '';
      case LiturgyItemType.presentation:
        final path = item.filePath;
        if (path == null || path.isEmpty || !File(path).existsSync())
          return 'liturgy.parity.fileUnavailable'.tr();
        final slides = PptxSlideExtractor.extract(
          path,
          requireCompleteSlides: true,
        );
        if (slides.isNotEmpty) {
          final directory = await getTemporaryDirectory();
          final stamp = DateTime.now().microsecondsSinceEpoch;
          final paths = <String>[];
          for (var i = 0; i < slides.length; i++) {
            final file = File(
              '${directory.path}/liturgy-$stamp-$i-${slides[i].name}',
            );
            await file.writeAsBytes(slides[i].bytes);
            paths.add(file.path);
          }
          if (!context.mounted) return '';
          unawaited(
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    LiturgyGalleryPage(title: item.name, paths: paths),
              ),
            ),
          );
          onStarted?.call();
          return '';
        }
        return _executeFile(context, item, onStarted: onStarted);

      case LiturgyItemType.scheduled:
        final repo = ScheduledRepository(await SharedPreferences.getInstance());
        final resolved = ScheduledResolver.resolve(
          item,
          date ?? DateTime.now(),
          repo.loadCategories(),
          repo.loadItems(),
        );
        if (resolved == null) return 'liturgy.parity.scheduledEmpty'.tr();
        if (!context.mounted) return '';
        return execute(context, resolved, date: date, onStarted: onStarted);

      case LiturgyItemType.annotation:
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => LiturgyTextControlPage(
                item: item,
                onChanged: onAnnotationChanged,
              ),
            ),
          ),
        );
        onStarted?.call();
        return '';
      case LiturgyItemType.verse:
        return _executeVerse(context, item);
      case LiturgyItemType.notice:
      case LiturgyItemType.prayer:
      case LiturgyItemType.category:
        // Nao executavel -- apenas visual
        return '';

      case LiturgyItemType.audio:
        // Áudio local: prévia e controles no mesmo executor de mídia do vídeo.
        if (item.filePath != null || item.filePaths.isNotEmpty) {
          final path = item.filePath ?? item.filePaths.firstOrNull;
          if (path == null || !File(path).existsSync())
            return 'liturgy.parity.fileUnavailable'.tr();
          unawaited(
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => LiturgyWebControlPage(
                  title: item.name,
                  url: path,
                  local: true,
                ),
              ),
            ),
          );
          onStarted?.call();
          return '';
        }
        return '';
    }
  }

  static Future<String> _executeMusic(
    BuildContext context,
    LiturgyItem item, {
    VoidCallback? onStarted,
  }) async {
    try {
      final language =
          EasyLocalization.of(context)?.locale.languageCode ?? 'pt';
      final catalog = await LiturgyCatalogRepository.open(language);
      final playback = await LiturgyPlayback.resolve(
        item,
        catalog: catalog,
        offline: OfflineMusicService(),
      );
      if (!context.mounted) return '';
      final stage = StageSession.instance;
      final player = HymnAudioPlayer.instance;
      nowPlaying.start(
        hymnId: item.musicId!,
        title: playback.detail.title ?? item.name,
        album: item.subtitle,
        detail: playback.detail,
        instrumental: item.musicMode == 'instrumental',
        durationMs: playback.detail.durationMs ?? item.durationMs,
        audioSource: playback.source,
        audioIsLocal: playback.isLocal,
      );
      await player.playUrl(playback.source);
      onStarted?.call();
      if (stage.isOn && stage.audioRoute != PalcoAudioRoute.local) {
        stage.playHymnAudio(
          playback.source,
          title: playback.detail.title ?? item.name,
          cover: playback.detail.imageUrl,
        );
        if (stage.audioRoute == PalcoAudioRoute.tv) await player.setVolume(0);
      }
      // Como em Hinos: toca no miniplayer (prévia da letra); a tela cheia
      // abre pelo botão de tela cheia dele.
      return '';
    } catch (_) {
      return 'liturgy.parity.audioUnavailable'.tr();
    }
  }

  static Future<String> _executeVerse(
    BuildContext context,
    LiturgyItem item,
  ) async {
    if (item.verseBookId == null || item.verseChapter == null)
      return 'liturgy.parity.incompleteItem'.tr();
    BibleBloc? opened;
    try {
      final catalog = await LiturgyCatalogRepository.open(
        EasyLocalization.of(context)?.locale.languageCode ?? 'pt',
      );
      final bloc = BibleBloc(catalog);
      opened = bloc;
      Future<BibleLoaded> wait() => bloc.stream
          .firstWhere((state) => state is BibleLoaded || state is BibleError)
          .then((state) {
            if (state is! BibleLoaded) throw StateError('bible');
            return state;
          });
      var next = wait();
      bloc.add(BibleBootstrap());
      await next;
      next = wait();
      bloc.add(BibleSelectBook(item.verseBookId!));
      await next;
      next = wait();
      bloc.add(BibleSelectChapter(item.verseChapter!));
      final chapter = await next;
      if ((item.verseNumbers ?? '').trim().isNotEmpty)
        bloc.add(
          BibleSelectVerses(
            ScriptureFormat.parseVerseQuery(item.verseNumbers!, chapter.verses),
          ),
        );
      if (!context.mounted) {
        await bloc.close();
        return '';
      }
      unawaited(
        Navigator.of(context)
            .push<void>(
              MaterialPageRoute(builder: (_) => BiblePage(testBloc: bloc)),
            )
            .whenComplete(bloc.close),
      );
      return '';
    } catch (_) {
      await opened?.close();
      return 'liturgy.parity.catalogUnavailable'.tr();
    }
  }

  static Future<String> _executeUrl(
    BuildContext context,
    LiturgyItem item, {
    VoidCallback? onStarted,
  }) async {
    final target = LiturgyWebTarget.parse(item.url ?? '');
    if (target == null) return 'liturgy.parity.incompleteItem'.tr();
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              LiturgyWebControlPage(title: item.name, url: target.url),
        ),
      ),
    );
    onStarted?.call();
    return '';
  }

  static Future<String> _executeFile(
    BuildContext context,
    LiturgyItem item, {
    VoidCallback? onStarted,
  }) async {
    final path = item.filePath?.trim().isNotEmpty == true
        ? item.filePath
        : item.filePaths.firstOrNull;
    if (path == null || path.trim().isEmpty) {
      return 'liturgy.parity.fileUnavailable'.tr();
    }
    // No mobile, abrir arquivo local com url_launcher (funciona pra file://)
    // No web, mostrar SnackBar (sem sistema de arquivos)
    try {
      final result = await OpenFilex.open(path);
      if (result.type == ResultType.done &&
          item.type != LiturgyItemType.otherFiles)
        onStarted?.call();
      return result.type == ResultType.done
          ? ''
          : 'liturgy.parity.fileUnavailable'.tr();
    } catch (_) {
      return 'liturgy.parity.fileUnavailable'.tr();
    }
  }

  /// Verifica se o tipo de item e executavel (tem acao ao tap).
  static bool isExecutable(LiturgyItemType type) {
    switch (type) {
      case LiturgyItemType.music:
      case LiturgyItemType.site:
      case LiturgyItemType.onlineVideo:
      case LiturgyItemType.video:
      case LiturgyItemType.images:
      case LiturgyItemType.pdf:
      case LiturgyItemType.presentation:
      case LiturgyItemType.otherFiles:
      case LiturgyItemType.scheduled:
      case LiturgyItemType.audio:
      case LiturgyItemType.annotation:
      case LiturgyItemType.verse:
        return true;
      case LiturgyItemType.category:
      case LiturgyItemType.notice:
      case LiturgyItemType.prayer:
        return false;
    }
  }
}
