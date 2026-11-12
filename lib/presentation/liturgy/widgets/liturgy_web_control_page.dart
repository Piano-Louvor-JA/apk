import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_snapshot.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_video_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_link_repository_impl.dart';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_target.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_cast_button.dart';

class LiturgyWebControlPage extends StatefulWidget {
  const LiturgyWebControlPage({
    super.key,
    required this.title,
    required this.url,
    this.local = false,
  });
  final String title;
  final String url;
  final bool local;
  @override
  State<LiturgyWebControlPage> createState() => _LiturgyWebControlPageState();
}

class _LiturgyWebControlPageState extends State<LiturgyWebControlPage> {
  late final WebViewController _controller;
  late String _url = widget.url;
  String? _offline;
  bool _downloading = false;
  double? _progress;
  bool _projecting = false;
  bool _paused = false;
  Timer? _snapshotTimer;
  bool _capturing = false;
  @override
  void dispose() {
    _snapshotTimer?.cancel();
    super.dispose();
  }

  Future<void> _snapshot() async {
    if (_capturing || !_projecting || !StageSession.instance.isOn) return;
    _capturing = true;
    try {
      final bytes = await LiturgyWebSnapshot.capture();
      if (mounted && _projecting)
        StageSession.instance.projectWebSnapshot(bytes);
    } catch (_) {
      /* mantém a última imagem enquanto a página carrega */
    } finally {
      _capturing = false;
    }
  }

  Future<LiturgyVideoCache> _cache() async => LiturgyVideoCache(
    Directory(
      '${(await getApplicationDocumentsDirectory()).path}/liturgy-online-videos',
    ),
    LiturgyLinkRepositoryImpl(),
  );
  Future<void> _load() async {
    if (widget.local) {
      await _controller.loadFile(File(widget.url).absolute.path);
      return;
    }
    final cached = await (await _cache()).find(widget.url);
    if (!mounted) return;
    if (cached != null) {
      _offline = cached;
      await _controller.loadFile(cached);
    } else {
      final target = LiturgyWebTarget.parse(widget.url);
      if (target != null)
        await _controller.loadRequest(
          Uri.parse(
            target.kind == 'youtube' || target.kind == 'vimeo'
                ? target.embedUrl
                : target.url,
          ),
        );
    }
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final path = await (await _cache()).download(
        widget.url,
        onProgress: (received, total) {
          if (mounted)
            setState(() => _progress = total > 0 ? received / total : null);
        },
      );
      if (!mounted) return;
      setState(() => _offline = path);
      await _controller.loadFile(path);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('liturgy.parity.downloadFailed'.tr())),
        );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _toggle() async {
    _paused = !_paused;
    await _controller.runJavaScript(
      '(()=>{const v=document.querySelector("video,audio");if(v){${_paused ? 'v.pause()' : 'v.play()'}}})()',
    );
    if (_projecting) StageSession.instance.toggleStageVideoPause();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri != null &&
                    ({'https', 'http', 'about', 'data'}.contains(uri.scheme) ||
                        (widget.local || _offline != null) &&
                            uri.scheme == 'file')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (url) {
            if (!widget.local &&
                _offline == null &&
                mounted &&
                !url.startsWith('file:'))
              setState(() => _url = url);
          },
        ),
      );
    unawaited(_load());
  }

  Future<void> _project() async {
    final stage = StageSession.instance;
    if (!stage.isOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('liturgy.parity.connectScreens'.tr())),
      );
      return;
    }
    if (widget.local || _offline != null) {
      final ok = stage.playVideoOnStage(_offline ?? widget.url);
      if (ok && mounted) setState(() => _projecting = true);
      return;
    }
    final target = LiturgyWebTarget.parse(_url);
    if (target == null) return;
    if (target.kind == 'site' && Platform.isAndroid) {
      setState(() => _projecting = true);
      await _snapshot();
      _snapshotTimer?.cancel();
      _snapshotTimer = Timer.periodic(
        const Duration(milliseconds: 800),
        (_) => unawaited(_snapshot()),
      );
      return;
    }

    if (target.kind == 'direct-video') {
      stage.playVideoOnStage(target.url);
      if (mounted) setState(() => _projecting = true);
    } else {
      await stage.project(
        title: '',
        body: '',
        richBody: target.projectionHtml,
        module: 'liturgy',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        const StageCastButton(),
        IconButton(
          tooltip: 'liturgy.parity.project'.tr(),
          onPressed: _project,
          icon: const Icon(TablerIcons.presentation),
        ),
        IconButton(
          tooltip: 'liturgy.parity.stopProjection'.tr(),
          onPressed: () {
            StageSession.instance.stopVideoOnStage();
            StageSession.instance.clearContent();
            setState(() => _projecting = false);
          },
          icon: const Icon(TablerIcons.playerStop),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_downloading) LinearProgressIndicator(value: _progress),
        Expanded(child: WebViewWidget(controller: _controller)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.local ||
                _offline != null ||
                LiturgyWebTarget.parse(widget.url)?.kind == 'direct-video')
              IconButton(
                tooltip: (_paused ? 'remote.play' : 'remote.pause').tr(),
                onPressed: _toggle,
                icon: Icon(
                  _paused ? TablerIcons.playerPlay : TablerIcons.playerPause,
                ),
              ),
            if (!widget.local &&
                {
                  'youtube',
                  'vimeo',
                  'direct-video',
                }.contains(LiturgyWebTarget.parse(widget.url)?.kind))
              IconButton(
                tooltip:
                    (_offline == null
                            ? 'liturgy.parity.downloadVideo'
                            : 'liturgy.parity.downloaded')
                        .tr(),
                onPressed: _downloading || _offline != null ? null : _download,
                icon: Icon(
                  _offline == null
                      ? TablerIcons.download
                      : TablerIcons.circleCheck,
                ),
              ),
            IconButton(
              tooltip: 'common.back'.tr(),
              onPressed: () async {
                if (await _controller.canGoBack()) await _controller.goBack();
              },
              icon: const Icon(TablerIcons.arrowLeft),
            ),
            IconButton(
              tooltip: 'liturgy.parity.reload'.tr(),
              onPressed: _controller.reload,
              icon: const Icon(TablerIcons.reload),
            ),
            IconButton(
              tooltip: 'liturgy.parity.openExternal'.tr(),
              onPressed: () {
                if (widget.local || _offline != null) {
                  OpenFilex.open(_offline ?? widget.url);
                  return;
                }
                final target = LiturgyWebTarget.parse(_url);
                if (target != null)
                  launchUrl(
                    Uri.parse(target.url),
                    mode: LaunchMode.externalApplication,
                  );
              },
              icon: const Icon(TablerIcons.externalLink),
            ),
          ],
        ),
      ],
    ),
  );
}
