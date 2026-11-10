library;

import 'dart:convert';
import 'dart:math';

import 'remote_announcements_state.dart';
export 'remote_announcements_state.dart';

/// Protocolo "LouvorJA Remote v1" — JSON sobre WebSocket.
///
/// Envelope único, bidirecional. O APK é cliente quando controla o Desktop
/// (Electron = servidor WS :48080) e servidor quando controla o Web
/// (browser não aceita conexão de entrada → conecta no APK).
///
/// Regras (SPEC ~/.hermes/specs/2026-08-16-controle-remoto-apk.md):
/// - `v` SEMPRE 1; `v` diferente = mensagem de peer futuro → ignorar.
/// - Comandos são idempotentes e exigem ack; sem ack em 3s = erro de UI.
/// - Estado é COMPLETO (não delta) — reconexão resync total.
/// - Parser nunca lança: entrada inválida → null (peer ruim não derruba app).

const remoteDesktopDefaultPort = 48080;

enum RemoteAction {
  announcementsSelectList('announcements.selectList'),
  announcementsOpen('announcements.open'),
  announcementsInclude('announcements.include'),
  announcementsSetCarousel('announcements.setCarousel'),
  announcementsStart('announcements.start'),
  announcementsPause('announcements.pause'),
  announcementsResume('announcements.resume'),
  announcementsNext('announcements.next'),
  announcementsPrevious('announcements.previous'),
  announcementsStop('announcements.stop'),
  play('player.play'),
  pause('player.pause'),
  toggle('player.toggle'),
  next('player.next'),
  previous('player.previous'),
  stop('player.stop'),
  setVolume('player.setVolume'),
  seek('player.seek'),
  setMode('player.setMode'),
  open('player.open'),
  // Liturgia no desktop — prioridade (multiplos monitores + projetor).
  liturgyNext('liturgy.next'),
  liturgyPrevious('liturgy.previous'),
  liturgySelect('liturgy.select'),
  liturgyOpen('liturgy.open'),
  // Troca o dia aberto no desktop; o dia vai em `mode`.
  liturgySelectDay('liturgy.selectDay'),
  // Abre uma liturgia avulsa; o índice vai em `value`.
  liturgySelectCustom('liturgy.selectCustom'),

  /// Navegador do celular: o site projetado no desktop abre o mesmo endereço.
  siteNavigate('site.navigate'),

  /// Rolagem do navegador do celular, em proporção da página (0..1).
  siteScroll('site.scroll'),
  liturgyToggleDone('liturgy.toggleDone'),
  liturgyState('liturgy.state'),
  // Controle remoto total (v2 — spec Obsidian "Controle Remoto Total v2").
  bibleOpen('bible.open'),
  bibleSelect('bible.select'),
  bibleSelectVerse('bible.selectVerse'),
  bibleClearSelection('bible.clearSelection'),
  bibleClose('bible.close'),
  timerStart('timer.start'),
  timerPause('timer.pause'),
  timerReset('timer.reset'),
  timerSaveMark('timer.saveMark'),
  timerRemoveMark('timer.removeMark'),
  timerClearMarks('timer.clearMarks'),
  timerToggleProjection('timer.toggleProjection'),
  countdownStart('countdown.start'),
  countdownPause('countdown.pause'),
  countdownReset('countdown.reset'),
  countdownSaveMark('countdown.saveMark'),
  countdownSetDuration('countdown.setDuration'),
  countdownToggleProjection('countdown.toggleProjection'),
  // Fase 2 — clock e random.
  clockSetConfig('clock.setConfig'),
  clockToggleProjection('clock.toggleProjection'),
  randomSetMode('random.setMode'),
  randomAddName('random.addName'),
  randomRemoveAvailable('random.removeAvailable'),
  randomClearAvailable('random.clearAvailable'),
  randomGenerateNumberRange('random.generateNumberRange'),
  randomStartDraw('random.startDraw'),
  randomCancelDraw('random.cancelDraw'),
  randomClearHistory('random.clearHistory'),
  randomResetAll('random.resetAll'),
  randomToggleProjection('random.toggleProjection'),
  randomSetNumberRange('random.setNumberRange'),
  randomImportNames('random.importNames'),
  randomRemoveDrawn('random.removeDrawn'),
  // Fase 3 — hinos/mídia.
  mediaOpen('media.open'),
  mediaSearch('media.search'),
  // Navegação de PDF/PPT/imagens/letra na superfície ativa do desktop.
  slideNext('slide:next'),
  slidePrevious('slide:prev'),
  // Recursos da barra de vídeo do desktop.
  videoSetAudioOutput('video.setAudioOutput'),
  videoToggleProjection('video.toggleProjection'),
  videoToggleCaptions('video.toggleCaptions'),
  videoSetTarget('video.setTarget'),
  videoSetIndependentMode('video.setIndependentMode'),
  videoSetIndependentTarget('video.setIndependentTarget');

  const RemoteAction(this.wire);
  final String wire;

  static RemoteAction? fromWire(String? wire) {
    if (wire == null) return null;
    for (final a in RemoteAction.values) {
      if (a.wire == wire) return a;
    }
    return null;
  }
}

/// Modos aceitos por setMode/open (espelham o Media.js do desktop).
const kRemoteModes = {'audio', 'instrumental', 'video'};

sealed class RemoteMessage {
  const RemoteMessage();

  String encode();
}

/// APK → alvo: comando de player.
class RemoteCommand extends RemoteMessage {
  RemoteCommand({
    required this.id,
    required this.action,
    this.token,
    this.volume,
    this.position,
    this.mode,
    this.hymnId,
    this.index,
    this.versionId,
    this.bookId,
    this.chapter,
    this.verse,
    this.durationMs,
    this.name,
    this.style,
    this.showSeconds,
    this.format24h,
    this.musicId,
    this.query,
    this.numberMin,
    this.numberMax,
    this.namesText,
    this.targetId,
    this.enabled,
    this.url,
    this.ratio,
  }) : assert(volume == null || (volume >= 0 && volume <= 100), 'volume 0-100'),
       assert(position == null || !position.isNegative, 'seek >= 0'),
       assert(durationMs == null || durationMs > 0, 'durationMs > 0');

  final String id;
  final RemoteAction action;
  String? token;
  final int? volume;
  final Duration? position;
  final String? mode;
  final int? hymnId;

  /// Destino da barra de vídeo: monitor:<id> ou tv:<slot> (video.setTarget).
  final String? targetId;
  final bool? enabled;

  /// Endereço aberto no navegador do celular (site.navigate).
  final String? url;

  /// Proporção da rolagem (site.scroll), de 0 a 1.
  final double? ratio;

  /// Índice do item da liturgia (liturgy.select/toggleDone).
  final int? index;

  /// Campos v2 (bible/timer/countdown).
  final int? versionId;
  final int? bookId;
  final int? chapter;
  final int? verse;
  final int? durationMs;

  /// Fase 2: random.addName / clock.setConfig.
  final String? name;
  final String? style;
  final bool? showSeconds;
  final bool? format24h;

  /// Fase 3: media.open (musicId; `mode` reaproveita o do player).
  final int? musicId;

  /// media.search
  final String? query;

  /// Sorteio: intervalo de números ou lista de nomes (texto multi-linha).
  final int? numberMin;
  final int? numberMax;
  final String? namesText;

  @override
  String encode() {
    final map = <String, dynamic>{
      'v': 1,
      'type': 'command',
      'id': id,
      'action': action.wire,
      if (token != null) 'token': token,
      if (volume != null) 'value': volume,
      if (position != null) 'positionMs': position!.inMilliseconds,
      if (mode != null) 'mode': mode,
      if (hymnId != null) 'hymnId': hymnId,
      if (index != null) 'value': index,
      if (versionId != null) 'versionId': versionId,
      if (bookId != null) 'bookId': bookId,
      if (chapter != null) 'chapter': chapter,
      if (verse != null) 'verse': verse,
      if (durationMs != null) 'durationMs': durationMs,
      if (name != null) 'name': name,
      if (style != null) 'style': style,
      if (showSeconds != null) 'showSeconds': showSeconds,
      if (format24h != null) 'format24h': format24h,
      if (musicId != null) 'musicId': musicId,
      if (query != null) 'query': query,
      if (numberMin != null) 'numberMin': numberMin,
      if (numberMax != null) 'numberMax': numberMax,
      if (namesText != null) 'namesText': namesText,
      if (targetId != null) 'targetId': targetId,
      if (enabled != null) 'enabled': enabled,
      if (url != null) 'url': url,
      if (ratio != null) 'ratio': ratio,
      if (mode != null) 'mode': mode,
    };
    return jsonEncode(map);
  }
}

/// Item da liturgia do desktop espelhado no APK.
class RemoteLiturgyItem {
  const RemoteLiturgyItem({
    required this.index,
    required this.type,
    required this.title,
    required this.done,
    this.subtitle,
    this.isCategory = false,
    this.accentColor,
    this.url,
  });

  final int index;
  final String type;
  final String? title;
  final String? subtitle;
  final bool isCategory;
  final String? accentColor;
  final bool done;

  /// Link do item de site: o celular abre no navegador embutido.
  final String? url;
}

/// Dia da liturgia no desktop (domingo a sábado ou `custom`, a avulsa).
class RemoteLiturgyDay {
  const RemoteLiturgyDay({
    required this.key,
    required this.count,
    required this.selected,
  });

  final String key;

  /// Quantidade de itens; zero = dia sem liturgia.
  final int count;

  /// Dia aberto agora no desktop.
  final bool selected;
}

/// Liturgia avulsa do desktop (pode haver várias).
class RemoteLiturgyCustom {
  const RemoteLiturgyCustom({
    required this.index,
    required this.name,
    required this.count,
    required this.selected,
  });

  final int index;
  final String name;
  final int count;
  final bool selected;
}

/// Tela ou TV que pode receber o vídeo.
class RemoteVideoTarget {
  const RemoteVideoTarget({
    required this.id,
    required this.label,
    required this.selected,
    this.detail,
    this.onAir = false,
    this.enabled = true,
  });

  final String id;
  final String label;
  final bool selected;
  final String? detail;

  /// Projeção independente: já está no ar neste destino.
  final bool onAir;

  /// Projeção independente: false = monitor desligado em "Telas".
  final bool enabled;
}

/// Projeção independente da barra de vídeo do desktop.
class RemoteIndependentControls {
  const RemoteIndependentControls({
    required this.mode,
    required this.live,
    required this.armed,
    required this.monitors,
    required this.remotes,
  });

  final String mode;
  final bool live;
  final bool armed;
  final List<RemoteVideoTarget> monitors;
  final List<RemoteVideoTarget> remotes;
}

/// Estado da barra de vídeo aberta no desktop. Null em desktops antigos.
class RemoteVideoControls {
  const RemoteVideoControls({
    required this.audioOutput,
    required this.canProject,
    required this.projecting,
    required this.canControlCaptions,
    required this.captionsHidden,
    required this.monitors,
    required this.tvs,
    this.independent,
  });

  final String audioOutput;
  final bool canProject;
  final bool projecting;
  final bool canControlCaptions;
  final bool captionsHidden;
  final List<RemoteVideoTarget> monitors;
  final List<RemoteVideoTarget> tvs;
  final RemoteIndependentControls? independent;
}

/// Alvo → APK: estado COMPLETO do player (push na conexão e após comandos).
class RemotePlayerState extends RemoteMessage {
  const RemotePlayerState({
    this.hymnId,
    this.title,
    this.mode,
    required this.playing,
    required this.position,
    required this.duration,
    required this.slideIndex,
    required this.slideCount,
    required this.volume,
    required this.canPrevious,
    required this.canNext,
    this.liturgyItems = const [],
    this.liturgySelectedIndex,
    this.liturgyCanOpen = false,
    this.liturgyDays = const [],
    this.liturgyCustoms = const [],
    this.slidePreview,
    this.slideGalleryKey,
    this.slidePreviews,
    this.slideLyrics,
    this.slideBackgroundKey,
    this.slideBackgroundIndex,
    this.slideBackgroundSources,
    this.bibleModule,
    this.timerModule,
    this.countdownModule,
    this.clockModule,
    this.randomModule,
    this.mediaModule,
    this.announcementsModule,
    this.videoControls,
    this.idleVideoTargets = const [],
    this.idleVideoTvs = const [],
    this.idleIndependent,
  });

  final int? hymnId;
  final String? title;
  final String? mode;
  final bool playing;
  final Duration position;
  final Duration duration;
  final int slideIndex;
  final int slideCount;

  /// Miniatura JPEG (base64) da imagem/página que está na tela do desktop.
  final String? slidePreview;

  /// Identifica a galeria aberta; as miniaturas dela chegam uma vez só.
  final String? slideGalleryKey;

  /// Miniaturas de todas as imagens da galeria (só quando ela muda).
  final List<String>? slidePreviews;

  /// Letra de cada slide do hino aberto (texto simples).
  final List<String>? slideLyrics;

  /// Identifica o conjunto de fundos do hino; as miniaturas chegam uma vez só.
  final String? slideBackgroundKey;

  /// Para cada slide, qual fundo usar (`-1` = sem fundo).
  final List<int>? slideBackgroundIndex;

  /// Miniatura (data URL) ou endereço de cada fundo diferente do hino.
  final List<String>? slideBackgroundSources;
  final int volume;
  final bool canPrevious;
  final bool canNext;

  /// Espelho da liturgia do desktop (v1.1) — vazio em peers antigos.
  final List<RemoteLiturgyItem> liturgyItems;
  final int? liturgySelectedIndex;

  /// Desktop aceita liturgy.open (executar sem projetar).
  final bool liturgyCanOpen;

  /// Dias da liturgia; vazio em desktops que ainda não informam.
  final List<RemoteLiturgyDay> liturgyDays;

  /// Liturgias avulsas do desktop.
  final List<RemoteLiturgyCustom> liturgyCustoms;

  /// Há mídia aberta no alvo. O título sozinho não basta: em vídeo ele vem do
  /// item selecionado da liturgia, que o desktop limpa ao concluir o item.
  bool get hasOpenMedia => title != null || playing || duration > Duration.zero;

  /// Módulos v2 (controle remoto total) — null em peers v1.
  final RemoteBibleState? bibleModule;
  final RemoteTimerState? timerModule;
  final RemoteCountdownState? countdownModule;
  final RemoteClockState? clockModule;
  final RemoteRandomState? randomModule;
  final RemoteMediaState? mediaModule;
  final RemoteAnnouncementsState? announcementsModule;
  final RemoteVideoControls? videoControls;

  /// Monitores informados pelo desktop quando não há vídeo aberto.
  final List<RemoteVideoTarget> idleVideoTargets;

  /// Conexões remotas ligadas no desktop quando não há vídeo aberto.
  final List<RemoteVideoTarget> idleVideoTvs;

  /// Projeção independente quando não há vídeo aberto.
  final RemoteIndependentControls? idleIndependent;

  @override
  String encode() {
    return jsonEncode({
      'v': 1,
      'type': 'state',
      if (announcementsModule != null) 'announcements': announcementsModule!.toJson(),
      'player': {
        if (hymnId != null) 'hymnId': hymnId,
        if (title != null) 'title': title,
        if (mode != null) 'mode': mode,
        'playing': playing,
        'positionMs': position.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'slideIndex': slideIndex,
        'slideCount': slideCount,
        'volume': volume,
        'canPrevious': canPrevious,
        'canNext': canNext,
      },
      'liturgy': {
        'selectedIndex': liturgySelectedIndex,
        'items': liturgyItems
            .map(
              (item) => {
                'index': item.index,
                'type': item.type,
                'title': item.title,
                'subtitle': item.subtitle,
                'isCategory': item.isCategory,
                'accentColor': item.accentColor,
                'done': item.done,
              },
            )
            .toList(),
      },
    });
  }
}

/// Estado da Bíblia do alvo (v2). Null em peers v1.
class RemoteBibleBook {
  const RemoteBibleBook({
    required this.id,
    required this.name,
    required this.chapters,
    required this.number,
  });

  final int id;
  final String name;
  final int chapters;
  final int number;
}

class RemoteBibleVersion {
  const RemoteBibleVersion({required this.id, required this.abbreviation});

  final int id;
  final String abbreviation;
}

class RemoteBibleState {
  const RemoteBibleState({
    this.bookId,
    this.chapter,
    this.selectedVerses = const [],
    required this.isProjecting,
    this.versionId,
    this.books = const [],
    this.versions = const [],
    this.verses = const {},
  });

  final int? bookId;
  final int? chapter;
  final List<int> selectedVerses;
  final bool isProjecting;
  final int? versionId;
  final List<RemoteBibleBook> books;
  final List<RemoteBibleVersion> versions;
  final Map<int, String> verses;
}

/// Estado do timer/cronômetro do alvo (v2).
class RemoteTimerState {
  const RemoteTimerState({
    required this.status,
    required this.accumulatedMs,
    this.savedTimesMs = const [],
    required this.isProjecting,
  });

  final String status;
  final int accumulatedMs;
  final List<int> savedTimesMs;
  final bool isProjecting;
}

/// Resultado de busca de hinos no catálogo do ALVO (ids corretos).
class RemoteMusicHit {
  const RemoteMusicHit({required this.musicId, required this.name, this.track});

  final int musicId;
  final String name;
  final int? track;
}

class RemoteMediaState {
  const RemoteMediaState({required this.searchResults, this.query});

  final List<RemoteMusicHit> searchResults;

  /// Query que gerou estes resultados (p/ o painel casar input ↔ lista).
  final String? query;
}

/// Estado do relógio do alvo (v2 fase 2).
class RemoteClockState {
  const RemoteClockState({
    required this.style,
    required this.showSeconds,
    required this.format24h,
    required this.isProjecting,
  });

  final String style;
  final bool showSeconds;
  final bool format24h;
  final bool isProjecting;
}

/// Estado do sorteio do alvo (v2 fase 2).
class RemoteRandomState {
  const RemoteRandomState({
    required this.mode,
    required this.drawnCount,
    required this.availableCount,
    required this.isDrawing,
    this.currentDisplay,
    required this.isProjecting,
    this.numberMin,
    this.numberMax,
    this.available = const [],
    this.drawn = const [],
  });

  final String mode;
  final int drawnCount;
  final int availableCount;
  final bool isDrawing;
  final String? currentDisplay;
  final int? numberMin;
  final int? numberMax;
  final List<String> available;
  final List<String> drawn;
  final bool isProjecting;
}

/// Estado do countdown do alvo (v2).
class RemoteCountdownState {
  const RemoteCountdownState({
    required this.status,
    required this.durationMs,
    required this.accumulatedMs,
    required this.finished,
    this.savedTimesMs = const [],
    required this.isProjecting,
  });

  final String status;
  final int durationMs;
  final int accumulatedMs;
  final bool finished;
  final List<int> savedTimesMs;
  final bool isProjecting;
}

/// Alvo → APK: resultado de um comando.
class RemoteAck extends RemoteMessage {
  const RemoteAck({required this.id, required this.ok});

  final String id;
  final bool ok;

  @override
  String encode() => jsonEncode({'v': 1, 'type': 'ack', 'id': id, 'ok': ok});
}

/// Erro de protocolo (ação desconhecida, token inválido etc.).
class RemoteError extends RemoteMessage {
  const RemoteError({required this.id, required this.code, this.message});

  final String id;
  final String code;
  final String? message;

  @override
  String encode() => jsonEncode({
    'v': 1,
    'type': 'error',
    'id': id,
    'code': code,
    if (message != null) 'message': message,
  });
}

/// Heartbeat: cada lado manda a cada 15s; 10s sem resposta = conexão morta.
class RemotePing extends RemoteMessage {
  const RemotePing();

  @override
  String encode() => jsonEncode({'v': 1, 'type': 'ping'});
}

class RemotePong extends RemoteMessage {
  const RemotePong();

  final String type = 'pong';

  @override
  String encode() => jsonEncode({'v': 1, 'type': 'pong'});
}

/// APK → desktop: identificação do aparelho logo após conectar.
class RemoteHello extends RemoteMessage {
  const RemoteHello({required this.device, this.appVersion, this.token});

  final String? token;

  /// Nome legível do dispositivo (ex.: modelo do aparelho).
  final String device;

  /// Versão do app APK (ex.: 0.1.86).
  final String? appVersion;

  @override
  String encode() => jsonEncode({
    'v': 1,
    'type': 'hello',
    if (token != null) 'token': token,
    'device': device,
    if (appVersion != null) 'appVersion': appVersion,
  });
}

/// Desktop → APK: quadro do vídeo/YouTube aberto (JPEG em base64), num canal
/// próprio para o estado continuar leve.
class RemoteVideoFrame extends RemoteMessage {
  const RemoteVideoFrame({required this.data});

  final String data;

  @override
  String encode() => jsonEncode({'v': 1, 'type': 'frame', 'data': data});
}

/// Parser tolerante: NUNCA lança. Tudo que viola o protocolo v1 → null.
class RemoteProtocol {
  static RemoteMessage? parse(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['v'] != 1) return null;
    final type = decoded['type'];
    switch (type) {
      case 'command':
        return _parseCommand(decoded);
      case 'state':
        return _parseState(decoded);
      case 'ack':
        final id = decoded['id'];
        if (id is! String) return null;
        return RemoteAck(id: id, ok: decoded['ok'] == true);
      case 'error':
        final id = decoded['id'];
        final code = decoded['code'];
        if (code is! String) return null;
        final msg = decoded['message'];
        return RemoteError(
          id: id is String ? id : '',
          code: code,
          message: msg is String ? msg : null,
        );
      case 'hello':
        final device = decoded['device'];
        if (device is! String || device.isEmpty) return null;
        final ver = decoded['appVersion'];
        return RemoteHello(
          device: device,
          appVersion: ver is String ? ver : null,
          token: decoded['token'] is String ? decoded['token'] as String : null,
        );
      case 'frame':
        final data = decoded['data'];
        if (data is! String || data.isEmpty) return null;
        return RemoteVideoFrame(data: data);
      case 'ping':
        return const RemotePing();
      case 'pong':
        return const RemotePong();
      default:
        return null;
    }
  }

  static RemoteCommand? _parseCommand(Map<String, dynamic> m) {
    final id = m['id'];
    if (id is! String) return null;
    final action = RemoteAction.fromWire(m['action'] as String?);
    if (action == null) return null;

    int? volume;
    int? index;
    if (m.containsKey('value')) {
      final v = m['value'];
      if (v is! num) return null;
      if (action == RemoteAction.liturgySelect ||
          action == RemoteAction.liturgyToggleDone) {
        if (v < 0 || v != v.toInt()) return null;
        index = v.toInt();
      } else {
        if (v < 0 || v > 100) return null;
        volume = v.toInt();
      }
    }

    Duration? position;
    if (m.containsKey('positionMs')) {
      final p = m['positionMs'];
      if (p is! num || p < 0) return null;
      position = Duration(milliseconds: p.toInt());
    }

    String? mode;
    if (m.containsKey('mode')) {
      final md = m['mode'];
      if (md is! String || !kRemoteModes.contains(md)) return null;
      mode = md;
    }

    int? hymnId;
    if (m.containsKey('hymnId')) {
      final h = m['hymnId'];
      if (h is! num || h <= 0) return null;
      hymnId = h.toInt();
    }

    int? verse;
    if (m.containsKey('verse')) {
      final v = m['verse'];
      if (v is! num || v < 1) return null;
      verse = v.toInt();
    }

    int? bookId;
    if (m.containsKey('bookId')) {
      final b = m['bookId'];
      if (b is! num || b < 1) return null;
      bookId = b.toInt();
    }

    int? chapter;
    if (m.containsKey('chapter')) {
      final c = m['chapter'];
      if (c is! num || c < 1) return null;
      chapter = c.toInt();
    }

    int? versionId;
    if (m.containsKey('versionId')) {
      final ver = m['versionId'];
      if (ver is! num || ver < 1) return null;
      versionId = ver.toInt();
    }

    int? durationMs;
    if (m.containsKey('durationMs')) {
      final d = m['durationMs'];
      if (d is! num || d <= 0) return null;
      durationMs = d.toInt();
    }

    final token = m['token'];
    return RemoteCommand(
      id: id,
      action: action,
      token: token is String ? token : null,
      volume: volume,
      position: position,
      mode: mode,
      hymnId: hymnId,
      index: index,
      versionId: versionId,
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      durationMs: durationMs,
    );
  }

  static RemotePlayerState? _parseState(Map<String, dynamic> m) {
    final p = m['player'];
    if (p is! Map<String, dynamic>) return null;

    int? intOrNull(Object? v) => v is num ? v.toInt() : null;

    final hymnId = intOrNull(p['hymnId']);
    if (p.containsKey('hymnId') && p['hymnId'] is num && hymnId == null) {
      return null;
    }
    final title = p['title'];
    final mode = p['mode'];
    final playing = p['playing'];
    if (playing is! bool) return null;

    final positionMs = p['positionMs'];
    final durationMs = p['durationMs'];
    if (positionMs is! num || durationMs is! num) return null;
    if (positionMs < 0 || durationMs < 0) return null;

    final rawSlide = m['slide'];
    final slide = rawSlide is Map ? rawSlide : null;

    // Liturgia espelhada (v1.1, opcional — peers antigos não enviam).
    final lit = m['liturgy'];
    final liturgyItems = <RemoteLiturgyItem>[];
    int? liturgySelected;
    final liturgyCanOpen = lit is Map && lit['canOpen'] == true;
    final liturgyDays = <RemoteLiturgyDay>[
      if (lit is Map && lit['days'] is List)
        for (final e in lit['days'] as List)
          if (e is Map && e['key'] is String)
            RemoteLiturgyDay(
              key: e['key'] as String,
              count: e['count'] is num ? (e['count'] as num).toInt() : 0,
              selected: e['selected'] == true,
            ),
    ];
    final liturgyCustoms = <RemoteLiturgyCustom>[
      if (lit is Map && lit['customs'] is List)
        for (final e in lit['customs'] as List)
          if (e is Map && e['index'] is num)
            RemoteLiturgyCustom(
              index: (e['index'] as num).toInt(),
              name: e['name'] is String ? e['name'] as String : '',
              count: e['count'] is num ? (e['count'] as num).toInt() : 0,
              selected: e['selected'] == true,
            ),
    ];
    if (lit is Map) {
      final sel = lit['selectedIndex'];
      liturgySelected = sel is num ? sel.toInt() : null;
      final rawItems = lit['items'];
      if (rawItems is List) {
        for (final e in rawItems) {
          if (e is Map && e['index'] is num && e['type'] is String) {
            liturgyItems.add(
              RemoteLiturgyItem(
                index: (e['index'] as num).toInt(),
                type: e['type'] as String,
                title: e['title'] is String ? e['title'] as String? : null,
                done: e['done'] == true,
                subtitle: e['subtitle'] is String
                    ? e['subtitle'] as String?
                    : null,
                isCategory: e['isCategory'] == true,
                accentColor: e['accentColor'] is String
                    ? e['accentColor'] as String?
                    : null,
                url: e['url'] is String ? e['url'] as String? : null,
              ),
            );
          }
        }
      }
    }

    return RemotePlayerState(
      hymnId: hymnId,
      title: title is String ? title : null,
      mode: mode is String ? mode : null,
      playing: playing,
      position: Duration(milliseconds: positionMs.toInt()),
      duration: Duration(milliseconds: durationMs.toInt()),
      // Desktop envia em `slide` no topo; peers antigos, dentro de `player`.
      slideIndex: intOrNull(slide?['index']) ?? intOrNull(p['slideIndex']) ?? 0,
      slideCount: intOrNull(slide?['total']) ?? intOrNull(p['slideCount']) ?? 0,
      slidePreview: slide?['preview'] is String
          ? slide!['preview'] as String
          : null,
      slideGalleryKey: slide?['galleryKey'] is String
          ? slide!['galleryKey'] as String
          : null,
      slideBackgroundKey: slide?['backgroundKey'] is String
          ? slide!['backgroundKey'] as String
          : null,
      slideBackgroundIndex: slide?['backgroundIndex'] is List
          ? [
              for (final e in slide!['backgroundIndex'] as List)
                e is num ? e.toInt() : -1,
            ]
          : null,
      slideBackgroundSources: slide?['backgroundSources'] is List
          ? [
              for (final e in slide!['backgroundSources'] as List)
                e is String ? e : '',
            ]
          : null,
      slideLyrics: slide?['lyrics'] is List
          ? [
              for (final e in slide!['lyrics'] as List)
                e is String ? e : '',
            ]
          : null,
      slidePreviews: slide?['previews'] is List
          ? [
              for (final e in slide!['previews'] as List)
                e is String ? e : '',
            ]
          : null,
      volume: intOrNull(p['volume']) ?? 0,
      canPrevious: p['canPrevious'] == true,
      canNext: p['canNext'] == true,
      liturgyItems: liturgyItems,
      liturgySelectedIndex: liturgySelected,
      liturgyCanOpen: liturgyCanOpen,
      liturgyDays: liturgyDays,
      liturgyCustoms: liturgyCustoms,
      bibleModule: _parseBibleModule(m['bible']),
      timerModule: _parseTimerModule(m['timer']),
      countdownModule: _parseCountdownModule(m['countdown']),
      clockModule: _parseClockModule(m['clock']),
      randomModule: _parseRandomModule(m['random']),
      mediaModule: _parseMediaModule(m['media']),
      announcementsModule: RemoteAnnouncementsState.parse(m['announcements']),
      videoControls: _parseVideoControls(m['video']),
      idleIndependent: m['videoTargets'] is Map
          ? _parseIndependent((m['videoTargets'] as Map)['independent'])
          : null,
      idleVideoTvs: _parseVideoTargets(
        m['videoTargets'] is Map ? (m['videoTargets'] as Map)['tvs'] : null,
      ),
      idleVideoTargets: _parseVideoTargets(
        m['videoTargets'] is Map
            ? (m['videoTargets'] as Map)['monitors']
            : null,
      ),
    );
  }

  static List<RemoteVideoTarget> _parseVideoTargets(Object? raw) => [
    if (raw is List)
      for (final e in raw)
        if (e is Map && e['id'] is String && e['label'] is String)
          RemoteVideoTarget(
            id: e['id'] as String,
            label: e['label'] as String,
            selected: e['selected'] == true,
            detail: e['detail'] is String ? e['detail'] as String : null,
            onAir: e['onAir'] == true,
            enabled: e['enabled'] != false,
          ),
  ];

  static RemoteVideoControls? _parseVideoControls(Object? raw) {
    if (raw is! Map) return null;
    final audioOutput = raw['audioOutput'];
    return RemoteVideoControls(
      audioOutput: audioOutput is String ? audioOutput : 'player',
      canProject: raw['canProject'] == true,
      projecting: raw['projecting'] == true,
      canControlCaptions: raw['canControlCaptions'] == true,
      captionsHidden: raw['captionsHidden'] == true,
      monitors: _parseVideoTargets(raw['monitors']),
      tvs: _parseVideoTargets(raw['tvs']),
      independent: _parseIndependent(raw['independent']),
    );
  }

  static RemoteIndependentControls? _parseIndependent(Object? raw) {
    if (raw is! Map) return null;
    final mode = raw['mode'];
    return RemoteIndependentControls(
      mode: mode is String ? mode : 'overlay',
      live: raw['live'] == true,
      armed: raw['armed'] == true,
      monitors: _parseVideoTargets(raw['monitors']),
      remotes: _parseVideoTargets(raw['remotes']),
    );
  }

  static RemoteMediaState? _parseMediaModule(Object? raw) {
    if (raw is! Map) return null;
    final results = raw['searchResults'];
    return RemoteMediaState(
      query: raw['query'] is String ? raw['query'] as String : null,
      searchResults: results is List
          ? results
                .whereType<Map>()
                .map(
                  (e) => RemoteMusicHit(
                    musicId: e['musicId'] is num
                        ? (e['musicId'] as num).toInt()
                        : 0,
                    name: e['name'] is String ? e['name'] as String : '',
                    track: e['track'] is num
                        ? (e['track'] as num).toInt()
                        : null,
                  ),
                )
                .where((h) => h.musicId > 0)
                .toList()
          : const [],
    );
  }

  static RemoteClockState? _parseClockModule(Object? raw) {
    if (raw is! Map) return null;
    final style = raw['style'];
    return RemoteClockState(
      style: style is String ? style : 'digital',
      showSeconds: raw['showSeconds'] == true,
      format24h: raw['format24h'] == true,
      isProjecting: raw['isProjecting'] == true,
    );
  }

  static RemoteRandomState? _parseRandomModule(Object? raw) {
    if (raw is! Map) return null;
    final mode = raw['mode'];
    final display = raw['currentDisplay'];
    List<String> _strList(Object? v) => v is List
        ? v.map((e) => '$e').where((e) => e.isNotEmpty).toList()
        : const [];
    return RemoteRandomState(
      mode: mode is String ? mode : 'names',
      numberMin: raw['numberMin'] is num
          ? (raw['numberMin'] as num).toInt()
          : null,
      numberMax: raw['numberMax'] is num
          ? (raw['numberMax'] as num).toInt()
          : null,
      available: _strList(raw['available']),
      drawn: _strList(raw['drawn']),
      currentDisplay: display is String ? display : null,
      drawnCount: raw['drawnCount'] is num
          ? (raw['drawnCount'] as num).toInt()
          : 0,
      availableCount: raw['availableCount'] is num
          ? (raw['availableCount'] as num).toInt()
          : 0,
      isDrawing: raw['isDrawing'] == true,
      isProjecting: raw['isProjecting'] == true,
    );
  }

  static RemoteBibleState? _parseBibleModule(Object? raw) {
    if (raw is! Map) return null;
    final bookId = raw['bookId'];
    final verses = raw['selectedVerses'];
    final rawBooks = raw['books'];
    final rawVersions = raw['versions'];
    return RemoteBibleState(
      verses: raw['verses'] is Map
          ? {
              for (final entry in (raw['verses'] as Map).entries)
                if (int.tryParse('${entry.key}') != null && entry.value is String)
                  int.parse('${entry.key}'): entry.value as String,
            }
          : const {},
      bookId: bookId is num ? bookId.toInt() : null,
      chapter: raw['chapter'] is num ? (raw['chapter'] as num).toInt() : null,
      selectedVerses: verses is List
          ? verses.whereType<num>().map((v) => v.toInt()).toList()
          : const [],
      isProjecting: raw['isProjecting'] == true,
      versionId: raw['versionId'] is num
          ? (raw['versionId'] as num).toInt()
          : null,
      books: rawBooks is List
          ? rawBooks
                .whereType<Map>()
                .where((b) => b['id'] is num && b['name'] is String)
                .map(
                  (b) => RemoteBibleBook(
                    id: (b['id'] as num).toInt(),
                    name: b['name'] as String,
                    chapters: b['chapters'] is num
                        ? (b['chapters'] as num).toInt()
                        : 0,
                    number: b['number'] is num
                        ? (b['number'] as num).toInt()
                        : 0,
                  ),
                )
                .toList()
          : const [],
      versions: rawVersions is List
          ? rawVersions
                .whereType<Map>()
                .where((v) => v['id'] is num && v['abbreviation'] is String)
                .map(
                  (v) => RemoteBibleVersion(
                    id: (v['id'] as num).toInt(),
                    abbreviation: v['abbreviation'] as String,
                  ),
                )
                .toList()
          : const [],
    );
  }

  static RemoteTimerState? _parseTimerModule(Object? raw) {
    if (raw is! Map) return null;
    final status = raw['status'];
    final marks = raw['savedTimesMs'];
    return RemoteTimerState(
      status: status is String ? status : 'idle',
      accumulatedMs: raw['accumulatedMs'] is num
          ? (raw['accumulatedMs'] as num).toInt()
          : 0,
      savedTimesMs: marks is List
          ? marks.whereType<num>().map((v) => v.toInt()).toList()
          : const [],
      isProjecting: raw['isProjecting'] == true,
    );
  }

  static RemoteCountdownState? _parseCountdownModule(Object? raw) {
    if (raw is! Map) return null;
    final status = raw['status'];
    final marks = raw['savedTimesMs'];
    return RemoteCountdownState(
      status: status is String ? status : 'idle',
      durationMs: raw['durationMs'] is num
          ? (raw['durationMs'] as num).toInt()
          : 0,
      accumulatedMs: raw['accumulatedMs'] is num
          ? (raw['accumulatedMs'] as num).toInt()
          : 0,
      finished: raw['finished'] == true,
      savedTimesMs: marks is List
          ? marks.whereType<num>().map((v) => v.toInt()).toList()
          : const [],
      isProjecting: raw['isProjecting'] == true,
    );
  }
}

/// Token de emparelhamento: 6 chars [A-Z0-9], sem caracteres ambíguos
/// (0/O e 1/I excluídos) pra leitura humana no QR/URL.
class RemotePairing {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generateToken([Random? random]) {
    final rng = random ?? Random.secure();
    return String.fromCharCodes(
      List.generate(
        6,
        (_) => _alphabet.codeUnitAt(rng.nextInt(_alphabet.length)),
      ),
    );
  }

  /// Compara em tempo constante (evita timing attack em LAN).
  static bool matches(String expected, String provided) {
    if (expected.length != provided.length) return false;
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected.codeUnitAt(i) ^ provided.codeUnitAt(i);
    }
    return diff == 0;
  }
}
