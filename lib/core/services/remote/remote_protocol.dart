library;

import 'dart:convert';
import 'dart:math';

/// Protocolo "LouvorJA Remote v1" — JSON sobre WebSocket.
///
/// Envelope único, bidirecional. O APK é cliente quando controla o Desktop
/// (Electron = servidor WS :7070) e servidor quando controla o Web
/// (browser não aceita conexão de entrada → conecta no APK).
///
/// Regras (SPEC ~/.hermes/specs/2026-08-16-controle-remoto-apk.md):
/// - `v` SEMPRE 1; `v` diferente = mensagem de peer futuro → ignorar.
/// - Comandos são idempotentes e exigem ack; sem ack em 3s = erro de UI.
/// - Estado é COMPLETO (não delta) — reconexão resync total.
/// - Parser nunca lança: entrada inválida → null (peer ruim não derruba app).

enum RemoteAction {
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
  liturgyToggleDone('liturgy.toggleDone'),
  liturgyState('liturgy.state'),
  // Controle remoto total (v2 — spec Obsidian "Controle Remoto Total v2").
  bibleOpen('bible.open'),
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
  mediaSearch('media.search');

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
  });

  final int index;
  final String type;
  final String? title;
  final String? subtitle;
  final bool isCategory;
  final String? accentColor;
  final bool done;
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
    this.bibleModule,
    this.timerModule,
    this.countdownModule,
    this.clockModule,
    this.randomModule,
    this.mediaModule,
  });

  final int? hymnId;
  final String? title;
  final String? mode;
  final bool playing;
  final Duration position;
  final Duration duration;
  final int slideIndex;
  final int slideCount;
  final int volume;
  final bool canPrevious;
  final bool canNext;

  /// Espelho da liturgia do desktop (v1.1) — vazio em peers antigos.
  final List<RemoteLiturgyItem> liturgyItems;
  final int? liturgySelectedIndex;

  /// Módulos v2 (controle remoto total) — null em peers v1.
  final RemoteBibleState? bibleModule;
  final RemoteTimerState? timerModule;
  final RemoteCountdownState? countdownModule;
  final RemoteClockState? clockModule;
  final RemoteRandomState? randomModule;
  final RemoteMediaState? mediaModule;

  @override
  String encode() {
    return jsonEncode({
      'v': 1,
      'type': 'state',
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
  });

  final int? bookId;
  final int? chapter;
  final List<int> selectedVerses;
  final bool isProjecting;
  final int? versionId;
  final List<RemoteBibleBook> books;
  final List<RemoteBibleVersion> versions;
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
  const RemoteHello({required this.device, this.appVersion});

  /// Nome legível do dispositivo (ex.: modelo do aparelho).
  final String device;

  /// Versão do app APK (ex.: 0.1.86).
  final String? appVersion;

  @override
  String encode() => jsonEncode({
    'v': 1,
    'type': 'hello',
    'device': device,
    if (appVersion != null) 'appVersion': appVersion,
  });
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
        if (id is! String || code is! String) return null;
        final msg = decoded['message'];
        return RemoteError(
          id: id,
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
        );
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

    // Liturgia espelhada (v1.1, opcional — peers antigos não enviam).
    final lit = m['liturgy'];
    final liturgyItems = <RemoteLiturgyItem>[];
    int? liturgySelected;
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
      slideIndex: intOrNull(p['slideIndex']) ?? 0,
      slideCount: intOrNull(p['slideCount']) ?? 0,
      volume: intOrNull(p['volume']) ?? 0,
      canPrevious: p['canPrevious'] == true,
      canNext: p['canNext'] == true,
      liturgyItems: liturgyItems,
      liturgySelectedIndex: liturgySelected,
      bibleModule: _parseBibleModule(m['bible']),
      timerModule: _parseTimerModule(m['timer']),
      countdownModule: _parseCountdownModule(m['countdown']),
      clockModule: _parseClockModule(m['clock']),
      randomModule: _parseRandomModule(m['random']),
      mediaModule: _parseMediaModule(m['media']),
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
