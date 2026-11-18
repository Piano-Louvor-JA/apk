import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_video_cache.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_snapshot.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_target.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_link_repository_impl.dart';

/// Site (ou vídeo web) aberto pela Liturgia. Vive fora da tela cheia:
/// minimizar volta à lista e o site continua igual (página, rolagem,
/// projeção) até expandir de novo ou fechar.
class LiturgySiteSession extends ChangeNotifier {
  LiturgySiteSession._({
    required this.title,
    required this.url,
    required this.local,
    WebViewController Function()? createController,
  }) : _createController = createController;

  final String title, url;
  final bool local;
  final WebViewController Function()? _createController;
  late final WebViewController controller = _buildController();

  /// Site aberto agora (um por vez).
  static final current = ValueNotifier<LiturgySiteSession?>(null);

  /// Testes trocam a WebView real.
  @visibleForTesting
  static WebViewController Function()? controllerFactory;

  late String currentUrl = url;
  String? offline;
  bool downloading = false, projecting = false, paused = false;
  bool minimized = false, _closed = false;
  double? progress;
  Timer? _snapshotTimer;
  bool _capturing = false;

  bool get closed => _closed;

  /// Abre (ou reabre, se for o mesmo endereço ainda aberto) o site.
  static LiturgySiteSession open({
    required String title,
    required String url,
    bool local = false,
  }) {
    final previous = current.value;
    if (previous != null && !previous.closed && previous.url == url) {
      previous.expand();
      return previous;
    }
    previous?.close();
    final session = LiturgySiteSession._(
      title: title,
      url: url,
      local: local,
      createController: controllerFactory,
    );
    _setCurrent(session);
    unawaited(session._load());
    return session;
  }

  /// Aberto/fechado pela tela (initState/dispose): avisa após o quadro.
  static void _setCurrent(LiturgySiteSession? value) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // Não apaga um site que abriu depois; não traz de volta um fechado.
        if (value == null && current.value != null && !current.value!.closed) {
          return;
        }
        if (value != null && value.closed) return;
        current.value = value;
      });
      SchedulerBinding.instance.scheduleFrame();
    } else {
      current.value = value;
    }
  }

  WebViewController _buildController() {
    final factory = _createController;
    if (factory != null) return factory();
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri != null &&
                    ({'https', 'http', 'about', 'data'}.contains(uri.scheme) ||
                        (local || offline != null) && uri.scheme == 'file')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (value) {
            if (!local && offline == null && !value.startsWith('file:')) {
              currentUrl = value;
              _notify();
            }
          },
        ),
      );
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  void minimize() {
    if (_closed || minimized) return;
    minimized = true;
    _notify();
  }

  void expand() {
    if (_closed || !minimized) return;
    minimized = false;
    _notify();
  }

  /// Fecha o site: para a captura para as telas. Igual a sair da tela
  /// cheia antes (a projeção já enviada só para pelo botão de parar).
  void close() {
    if (_closed) return;
    _snapshotTimer?.cancel();
    _closed = true;
    if (current.value == this || current.value == null) _setCurrent(null);
    super.dispose();
  }

  Future<LiturgyVideoCache> _cache() async => LiturgyVideoCache(
    Directory(
      '${(await getApplicationDocumentsDirectory()).path}/liturgy-online-videos',
    ),
    LiturgyLinkRepositoryImpl(),
  );

  Future<void> _load() async {
    if (_createController != null) return;
    if (local) {
      await controller.loadFile(File(url).absolute.path);
      return;
    }
    final cached = await (await _cache()).find(url);
    if (_closed) return;
    if (cached != null) {
      offline = cached;
      await controller.loadFile(cached);
    } else {
      final target = LiturgyWebTarget.parse(url);
      if (target != null) {
        await controller.loadRequest(
          Uri.parse(
            target.kind == 'youtube' || target.kind == 'vimeo'
                ? target.embedUrl
                : target.url,
          ),
        );
      }
    }
  }

  /// Retorna false se falhar.
  Future<bool> download() async {
    downloading = true;
    _notify();
    try {
      final path = await (await _cache()).download(
        url,
        onProgress: (received, total) {
          progress = total > 0 ? received / total : null;
          _notify();
        },
      );
      if (_closed) return true;
      offline = path;
      await controller.loadFile(path);
      return true;
    } catch (_) {
      return false;
    } finally {
      downloading = false;
      _notify();
    }
  }

  Future<void> toggle() async {
    paused = !paused;
    await controller.runJavaScript(
      '(()=>{const v=document.querySelector("video,audio");if(v){${paused ? 'v.pause()' : 'v.play()'}}})()',
    );
    if (projecting) StageSession.instance.toggleStageVideoPause();
    _notify();
  }

  Future<void> _snapshot() async {
    if (_capturing || !projecting || !StageSession.instance.isOn) return;
    _capturing = true;
    try {
      final bytes = await LiturgyWebSnapshot.capture();
      if (!_closed && projecting) {
        StageSession.instance.projectWebSnapshot(bytes);
      }
    } catch (_) {
      /* mantém a última imagem enquanto a página carrega */
    } finally {
      _capturing = false;
    }
  }

  /// false = nenhuma tela conectada.
  Future<bool> project() async {
    final stage = StageSession.instance;
    if (!stage.isOn) return false;
    if (local || offline != null) {
      if (stage.playVideoOnStage(offline ?? url)) {
        projecting = true;
        _notify();
      }
      return true;
    }
    final target = LiturgyWebTarget.parse(currentUrl);
    if (target == null) return true;
    if (target.kind == 'site' && Platform.isAndroid) {
      projecting = true;
      _notify();
      await _snapshot();
      _snapshotTimer?.cancel();
      _snapshotTimer = Timer.periodic(
        const Duration(milliseconds: 800),
        (_) => unawaited(_snapshot()),
      );
      return true;
    }
    if (target.kind == 'direct-video') {
      stage.playVideoOnStage(target.url);
      projecting = true;
      _notify();
    } else {
      await stage.project(
        title: '',
        body: '',
        richBody: target.projectionHtml,
        module: 'liturgy',
      );
    }
    return true;
  }

  void stopProjection() {
    _snapshotTimer?.cancel();
    StageSession.instance.stopVideoOnStage();
    StageSession.instance.clearContent();
    projecting = false;
    _notify();
  }
}
