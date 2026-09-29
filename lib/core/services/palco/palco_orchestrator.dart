library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:flutter/material.dart' show Color;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'palco_controller.dart';
import 'palco_slot.dart';
import 'palco_models.dart';
import '../dlna/stage_settings_repository.dart';
import '../dlna/slide_http_server.dart';
import '../dlna/webos_tv_dial_probe.dart';
import '../palco/palco_foreground.dart';

/// Orquestra N slots de Palco (multi-TV independente ou espelho).
///
/// Substitui o singleton StageSession como gerenciador central.
/// StageSession vira facade que delega pra esta classe.
class PalcoOrchestrator extends ChangeNotifier {
  PalcoOrchestrator._();
  static final PalcoOrchestrator instance = PalcoOrchestrator._();

  final Map<String, PalcoSlot> _slots = {};
  static const _slotsKey = 'palco.multi.slots.v1';
  static const _activeKey = 'palco.multi.active.v1';
  bool _loaded = false;

  /// Restaura telas salvas. Senders são ligados quando o palco abre.
  Future<void> loadStoredConfig() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await _prefs();
    if (prefs == null) return;
    final raw = prefs.getString(_slotsKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).whereType<Map>();
      for (final item in list) {
        final id = item['id'] as String?;
        final label = item['label'] as String?;
        final slotIndex = item['slotIndex'] as int?;
        if (id != null && label != null) {
          addSlot(id: id, label: label, slotIndex: slotIndex, persist: false);
        }
      }
    }
    final active = prefs.getString(_activeKey);
    if (active != null && _slots.containsKey(active)) _activeSlotId = active;
    notifyListeners();
  }

  /// SharedPreferences best-effort: em teste (sem binding) devolve null.
  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistConfig() async {
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.setString(
      _slotsKey,
      jsonEncode(
        _slots.values
            .map(
              (s) => {
                'id': s.id,
                'label': s.label,
                'slotIndex': s.slotIndex,
                'httpPort': s.httpPort,
                'wsPort': s.wsPort,
              },
            )
            .toList(),
      ),
    );
    if (_activeSlotId != null) {
      await prefs.setString(_activeKey, _activeSlotId!);
    }
  }

  /// Slot ativo — onde as projeções dos módulos vão.
  String? _activeSlotId;
  String? get activeSlotId => _activeSlotId;
  PalcoSlot? get activeSlot =>
      _activeSlotId != null ? _slots[_activeSlotId] : null;

  /// Slots em modo espelho (null = modo independente).
  Set<String>? mirrorGroup;
  bool get isMirrorMode => mirrorGroup != null && mirrorGroup!.isNotEmpty;

  /// Slots ordenados por índice.
  List<PalcoSlot> get slots =>
      _slots.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  /// Slot por ID.
  PalcoSlot? slot(String id) => _slots[id];

  /// Quantidade de slots conectados.
  int get connectedCount => _slots.values.where((s) => s.isConnected).length;

  /// Alguma TV conectada? (compat StageSession.isOn)
  bool get anyConnected => connectedCount > 0;

  /// Max de slots suportados.
  static const maxSlots = 4;

  // ===== Gerenciamento de Slots =====

  /// Cria um novo slot. Retorna false se atingiu o limite.
  bool addSlot({
    required String id,
    String? label,
    int? slotIndex,
    bool persist = true,
  }) {
    if (_slots.length >= maxSlots) return false;
    if (_slots.containsKey(id)) return false;
    // A porta é identidade do slot: nunca recalcular pela ordem do Map ao
    // restaurar. Slots antigos sem índice usam primeiro índice livre.
    final used = _slots.values.map((s) => s.slotIndex).toSet();
    final index =
        slotIndex ??
        List<int>.generate(
          maxSlots,
          (i) => i,
        ).firstWhere((i) => !used.contains(i), orElse: () => -1);
    if (index < 0 || index >= maxSlots || used.contains(index)) return false;
    final slot = PalcoSlot(id: id, label: label ?? id, slotIndex: index);
    slot.addListener(_onSlotChanged);
    _slots[id] = slot;
    // Primeiro slot vira ativo automaticamente
    _activeSlotId ??= id;
    notifyListeners();
    if (persist) unawaited(_persistConfig());
    debugPrint('[ORCH] slot criado: $id (${slot.httpPort}/${slot.wsPort})');
    return true;
  }

  /// Adiciona slot e JÁ liga o sender (TV pode conectar em seguida).
  /// Sem isso o slot ficava "desconectado" para sempre: o sender nunca
  /// escutava a porta do slot (bug multi-palco 2026-08-21).
  Future<bool> addSlotOnline({required String id, String? label}) async {
    if (!addSlot(id: id, label: label)) return false;
    await SlideHttpServer.resolveLocalIp();
    final localIp = SlideHttpServer.localIp;
    if (localIp == null) return false;
    return connectTv(id, PalcoTarget(name: label ?? id, ip: localIp));
  }

  /// Remove slot e desconecta a TV.
  Future<void> removeSlot(String id) async {
    final slot = _slots[id];
    if (slot == null) return;
    await slot.disconnect();
    slot.removeListener(_onSlotChanged);
    _slots.remove(id);
    mirrorGroup?.remove(id);
    if (_activeSlotId == id) {
      _activeSlotId = _slots.keys.firstOrNull;
    }
    if (mirrorGroup?.isEmpty ?? false) mirrorGroup = null;
    unawaited(_persistConfig());
    notifyListeners();
    debugPrint('[ORCH] slot removido: $id');
  }

  /// Renomeia um slot.
  void renameSlot(String id, String newLabel) {
    _slots[id]?.label = newLabel;
    notifyListeners();
  }

  /// Define o slot ativo.
  void setActiveSlot(String id) {
    if (!_slots.containsKey(id)) {
      debugPrint('[ORCH] setActiveSlot($id): SLOT INEXISTENTE');
      return;
    }
    _activeSlotId = id;
    unawaited(_persistConfig());
    debugPrint('[ORCH] slot ativo agora: $id');
    notifyListeners();
  }

  /// Liga/desliga modo espelho. Se ids vazio, espelha todos conectados.
  void toggleMirror(Set<String>? ids) {
    if (ids != null && ids.isNotEmpty) {
      mirrorGroup = ids;
    } else {
      // Espelha todos conectados
      final connected = _slots.values
          .where((s) => s.isConnected)
          .map((s) => s.id)
          .toSet();
      if (connected.length < 2) return; // espelho precisa 2+
      mirrorGroup = connected;
    }
    notifyListeners();
  }

  void clearMirror() {
    mirrorGroup = null;
    notifyListeners();
  }

  void _onSlotChanged() {
    // Re-forward notificação do slot para ouvintes do orchestrator
    notifyListeners();
  }

  // ===== Conexão =====

  /// Conecta uma TV num slot existente.
  Future<bool> connectTv(String slotId, PalcoTarget tv) async {
    final s = _slots[slotId];
    if (s == null) return false;
    final ok = await s.connect(tv);
    if (ok) {
      unawaited(PalcoForeground.start());
      try {
        await WakelockPlus.enable();
      } catch (_) {}
      // Configura foreground service se precisar
      _setupRemoteKeys(s);
    }
    return ok;
  }

  /// Liga senders de slots salvos para TVs poderem reconectar sem reconfigurar.
  Future<void> startStoredSenders({String? excludeId}) async {
    await SlideHttpServer.resolveLocalIp();
    final ip = SlideHttpServer.localIp;
    if (ip == null) return;
    for (final s in _slots.values) {
      if (s.id == excludeId || s.controller.isRunning) continue;
      await s.controller.connect(PalcoTarget(name: s.label, ip: ip));
    }
  }

  /// Desconecta uma TV de um slot.
  Future<void> disconnectTv(String slotId) async {
    await _slots[slotId]?.disconnect();
    if (connectedCount == 0) {
      unawaited(PalcoForeground.stop());
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }
  }

  /// Desconecta todas as TVs.
  Future<void> disconnectAll() async {
    for (final s in _slots.values.toList()) {
      await s.disconnect();
    }
    mirrorGroup = null;
    unawaited(PalcoForeground.stop());
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    notifyListeners();
  }

  StreamSubscription<PalcoMessage>? _remoteKeySub;

  void _setupRemoteKeys(PalcoSlot s) {
    _remoteKeySub?.cancel();
    _remoteKeySub = s.controller.events.listen((m) {
      // Por enquanto, remote keys só funcionam no slot ativo
      // (navegação de slides). Depois pode ser por slot.
      if (m.type == 'remote-key' && m.fields['key'] is String) {
        // TODO: notificar módulo ativo sobre navegação
      }
      if (m.type == 'ended' && m.fields['media'] == 'video') {
        // TODO: notificar sobre vídeo terminado
      }
    });
  }

  // ===== Projeção =====

  /// Projetar no slot ativo (ou em todos se espelho).
  /// Esta é a API que os módulos chamam.
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
    if (!anyConnected) return false;

    final targets = _projectionTargets();
    if (targets.isEmpty) return false;

    final results = await Future.wait(
      targets.map(
        (s) => _projectToSlot(
          s,
          title: title,
          body: body,
          footer: footer,
          footerRef: footerRef,
          footerVersion: footerVersion,
          isBible: isBible,
          module: module,
          background: background,
        ),
      ),
    );
    return results.any((ok) => ok);
  }

  /// Projetar num slot específico (por ID).
  Future<bool> projectToSlot(
    String slotId, {
    required String title,
    String? body,
    String? footer,
    String? footerRef,
    String? footerVersion,
    bool isBible = false,
    String module = 'hymns',
    String? background,
  }) async {
    final s = _slots[slotId];
    if (s == null || !s.isConnected) return false;
    return _projectToSlot(
      s,
      title: title,
      body: body,
      footer: footer,
      footerRef: footerRef,
      footerVersion: footerVersion,
      isBible: isBible,
      module: module,
      background: background,
    );
  }

  /// Targets de projeção: espelho (grupo) ou slot ativo.
  List<PalcoSlot> _projectionTargets() {
    if (isMirrorMode) {
      return mirrorGroup!
          .map((id) => _slots[id])
          .whereType<PalcoSlot>()
          .where((s) => s.isConnected)
          .toList();
    }
    final a = activeSlot;
    if (a != null && a.isConnected) return [a];
    return [];
  }

  Future<bool> _projectToSlot(
    PalcoSlot s, {
    required String title,
    String? body,
    String? footer,
    String? background,
    String? footerRef,
    String? footerVersion,
    bool isBible = false,
    String module = 'hymns',
  }) async {
    final ctrl = s.controller;
    final settings = s.settings;
    final text = [
      title,
      body,
    ].whereType<String>().where((t) => t.isNotEmpty).join('<br><br>');

    // BG do slide > BG do módulo > BG global > null (receiver usa fallback)
    String? effectiveBackground = background;
    if (effectiveBackground == null) {
      final moduleBg = await StageSettingsRepository(
        scope: module,
      ).loadBackgroundImage();
      final globalBg = await StageSettingsRepository(
        scope: 'global',
      ).loadBackgroundImage();
      if (moduleBg != null) {
        effectiveBackground = ctrl.serveMedia('bg-$module.png', moduleBg);
      } else if (globalBg != null) {
        effectiveBackground = ctrl.serveMedia('bg-global.png', globalBg);
      }
    }

    final fSize = isBible ? settings.bibleFontSize : settings.fontSize;
    final fWeight = isBible
        ? settings.bibleFontWeight
        : settings.fontWeight.value;
    final textColor = isBible ? settings.bibleTextColor : settings.textColor;

    ctrl.project(
      text: _colorize(text, textColor),
      footer: footer ?? '',
      background: effectiveBackground,
      footerRef: footerRef,
      footerColor:
          '#${settings.footerRefColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      footerWeight: settings.footerRefWeight,
      footerVersion: (settings.showBibleVersion && footerVersion != null)
          ? footerVersion
          : null,
      textShadow: settings.textShadow,
      shadowBlur: settings.shadowBlur,
      shadowIntensity: settings.shadowIntensity,
      textBox: settings.textBox,
      boxOpacity: settings.boxOpacity,
      boxBorder: settings.boxBorder
          ? {'width': 0.4, 'color': 'rgba(255,255,255,.25)'}
          : null,
      textAlign: settings.textAlign,
      textVerticalAlign: settings.textVerticalAlign,
      fontSize: fSize,
      fontWeight: fWeight,
    );
    return true;
  }

  /// Limpa conteúdo (idle) em todos os slots conectados.
  Future<void> clearAll() async {
    for (final s in _slots.values) {
      if (s.isConnected) s.controller.projectIdle();
    }
  }

  /// Limpa conteúdo em slot específico.
  void clearSlot(String slotId) {
    _slots[slotId]?.controller.projectIdle();
  }

  /// Volta ao idle nos targets de projeção atuais.
  Future<void> clearContent() async {
    for (final s in _projectionTargets()) {
      s.controller.projectIdle();
    }
  }

  // ===== Áudio (sempre no slot ativo ou slot designado) =====

  PalcoAudioRoute _audioRoute = PalcoAudioRoute.local;
  PalcoAudioRoute get audioRoute => _audioRoute;
  String? _audioSlotId; // slot que recebe áudio (null = ativo)

  set audioRoute(PalcoAudioRoute v) {
    if (_audioRoute == v) return;
    _audioRoute = v;
    notifyListeners();
  }

  /// Designa qual slot recebe áudio.
  void setAudioSlot(String? id) {
    _audioSlotId = id;
  }

  PalcoSlot? get _audioSlot {
    if (_audioSlotId != null) return _slots[_audioSlotId];
    return activeSlot;
  }

  bool get _routesAudioToTv {
    final s = _audioSlot;
    return s != null && s.isConnected && audioRoute != PalcoAudioRoute.local;
  }

  PalcoAudioRoute playHymnAudio(
    String url, {
    String? title,
    String? subtitle,
    String? cover,
    String? background,
    Duration? position,
  }) {
    if (!_routesAudioToTv) return PalcoAudioRoute.local;
    final ctrl = _audioSlot!.controller;
    var playable = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final file = File(url);
      if (file.existsSync()) {
        final name = 'hymn_${file.uri.pathSegments.last}'.replaceAll(
          RegExp(r'[^A-Za-z0-9._-]'),
          '_',
        );
        playable = ctrl.serveMedia(name, file.readAsBytesSync()) ?? url;
      }
    }
    ctrl.playAudio(
      playable,
      title: title,
      subtitle: subtitle,
      cover: cover,
      background: background,
      position: position,
    );
    return audioRoute;
  }

  void pauseHymnAudio() {
    if (_routesAudioToTv) _audioSlot!.controller.pauseAudio();
  }

  void stopHymnAudio() {
    if (_routesAudioToTv) _audioSlot!.controller.stopAudio();
  }

  void seekHymnAudio(Duration position) {
    if (audioRoute == PalcoAudioRoute.tv &&
        _audioSlot != null &&
        _audioSlot!.isConnected) {
      _audioSlot!.controller.seekAudio(position.inMilliseconds / 1000.0);
    }
  }

  // ===== Timer (sempre no slot ativo) =====

  Future<void> startTimer({
    required int duration,
    required String mode,
    required String label,
  }) async {
    final s = activeSlot;
    if (s == null || !s.isConnected) return;
    final settings = s.settings;
    s.controller.startTimer(
      duration: duration,
      mode: mode,
      label: label,
      color:
          '#${settings.textColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      fontSize: settings.fontSize,
      fontWeight: settings.fontWeight.value,
      textShadow: settings.textShadow,
      shadowBlur: settings.shadowBlur,
      shadowIntensity: settings.shadowIntensity,
      textAlign: settings.textAlign,
      textVerticalAlign: settings.textVerticalAlign,
    );
  }

  void stopTimer() {
    activeSlot?.controller.stopTimer();
  }

  // ===== Vídeo (sempre no slot ativo) =====

  bool playVideoOnStage(String pathOrUrl) {
    final s = activeSlot;
    if (s == null || !s.isConnected) return false;
    var url = pathOrUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final file = File(url);
      if (!file.existsSync()) return false;
      final name = 'video_${file.uri.pathSegments.last}'.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      final served = s.controller.serveMedia(name, file.readAsBytesSync());
      if (served == null) return false;
      url = served;
    }
    s.controller.playVideo(url);
    notifyListeners();
    return true;
  }

  void stopVideoOnStage() {
    activeSlot?.controller.stopVideo();
    notifyListeners();
  }

  void toggleStageVideoPause() {
    activeSlot?.controller.toggleVideoPause();
    notifyListeners();
  }

  // ===== Helper =====

  String _colorize(String text, Color c) {
    final hex = '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    return '<span style="color:$hex">$text</span>';
  }

  /// Detecta TVs na rede (DIAL unicast).
  Future<String?> checkTvNeedsPalcoOpen() async {
    for (var i = 0; i < 16; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (anyConnected && _slots.values.any((s) => s.isConnected)) return null;
    }
    try {
      final tvs = await WebosTvDialProbe.scan();
      if (tvs.isNotEmpty) {
        final tv = tvs.first;
        return 'TV detectada: ${tv.friendlyName} (${tv.ip}). '
            'Abra o app Palco nela pelo controle.';
      }
    } catch (_) {}
    return 'Nenhuma TV webOS na rede.';
  }

  /// Projeta idle nos targets.
  Future<void> projectIdle() async {
    for (final s in _projectionTargets()) {
      s.controller.projectIdle();
    }
  }
}
