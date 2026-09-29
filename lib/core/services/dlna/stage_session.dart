library;

import 'dart:async' show unawaited, StreamSubscription;
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:image/image.dart' as image;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'dart:ui' as ui;

import 'ssdp_discovery.dart';
import 'webos_tv_dial_probe.dart';
import 'cast_controller.dart';
import 'stage_slide_painter.dart';
import 'stage_settings_repository.dart';
import '../palco/palco_controller.dart';
import '../palco/palco_orchestrator.dart';
import '../palco/palco_models.dart' show PalcoMessage;
import '../palco/pptx_slide_extractor.dart';
import '../palco/palco_foreground.dart';

/// Palco global: sessão de cast PERSISTENTE entre telas.
///
/// Quando ligado, a TV mostra o background/personalização definida e
/// AGUARDA conteúdo — qualquer módulo (liturgia, bíblia, player) projeta
/// nele via [project]. Desligar = desconecta da TV.
///
/// Transportes:
/// - DLNA (rasteriza PNG/JPEG + SOAP) — TVs genéricas.
/// - Palco WS (protocolo v2) — receiver LouvorJA (webOS): texto nativo,
///   áudio, vídeo, timer e controle por setas do remote.
class StageSession extends ChangeNotifier {
  StageSession._();
  static final StageSession instance = StageSession._();

  final CastController _cast = CastController();
  final StageSettingsRepository _settingsRepo = StageSettingsRepository();

  /// Transporte Palco WS (nulo = usando DLNA).
  PalcoController? _palco;
  bool get isPalcoMode => _palco != null;

  StageSettings settings = const StageSettings();
  DlnaRenderer? renderer;
  bool _busy = false;
  ui.Image? _backgroundImage;

  bool get isOn => _cast.isConnected || isPalcoMode;
  String? get rendererName =>
      isPalcoMode ? _palco!.target?.name : _cast.rendererName;

  /// F3.3x: IP real da TV conectada (via socket WS) — nulo até conectar.
  /// Diferente do target (IP do próprio celular): este é o DA TV.
  String? get receiverIp =>
      isPalcoMode && _palco!.isConnected ? _palco!.receiverIp : null;
  String? get castLastError => _cast.lastError;

  /// Controle remoto: receivers conectados por role (desktop/web/tv).
  Map<String, int> get receiverRoles =>
      isPalcoMode ? _palco!.receiverRoles : const {};

  /// Controle remoto: último estado de player reportado por receiver.
  Map<String, dynamic> get remotePlayerState =>
      isPalcoMode ? _palco!.remotePlayerState : const {};

  /// Controle remoto: envia comando (play/pause/stop/volume/seek) ao
  /// receiver do role dado. Retorna estado do ack ou null.
  Future<Map<String, dynamic>?> sendRemoteCommand(
    String command, {
    String role = 'desktop',
    double? value,
  }) => isPalcoMode
      ? _palco!.sendRemoteCommand(command, role: role, value: value)
      : Future.value(null);

  /// Liga o palco no modo Palco WS (receiver LouvorJA na TV).
  /// A TV conecta no sender do celular ao abrir o app dela.
  Future<bool> turnOnPalco(PalcoTarget tv) async {
    // Multi-palco: o slot "principal" do orchestrator É o transporte desta
    // sessão — um sender só (portas 7080/7081), estado compartilhado com o
    // gerenciador de telas. Antes: controller paralelo deixava o slot
    // "desconectado" no gerenciador (bug 2026-08-21).
    final orch = PalcoOrchestrator.instance;
    await orch.loadStoredConfig();
    if (orch.slot('principal') == null) {
      orch.addSlot(id: 'principal', label: 'Principal');
    }
    final ok = await orch.connectTv('principal', tv);
    if (!ok) return false;
    final p = orch.slot('principal')!.controller;
    _palco = p;
    // Senders de telas salvas ficam disponíveis para reconexão automática.
    await orch.startStoredSenders(excludeId: 'principal');
    renderer = null;
    // F3.3: foreground service — sobrevive a background (One UI mata rede).
    unawaited(PalcoForeground.start());
    // F3.3i: setas do controle da TV navegam a sequência de slides.
    _remoteKeySub?.cancel();
    _remoteKeySub = p.events.listen((m) {
      if (m.type == 'remote-key' && m.fields['key'] is String) {
        navigateSlides(m.fields['key'] as String);
      }
      // F3.3k: vídeo terminou na TV → volta ao idle do palco.
      if (m.type == 'ended' && m.fields['media'] == 'video') {
        _videoOnStage = false;
        notifyListeners();
        stopSlides();
      }
    });
    // F3.3m: re-aplica o BG do usuário como bgPalco (body do palco).
    try {
      final bytes = await _settingsRepo.loadBackgroundImage();
      if (bytes != null) {
        final url = p.serveMedia('palco_bg.png', bytes);
        if (url != null) p.setPalcoBackground(url);
      }
    } catch (_) {
      /* sem BG salvo: segue */
    }
    // F3.3u: wakelock — CPU sleep com tela apagada derruba o WS mesmo com
    // foreground service em alguns aparelhos (One UI agressivo).
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    notifyListeners();
    return true;
  }

  /// F3.3y: após ligar o sender, detecta TVs na rede (SSDP). Se uma TV foi
  /// encontrada mas nenhum receiver conectou em ~8s, orienta o operador a
  /// abrir o app Palco na TV pelo controle (webOS não permite launch remoto
  /// fora do Dev Mode — limitação da plataforma, não do app).
  /// Retorna mensagem de orientação ou null se tudo certo.
  Future<String?> checkTvNeedsPalcoOpen() async {
    // espera 8s pelo receiver conectar sozinho (scan da TV é rápido)
    for (var i = 0; i < 16; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (_palco != null && _palco!.isConnected) return null; // conectou
    }
    // sem receiver: tem TV webOS na rede? (DIAL HTTP unicast na 1926 —
    // imune a multicast; DLNA/SSDP desativado: multicast cego no Wi-Fi)
    try {
      final tvs = await WebosTvDialProbe.scan();
      if (tvs.isNotEmpty) {
        final tv = tvs.first;
        return 'TV detectada: ${tv.friendlyName} (${tv.ip}). '
            'Abra o app Palco nela pelo controle — ele conecta sozinho.';
      }
    } catch (_) {}
    return 'Nenhuma TV webOS na rede. Verifique TV e celular na mesma rede Wi-Fi.';
  }

  StreamSubscription<PalcoMessage>? _remoteKeySub;

  /// Acesso ao transporte Palco (áudio, vídeo, timer, eventos).
  /// Nulo quando ligado via DLNA.
  PalcoController? get palco => _palco;

  // ===== Roteamento de áudio (F3.2) =====
  // local: só celular | tv: só TV (celular = controle) | mirror: ambos.
  PalcoAudioRoute _audioRoute = PalcoAudioRoute.local;
  PalcoAudioRoute get audioRoute => _audioRoute;

  /// Troca o modo e notifica ouvintes (UI re-roteia a faixa corrente).
  set audioRoute(PalcoAudioRoute v) {
    if (_audioRoute == v) return;
    _audioRoute = v;
    notifyListeners();
  }

  /// Faixa corrente roteada (para re-enviar ao trocar o modo em runtime).
  String? _currentAudioUrl;
  String? _currentAudioTitle;
  String? _currentAudioSubtitle;
  String? _currentAudioCover;

  bool get _routesToTv => isPalcoMode && audioRoute != PalcoAudioRoute.local;

  /// Toca faixa no destino configurado. Retorna o modo efetivo
  /// (local quando palco desligado, independente da config).
  ///
  /// Fonte LOCAL (hino baixado, path /data/...) não é alcançável pela TV:
  /// os bytes são servidos via /media do sender e a URL substituída.
  PalcoAudioRoute playHymnAudio(
    String url, {
    String? title,
    String? subtitle,
    String? cover,
    String? background,
    Duration? position,
  }) {
    _currentAudioUrl = url;
    _currentAudioTitle = title;
    _currentAudioSubtitle = subtitle;
    _currentAudioCover = cover;
    if (!_routesToTv) return PalcoAudioRoute.local;
    final p = _audioTarget();
    var playable = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final file = File(url);
      if (file.existsSync()) {
        final name = 'hymn_${file.uri.pathSegments.last}'.replaceAll(
          RegExp(r'[^A-Za-z0-9._-]'),
          '_',
        );
        playable = p.serveMedia(name, file.readAsBytesSync()) ?? url;
        debugPrint('[PALCO] midia local servida: $playable');
      } else {
        debugPrint('[PALCO] ERRO: fonte local inexistente roteada: $url');
      }
    }
    p.playAudio(
      playable,
      title: title,
      subtitle: subtitle,
      cover: cover,
      background: background,
      position: position,
    );
    return audioRoute;
  }

  /// Alvo de áudio: slot ATIVO (a TV que recebe o som) — multi-palco.
  /// Áudio numa TV só (eco em várias); muda trocando o chip da tela ativa.
  PalcoController _audioTarget() {
    final t = _projectionTargets();
    if (t.isNotEmpty) return t.first;
    return _palco!;
  }

  /// Re-envia a faixa corrente com o modo novo (chamado ao trocar modo).
  void rerouteCurrentAudio() {
    if (_currentAudioUrl == null) return;
    if (!_routesToTv) {
      // voltou pra local: para na TV (player local segue por conta da UI)
      _audioTarget().stopAudio();
      return;
    }
    var url = _currentAudioUrl!;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final file = File(url);
      if (file.existsSync()) {
        final name = 'hymn_${file.uri.pathSegments.last}'.replaceAll(
          RegExp(r'[^A-Za-z0-9._-]'),
          '_',
        );
        url = _audioTarget().serveMedia(name, file.readAsBytesSync()) ?? url;
        debugPrint('[PALCO] reroute: local served as $url');
      } else {
        debugPrint('[PALCO] reroute ERROR: local not found: $url');
      }
    }
    _audioTarget().playAudio(
      url,
      title: _currentAudioTitle,
      subtitle: _currentAudioSubtitle,
      cover: _currentAudioCover,
    );
  }

  void pauseHymnAudio() {
    if (_routesToTv) {
      for (final p in _allConnectedControllers()) {
        p.pauseAudio();
      }
    }
  }

  void stopHymnAudio() {
    // Para em TODOS os slots conectados: a faixa pode ter começado em
    // outro slot antes da troca de chip ativo (bug 2026-08-21).
    if (_routesToTv) {
      for (final p in _allConnectedControllers()) {
        p.stopAudio();
      }
    }
  }

  /// Todos os controllers com TV conectada (qualquer slot).
  List<PalcoController> _allConnectedControllers() {
    final orch = PalcoOrchestrator.instance;
    return orch.slots
        .map((s) => s.controller)
        .where((c) => c.isConnected)
        .toList();
  }

  /// Seek espelhado (modo tv: a TV é o relógio; local/mirror: no-op
  /// porque o player local já é a fonte).
  void seekHymnAudio(Duration position) {
    if (audioRoute == PalcoAudioRoute.tv && isPalcoMode) {
      _audioTarget().seekAudio(position.inMilliseconds / 1000.0);
    }
  }

  /// Liga o palco: conecta na TV e projeta o IDLE (background definido).
  // ===== Apresentação de slides (PPTX/images) no Palco — F3.3i =====
  // Extraí as imagens do .pptx (ZIP ppt/media/*), serve via /media e
  // projeta como sequência. Setas do controle da TV navegam.
  List<String> _slideUrls = [];
  int _slideIndex = -1;

  /// Projeta o slide [index] da sequência carregada.
  void _projectSlide(int index) {
    if (index < 0 || index >= _slideUrls.length) return;
    _slideIndex = index;
    for (final p in _projectionTargets()) {
      p.project(text: '', footer: '', background: _slideUrls[index]);
    }
  }

  /// Carrega e projeta a 1a imagem de slides extraídos de um .pptx.
  /// Retorna a quantidade de slides projetados (0 = nada extraído).
  int projectPptxSlides(String pptxPath) {
    final slides = PptxSlideExtractor.extract(pptxPath);
    if (slides.isEmpty || _palco == null) return 0;
    _slideUrls = slides
        .map(
          (s) => _projectionTargets().isNotEmpty
              ? _projectionTargets().first.serveMedia(
                  'slide_${s.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}',
                  s.bytes,
                )
              : null,
        )
        .whereType<String>()
        .toList();
    _projectSlide(0);
    return _slideUrls.length;
  }

  /// Navegação next/prev da sequência de slides (setas do controle).
  /// No ÚLTIMO slide, next encerra a apresentação → idle (F3.3k).
  bool navigateSlides(String direction) {
    if (_slideUrls.isEmpty) return false;
    if (direction == 'next') {
      if (_slideIndex < _slideUrls.length - 1) {
        _projectSlide(_slideIndex + 1);
        return true;
      }
      stopSlides(); // último slide + next → volta pro palco (idle)
      return true;
    }
    if (direction == 'prev' && _slideIndex > 0) {
      _projectSlide(_slideIndex - 1);
      return true;
    }
    return false;
  }

  /// Encerra a apresentação de slides (volta ao idle).
  void stopSlides() {
    _slideUrls = [];
    _slideIndex = -1;
    for (final p in _projectionTargets()) {
      p.projectIdle();
    }
  }

  /// Para o cronômetro na(s) tela(s) de destino (multi-palco).
  /// Chamado pela UI do Timer (pause/stop) — NÃO usar palco.stopTimer()
  /// direto: isso mandaria só pro sender principal.
  void stopTimerStage() {
    for (final p in _projectionTargets()) {
      p.stopTimer();
    }
  }

  /// F3.3k: toca vídeo no palco. Arquivo local → serveMedia; URL externa
  /// → proxy do sender (mixed content + headers da API).
  bool playVideoOnStage(String pathOrUrl) {
    if (_palco == null) return false;
    var url = pathOrUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final file = File(url);
      if (!file.existsSync()) return false;
      final name = 'video_${file.uri.pathSegments.last}'.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      final served = _audioTarget().serveMedia(name, file.readAsBytesSync());
      if (served == null) return false;
      url = served;
    }
    for (final p in _projectionTargets()) {
      p.playVideo(url);
    }
    _videoOnStage = true;
    notifyListeners();
    return true;
  }

  /// F3.3w: interrompe o vídeo rodando no palco (volta ao idle).
  /// Usado pelo botão "Parar vídeo" quando um item de vídeo da liturgia
  /// está em execução na TV.
  void stopVideoOnStage() {
    _videoOnStage = false;
    notifyListeners();
    for (final p in _projectionTargets()) {
      p.stopVideo();
    }
  }

  /// F3.3w: true enquanto um vídeo projetado pela liturgia roda na TV.
  bool _videoOnStage = false;
  bool get isVideoOnStage => _videoOnStage;
  bool _stageVideoPaused = false;
  bool get isStageVideoPaused => _stageVideoPaused;

  /// Pausa/continua o vídeo da liturgia rodando na TV (via APK).
  void toggleStageVideoPause() {
    _stageVideoPaused = !_stageVideoPaused;
    notifyListeners();
    for (final p in _projectionTargets()) {
      p.toggleVideoPause();
    }
  }

  /// Projeta conteúdo no palco. Sobrescreve o anterior.
  /// Inicia cronômetro com personalização salva no módulo Timer.
  Future<void> startTimer({
    required int duration,
    required String mode,
    required String label,
  }) async {
    if (!isOn || !isPalcoMode || _palco == null) return;
    final s =
        await StageSettingsRepository(scope: 'timer').loadOptional() ??
        settings;
    // Multi-palco: timer vai pro(s) mesmo(s) alvo(s) da projeção.
    for (final p in _projectionTargets()) {
      p.startTimer(
        duration: duration,
        mode: mode,
        label: label,
        color:
            '#${s.textColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
        fontSize: s.fontSize,
        fontWeight: s.fontWeight.value,
        textShadow: s.textShadow,
        shadowBlur: s.shadowBlur,
        shadowIntensity: s.shadowIntensity,
        textAlign: s.textAlign,
        textVerticalAlign: s.textVerticalAlign,
      );
    }
  }

  /// Liga o palco: conecta na TV e projeta o IDLE (background definida).
  Future<bool> turnOn(DlnaRenderer tv) async {
    settings = await _settingsRepo.load();
    final ok = await _cast.connect(tv);
    if (!ok) return false;
    renderer = tv;
    settings = settings.copyWith(capability: tv.screenCapability);
    try {
      await _loadBackground();
      await _projectIdle();
    } catch (e, st) {
      debugPrint(
        '[DLNA] turnOn(): falha em loadBackground/projectIdle: '
        '$e\n$st',
      );
    }
    notifyListeners();
    return true;
  }

  Future<void> turnOff() async {
    if (_palco != null) {
      _remoteKeySub?.cancel();
      _remoteKeySub = null;
      _palco = null;
      // Multi-palco: desconexão passa pelo orchestrator (mantém slot e
      // estado do gerenciador de telas coerentes).
      await PalcoOrchestrator.instance.disconnectAll();
    } else {
      await _cast.disconnect();
    }
    renderer = null;
    _backgroundImage?.dispose();
    _backgroundImage = null;
    notifyListeners();
  }

  /// Carrega a imagem de fundo personalizada (persistida) em memória.
  Future<void> _loadBackground() async {
    final bytes = await _settingsRepo.loadBackgroundImage();
    if (bytes == null) {
      _backgroundImage = null;
      return;
    }
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _backgroundImage?.dispose();
      _backgroundImage = frame.image;
    } catch (_) {
      _backgroundImage = null;
    }
  }

  /// Define nova imagem de fundo (path escolhido pelo usuário),
  /// persiste e re-projeta se ligado. F3.3m: no modo Palco WS o BG do
  /// usuário vira o bgPalco (body do palco) servido via /media.
  Future<void> setBackgroundFromFile(
    String path, {
    String scope = 'global',
  }) async {
    final repo = StageSettingsRepository(scope: scope);
    final saved = await repo.saveBackgroundImage(path);
    if (saved == null) return;
    await _loadBackground();
    if (isPalcoMode) {
      final bytes = await repo.loadBackgroundImage();
      if (bytes != null && _palco != null) {
        final ext = path.split('.').last.toLowerCase();
        final url = _palco!.serveMedia(
          'palco_bg.${ext == 'jpg' ? 'jpg' : 'png'}',
          bytes,
        );
        if (url != null) {
          _palco!.setPalcoBackground(url);
          return; // bgPalco aplicado; idle já mostra por trás
        }
      }
    }
    await refresh();
  }

  /// Define BG vindo da galeria oficial empacotada.
  Future<void> setBackgroundBytes(
    Uint8List bytes, {
    String scope = 'global',
  }) async {
    final repo = StageSettingsRepository(scope: scope);
    final saved = await repo.saveBackgroundBytes(bytes);
    if (saved == null) return;
    await _loadBackground();
    if (isPalcoMode) {
      final loaded = await repo.loadBackgroundImage();
      final url = loaded == null
          ? null
          : _palco?.serveMedia('palco_bg.png', loaded);
      if (url != null) {
        _palco!.setPalcoBackground(url);
        return;
      }
    }
    await refresh();
  }

  Future<void> updateSettings(StageSettings s) async {
    settings = s;
    await _settingsRepo.save(s);
    await refresh();
  }

  /// Re-projeta o que estiver em cena (ou idle).
  Future<void> refresh() async {
    if (!isOn) return;
    final current = _lastContent;
    if (current != null) {
      await _project(current);
    } else {
      await _projectIdle();
    }
  }

  // Conteúdo atual em cena (para refresh pós-mudança de visual).
  _StageContent? _lastContent;

  /// Projeta conteúdo no palco. Sobrescreve o anterior.
  Future<bool> project({
    required String title,
    String? body,
    String? footer,
    String? background,
    String? footerRef,
    String? footerVersion,
    bool isBible = false,
    String module = 'hymns',
  }) async {
    if (!isOn) return false;
    final content = _StageContent(
      title: title,
      body: body,
      footer: footer,
      module: module,
      isBible: isBible,
    );
    _lastContent = content;
    if (isPalcoMode) {
      // Palco WS: texto nativo (body com \n vira <br> no receiver).
      final text = [
        title,
        body,
      ].whereType<String>().where((s) => s.isNotEmpty).join('<br><br>');
      // F3.3m/o: estilos da letra (sombra/caixinha) e footer destacado.
      // Bíblia tem tipografia PRÓPRIA (tamanho/peso/cor) — diferente da música.
      // Override do módulo vence; sem arquivo próprio, herda padrão global.
      final s =
          await StageSettingsRepository(scope: module).loadOptional() ??
          settings;
      final fSize = isBible ? s.bibleFontSize : s.fontSize;
      final fWeight = isBible ? s.bibleFontWeight : s.fontWeight.value;

      // Multi-palco: espelho → todos do grupo; senão slot ATIVO (conteúdo
      // diferente por tela). Fallback: transporte da sessão (principal).
      final targets = _projectionTargets();
      for (final p in targets) {
        _projectToController(
          p,
          text: _colorize(text, isBible ? s.bibleTextColor : s.textColor),
          footer: footer ?? '',
          background: background,
          footerRef: footerRef,
          footerVersion: (s.showBibleVersion && footerVersion != null)
              ? footerVersion
              : null,
          fSize: fSize,
          fWeight: fWeight,
          s: s,
        );
      }
      return targets.isNotEmpty;
    }
    return _project(content);
  }

  /// Controllers que recebem a projeção (multi-palco).
  List<PalcoController> _projectionTargets() {
    final orch = PalcoOrchestrator.instance;
    if (orch.isMirrorMode) {
      final group = orch.mirrorGroup!;
      debugPrint(
        '[MULTI] espelho: slots=$group conectados='
        '${group.map((id) => '${orch.slot(id)?.label}:${orch.slot(id)?.isConnected}')}',
      );
      return group
          .map((id) => orch.slot(id)?.controller)
          .whereType<PalcoController>()
          .where((c) => c.isConnected)
          .toList();
    }
    final activeSlot = orch.activeSlot;
    final active = activeSlot?.controller;
    debugPrint(
      '[MULTI] ativo=${activeSlot?.label}(${activeSlot?.wsPort}) '
      'connected=${activeSlot?.isConnected} '
      'todos=${orch.slots.map((s) => '${s.label}:${s.isConnected}@${s.wsPort}')} '
      'fallback=${_palco != null && (active == null || !active.isConnected)}',
    );
    if (active != null && active.isConnected) return [active];
    return _palco != null ? [_palco!] : const [];
  }

  void _projectToController(
    PalcoController p, {
    required String text,
    required String footer,
    String? background,
    String? footerRef,
    String? footerVersion,
    required double fSize,
    required int fWeight,
    required StageSettings s,
  }) {
    p.project(
      text: text,
      footer: footer,
      background: background,
      footerRef: footerRef,
      footerColor:
          '#${s.footerRefColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      footerWeight: s.footerRefWeight,
      footerVersion: footerVersion,
      textShadow: s.textShadow,
      shadowBlur: s.shadowBlur,
      shadowIntensity: s.shadowIntensity,
      textBox: s.textBox,
      boxOpacity: s.boxOpacity,
      boxBorder: s.boxBorder
          ? {'width': 0.4, 'color': 'rgba(255,255,255,.25)'}
          : null,
      fontSize: fSize,
      fontWeight: fWeight,
    );
  }

  /// Envolve o texto em <span style="color"> preservando <br>.
  String _colorize(String text, Color c) {
    final hex = '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    return '<span style="color:$hex">$text</span>';
  }

  /// Volta ao idle (background aguardando mídia).
  Future<void> clearContent() async {
    _lastContent = null;
    if (!isOn) return;
    // F3.3p: limpa TAMBÉM sequência de slides/timer pendentes.
    _slideUrls = [];
    _slideIndex = -1;
    _palco?.stopTimer();
    if (isPalcoMode) {
      // Multi-palco: idle nos mesmos targets da projeção.
      for (final p in _projectionTargets()) {
        p.projectIdle();
      }
      return;
    }
    await _projectIdle();
  }

  Future<bool> _project(_StageContent c) async {
    if (_busy) return true; // projeção em andamento: mantém a última
    _busy = true;
    try {
      var bytes = await StageSlidePainter.renderGeneric(
        title: c.title,
        body: c.body,
        footer: c.footer,
        settings: settings,
        backgroundImage: _backgroundImage,
      );
      // Compatibilidade máxima: sinks sem PNG recebem JPEG (universal).
      if (_cast.imageFormat == StageImageFormat.jpeg) {
        bytes = _encodeJpeg(bytes);
      }
      return await _cast.projectSlide(bytes, title: c.title);
    } finally {
      _busy = false;
    }
  }

  /// PNG (RGBA do rasterizador) → JPEG (qualidade 90) via pacote image.
  static Uint8List _encodeJpeg(Uint8List pngBytes) {
    final img = image.decodePng(pngBytes);
    if (img == null) return pngBytes; // improvável: segue PNG
    return Uint8List.fromList(image.encodeJpg(img, quality: 90));
  }

  Future<void> _projectIdle() async {
    var bytes = await StageSlidePainter.renderGeneric(
      title: '',
      body: '',
      footer: 'stage.waiting'.tr(),
      settings: settings,
      backgroundImage: _backgroundImage,
    );
    if (_cast.imageFormat == StageImageFormat.jpeg) {
      bytes = _encodeJpeg(bytes);
    }
    await _cast.projectSlide(bytes, title: 'Palco');
  }
}

class _StageContent {
  final String title;
  final String? body;
  final String? footer;
  final String module;
  final bool isBible;
  const _StageContent({
    required this.title,
    this.body,
    this.footer,
    this.module = 'hymns',
    this.isBible = false,
  });
}
