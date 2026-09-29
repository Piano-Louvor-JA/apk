// coverage:ignore-file
// Executor de itens da liturgia -- depende de plataforma (player, url_launcher)
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:louvorja_piano_mobile/core/services/download_url_builder.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart'
    show PalcoAudioRoute;
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';

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

/// Executa a acao correspondente ao tipo do item da liturgia.
///
/// music -> toca audio via HymnAudioPlayer (carrega music_{id} da API)
/// site/online_video -> abre URL no navegador
/// video/images/pdf/presentation/other_files -> abre arquivo local
/// scheduled -> mostra detalhes do agendamento
class LiturgyItemExecutor {
  LiturgyItemExecutor._();

  static final _api = LouvorjaApiImpl(
    baseUrls: ApiConfig.databaseUrls(),
    filesUrls: ApiConfig.filesUrls(),
    apiToken: const String.fromEnvironment('API_TOKEN', defaultValue: ''),
  );

  /// Executa a acao do item. Retorna uma mensagem de feedback.
  static Future<String> execute(BuildContext context, LiturgyItem item) async {
    switch (item.type) {
      case LiturgyItemType.music:
        return _executeMusic(context, item);

      case LiturgyItemType.site:
        return _executeUrl(context, item);

      case LiturgyItemType.video:
        // F3.3k: com Palco ligado, vídeo LOCAL renderiza NA TV (receiver
        // tem <video>); ao terminar volta ao idle. Sem palco: abre externo.
        final stageV = StageSession.instance;
        final vpath = item.filePath;
        if (stageV.isOn && stageV.isPalcoMode && vpath != null) {
          if (stageV.playVideoOnStage(vpath)) {
            return 'Reproduzindo vídeo no Palco';
          }
        }
        return _executeFile(context, item);

      case LiturgyItemType.onlineVideo:
        // F3.3k: vídeo ONLINE (youtube etc) — só projeta se for URL de
        // arquivo direto (mp4/webm); senão abre externo (player dedicado).
        final stageO = StageSession.instance;
        final ourl = item.url;
        if (stageO.isOn && stageO.isPalcoMode && ourl != null) {
          final lower = ourl.toLowerCase();
          if (lower.endsWith('.mp4') || lower.endsWith('.webm')) {
            if (stageO.playVideoOnStage(ourl)) {
              return 'Reproduzindo vídeo no Palco';
            }
          }
        }
        return _executeUrl(context, item);

      case LiturgyItemType.pdf:
      case LiturgyItemType.otherFiles:
        return _executeFile(context, item);

      case LiturgyItemType.presentation:
      case LiturgyItemType.images:
        // F3.3i: com Palco ligado, PPTX/imagens projetam os slides na TV
        // (imagens extraídas do .pptx servidas via /media do sender).
        final stage = StageSession.instance;
        final path = item.filePath;
        if (stage.isOn && stage.isPalcoMode && path != null) {
          final count = stage.projectPptxSlides(path);
          if (count > 0) {
            return 'Projetando $count slides — setas do controle navegam';
          }
        }
        return _executeFile(context, item);

      case LiturgyItemType.scheduled:
        _showScheduledDetails(context, item);
        return '';

      case LiturgyItemType.annotation:
      case LiturgyItemType.notice:
      case LiturgyItemType.prayer:
      case LiturgyItemType.verse:
      case LiturgyItemType.category:
        // Nao executavel -- apenas visual
        return '';
    }
  }

  static Future<String> _executeMusic(
    BuildContext context,
    LiturgyItem item,
  ) async {
    if (item.musicId == null) {
      return 'Hino nao vinculado';
    }
    try {
      final hymn = await _api.fetchMusic(item.musicId!);
      final relativeUrl = hymn.urlMusic ?? '';
      if (relativeUrl.isEmpty) {
        return 'Audio nao disponivel';
      }
      // URL encodada por segmento: paths com espaco/acento quebram sem encode.
      final url = buildLiturgyMusicUrl(relativeUrl);
      // Palco ligado (modo tv/mirror): roteia o audio pela TV em vez de
      // tocar local (mesma regra do NowPlaying). Modo local ou palco off:
      // comporta-se como antes (toggle local).
      final stage = StageSession.instance;
      if (stage.isOn && stage.audioRoute != PalcoAudioRoute.local) {
        stage.playHymnAudio(
          url,
          title: hymn.title ?? item.name,
          cover: hymn.imageUrl,
        );
        return 'Tocando na TV: ${hymn.title ?? item.name}';
      }
      await HymnAudioPlayer.instance.toggleUrl(url);
      return 'Tocando: ${hymn.title ?? item.name}';
    } catch (_) {
      return 'Erro ao carregar hino';
    }
  }

  static Future<String> _executeUrl(
    BuildContext context,
    LiturgyItem item,
  ) async {
    final url = item.url;
    if (url == null || url.trim().isEmpty) {
      return 'URL nao definida';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return 'URL invalida';
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return 'Abrindo: $url';
    } catch (_) {
      return 'Erro ao abrir URL';
    }
  }

  static Future<String> _executeFile(
    BuildContext context,
    LiturgyItem item,
  ) async {
    final path = item.filePath;
    if (path == null || path.trim().isEmpty) {
      return 'Arquivo nao selecionado';
    }
    // No mobile, abrir arquivo local com url_launcher (funciona pra file://)
    // No web, mostrar SnackBar (sem sistema de arquivos)
    try {
      final uri = Uri.file(path);
      await launchUrl(uri);
      return 'Abrindo: ${path.split('/').last}';
    } catch (_) {
      return 'Nao foi possivel abrir o arquivo';
    }
  }

  static void _showScheduledDetails(BuildContext context, LiturgyItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.scheduledAt != null)
              Text('Agendado para: ${item.scheduledAt}'),
            if (item.subtitle.isNotEmpty) Text(item.subtitle),
            if (item.notes != null && item.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(item.notes!),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        return true;
      case LiturgyItemType.category:
      case LiturgyItemType.annotation:
      case LiturgyItemType.notice:
      case LiturgyItemType.prayer:
      case LiturgyItemType.verse:
        return false;
    }
  }
}
