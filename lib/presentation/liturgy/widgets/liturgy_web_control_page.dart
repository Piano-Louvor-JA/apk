import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_target.dart';
import 'liturgy_site_session.dart';

/// Tela cheia do site/vídeo web da Liturgia. O conteúdo vive na
/// [LiturgySiteSession]: minimizar volta à lista sem fechar o site.
class LiturgyWebControlPage extends StatefulWidget {
  const LiturgyWebControlPage({
    super.key,
    required this.title,
    required this.url,
    this.local = false,
  }) : session = null;

  /// Reabre (expande) um site minimizado.
  const LiturgyWebControlPage.resume(
    LiturgySiteSession this.session, {
    super.key,
  }) : title = '',
       url = '',
       local = false;

  final String title;
  final String url;
  final bool local;
  final LiturgySiteSession? session;
  @override
  State<LiturgyWebControlPage> createState() => _LiturgyWebControlPageState();
}

class _LiturgyWebControlPageState extends State<LiturgyWebControlPage> {
  late final LiturgySiteSession session =
      widget.session ??
      LiturgySiteSession.open(
        title: widget.title,
        url: widget.url,
        local: widget.local,
      );
  bool _minimizing = false;

  @override
  void initState() {
    super.initState();
    session.expand();
  }

  @override
  void dispose() {
    // Sair pela seta (sem minimizar) fecha o site, como antes.
    if (!_minimizing) session.close();
    super.dispose();
  }

  void _minimize() {
    _minimizing = true;
    session.minimize();
    Navigator.of(context).pop();
  }

  Future<void> _project() async {
    final ok = await session.project();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('liturgy.parity.connectScreens'.tr())),
      );
    }
  }

  Future<void> _download() async {
    final ok = await session.download();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('liturgy.parity.downloadFailed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final controller = session.controller;
      final kind = LiturgyWebTarget.parse(session.url)?.kind;
      return Scaffold(
        appBar: AppBar(
          title: Text(session.title),
          actions: [
            IconButton(
              tooltip: 'liturgy.parity.project'.tr(),
              onPressed: _project,
              icon: const Icon(TablerIcons.presentation),
            ),
            IconButton(
              tooltip: 'liturgy.parity.stopProjection'.tr(),
              onPressed: session.stopProjection,
              icon: const Icon(TablerIcons.playerStop),
            ),
            IconButton(
              key: const Key('liturgy-site-minimize'),
              tooltip: 'common.minimize'.tr(),
              onPressed: _minimize,
              icon: const Icon(TablerIcons.minus),
            ),
          ],
        ),
        body: Column(
          children: [
            if (session.downloading)
              LinearProgressIndicator(value: session.progress),
            Expanded(child: WebViewWidget(controller: controller)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (session.local ||
                    session.offline != null ||
                    kind == 'direct-video')
                  IconButton(
                    tooltip: (session.paused ? 'remote.play' : 'remote.pause')
                        .tr(),
                    onPressed: session.toggle,
                    icon: Icon(
                      session.paused
                          ? TablerIcons.playerPlay
                          : TablerIcons.playerPause,
                    ),
                  ),
                if (!session.local &&
                    {'youtube', 'vimeo', 'direct-video'}.contains(kind))
                  IconButton(
                    tooltip:
                        (session.offline == null
                                ? 'liturgy.parity.downloadVideo'
                                : 'liturgy.parity.downloaded')
                            .tr(),
                    onPressed: session.downloading || session.offline != null
                        ? null
                        : _download,
                    icon: Icon(
                      session.offline == null
                          ? TablerIcons.download
                          : TablerIcons.circleCheck,
                    ),
                  ),
                IconButton(
                  tooltip: 'common.back'.tr(),
                  onPressed: () async {
                    if (await controller.canGoBack()) {
                      await controller.goBack();
                    }
                  },
                  icon: const Icon(TablerIcons.arrowLeft),
                ),
                IconButton(
                  tooltip: 'liturgy.parity.reload'.tr(),
                  onPressed: controller.reload,
                  icon: const Icon(TablerIcons.reload),
                ),
                IconButton(
                  tooltip: 'liturgy.parity.openExternal'.tr(),
                  onPressed: () {
                    if (session.local || session.offline != null) {
                      OpenFilex.open(session.offline ?? session.url);
                      return;
                    }
                    final target = LiturgyWebTarget.parse(session.currentUrl);
                    if (target != null) {
                      launchUrl(
                        Uri.parse(target.url),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(TablerIcons.externalLink),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
