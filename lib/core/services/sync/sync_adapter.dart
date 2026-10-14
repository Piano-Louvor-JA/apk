library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/sync/sync_package.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_timestamps.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/local_custom_store.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

/// Resultado de uma importação (para UI/reportar).
class SyncImportResult {
  final List<String> applied;
  final List<String> skipped;

  const SyncImportResult({required this.applied, required this.skipped});
}

/// Adaptador SharedPreferences ↔ SyncPackage (formato `.louvorja`).
///
/// Conflito: LWW por entidade (timestamp `sync.modified.v1.<entidade>`).
/// Entidade desconhecida no pacote é ignorada (forward-compatible).
class SyncAdapter {
  static const _settingsKeys = ['themeMode', 'accent', 'interaction'];
  static const _settingsIntKeys = ['glassIntensity'];
  static const _timerPresetsKey = 'timer.countdown.presets.v1';

  /// Escopos de palco sincronizáveis (paridade com desktop t_c1ea317a).
  static const _stageScopes = [
    'global',
    'hymns',
    'bible',
    'liturgy',
    'timer',
  ];
  static const _stagePrefix = 'stage.settings.';

  final SharedPreferences prefs;
  final LocalCustomStore localCustomStore;

  SyncAdapter(this.prefs, {LocalCustomStore? localCustomStore})
    : localCustomStore = localCustomStore ?? LocalCustomStore.noop();

  /// Lê o storage local e produz o pacote para exportar.
  Future<SyncPackage> export() async {
    final entities = <String, SyncEntity>{};

    // Liturgia: dias tocados (com dados) entram no pacote.
    final days = <String, Map<String, dynamic>>{};
    final repo = LiturgyRepository(prefs);
    for (final day in LiturgyWeekday.values) {
      final items = repo.loadItems(day);
      final notes = repo.loadNotes(day);
      if (items.isEmpty && notes.isEmpty) continue;
      days[day.name] = {
        'items': items.map((e) => e.toJson()).toList(),
        'notes': notes,
      };
    }
    if (days.isNotEmpty) {
      entities['liturgy'] = SyncEntity(
        type: 'liturgy',
        modified: SyncTimestamps.get('liturgy'),
        data: days,
      );
    }

    // Settings (se algum existir).
    final settings = <String, dynamic>{};
    for (final k in _settingsKeys) {
      final v = prefs.getString(k);
      if (v != null) settings[k] = v;
    }
    for (final k in _settingsIntKeys) {
      final v = prefs.getInt(k);
      if (v != null) settings[k] = v;
    }
    if (settings.isNotEmpty) {
      entities['settings'] = SyncEntity(
        type: 'settings',
        modified: SyncTimestamps.get('settings'),
        data: settings,
      );
    }

    // Presets de timer.
    final timers = prefs.getString(_timerPresetsKey);
    if (timers != null) {
      entities['timerPresets'] = SyncEntity(
        type: 'timerPresets',
        modified: SyncTimestamps.get('timerPresets'),
        data: {'raw': timers},
      );
    }

    // Coletâneas custom locais (t_c1ea317a): converte p/ shape canônico
    // desktop (ver comentário do card). Binários/paths ficam fora.
    final customDb = _exportCanonicalDb(localCustomStore);
    final hasCustom =
        ((customDb['collections'] as List<dynamic>? ?? const []).isNotEmpty) ||
        ((customDb['musics'] as List<dynamic>? ?? const []).isNotEmpty);
    if (hasCustom) {
      entities['mediaCustomCatalog'] = SyncEntity(
        type: 'mediaCustomCatalog',
        modified: SyncTimestamps.get('mediaCustomCatalog'),
        data: {'db': customDb},
      );
    }

    // Preferências de palco (allowlist de escopos — nunca blob opaco).
    final stagePrefs = <String, dynamic>{};
    for (final scope in _stageScopes) {
      final key = 'stage.settings.$scope';
      final raw = prefs.getString(key);
      if (raw != null) stagePrefs[key] = jsonDecode(raw);
    }
    if (stagePrefs.isNotEmpty) {
      entities['preferences'] = SyncEntity(
        type: 'preferences',
        modified: SyncTimestamps.get('preferences'),
        data: stagePrefs,
      );
    }

    return SyncPackage(
      appVersion: 'mobile',
      platform: 'apk',
      exportedAt: DateTime.now().toUtc(),
      entities: entities,
    );
  }

  /// Aplica o pacote com LWW por entidade.
  Future<SyncImportResult> importPackage(SyncPackage pkg) async {
    final applied = <String>[];
    final skipped = <String>[];

    for (final entry in pkg.entities.entries) {
      final name = entry.key;
      final remote = entry.value;
      final localTs = SyncTimestamps.get(name);

      if (remote.modified.isAfter(localTs)) {
        final ok = await _apply(name, remote.data);
        if (ok) {
          // Timestamp local = modified do PACOTE (não "agora"): relógios de
          // dispositivos distintos não podem corromper a ordem LWW.
          await SyncTimestamps.set(name, remote.modified);
          applied.add(name);
        } else {
          skipped.add(name);
        }
      } else {
        skipped.add(name);
      }
    }
    return SyncImportResult(applied: applied, skipped: skipped);
  }

  Future<bool> _apply(String name, Map<String, dynamic> data) async {
    switch (name) {
      case 'liturgy':
        final repo = LiturgyRepository(prefs);
        for (final day in LiturgyWeekday.values) {
          final dayData = data[day.name];
          if (dayData is! Map<String, dynamic>) continue;
          final rawItems = dayData['items'];
          final items = (rawItems is List<dynamic>)
              ? rawItems
                    .whereType<Map>()
                    .map((e) => LiturgyItem.fromJson(e.cast<String, dynamic>()))
                    .toList()
              : <LiturgyItem>[];
          await repo.saveItems(day, items);
          final notes = dayData['notes'];
          await repo.saveNotes(day, notes is String ? notes : '');
        }
        return true;

      case 'settings':
        for (final k in _settingsKeys) {
          final v = data[k];
          if (v is String) await prefs.setString(k, v);
        }
        for (final k in _settingsIntKeys) {
          final v = data[k];
          if (v is int) await prefs.setInt(k, v);
        }
        return true;

      case 'timerPresets':
        final raw = data['raw'];
        if (raw is String) {
          await prefs.setString(_timerPresetsKey, raw);
        }
        return true;

      case 'mediaCustomCatalog':
        // Substituição TOTAL SÓ desta entidade (offline-first: liturgia/
        // preferências não são tocados). Converte do shape canônico desktop
        // p/ shape do store local (ver comentário do card t_c1ea317a).
        final db = data['db'];
        if (db is Map<String, dynamic>) {
          localCustomStore.replaceAll(_canonicalToLocal(db));
          return true;
        }
        return false;

      case 'preferences':
        // Allowlist explícita: só `stage.settings.<escopo>` entra.
        var applied = 0;
        for (final scope in _stageScopes) {
          final key = '$_stagePrefix$scope';
          final v = data[key];
          if (v is Map<String, dynamic>) {
            await prefs.setString(key, jsonEncode(v));
            applied++;
          }
        }
        return applied > 0;

      default:
        return false; // entidade desconhecida — ignora
    }
  }

  /// Converte o db local (shape APK) p/ o shape canônico desktop do pacote.
  ///
  /// Mapeamento (decisão no card t_c1ea317a):
  /// - musics: `slides[]` → `lyrics[]` (lyric=text, time, order,
  ///   show_slide=true); `audio_path` descartado (por-máquina);
  ///   `collection_id` → `collectionId`.
  /// - collections: `created_at` → `createdAt`; `author` → `description`.
  static Map<String, dynamic> _exportCanonicalDb(LocalCustomStore store) {
    final raw = store.exportDb();
    return {
      'nextCollectionId':
          (raw['nextCollectionId'] as num?)?.toInt() ?? _minId(raw['collections']) - 1,
      'nextMusicId':
          (raw['nextMusicId'] as num?)?.toInt() ?? _minId(raw['musics']) - 1,
      'nextLyricId': (raw['nextLyricId'] as num?)?.toInt() ?? -1,
      'collections': (raw['collections'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((c) => {
                'id': ((c['id'] as num?) ?? 0).toInt(),
                'name': c['name'],
                'description': c['description'] ?? c['author'],
                'createdAt': c['createdAt'] ?? c['created_at'],
              })
          .toList(),
      'musics': (raw['musics'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((m) => {
                'id': ((m['id'] as num?) ?? 0).toInt(),
                'collectionId': ((m['collectionId'] as num?) ??
                        (m['collection_id'] as num?) ??
                        0)
                    .toInt(),
                'name': m['name'],
                'audio_url': m['audio_url'],
                'image_url': m['image_url'],
                'officialMusicId': m['officialMusicId'],
                'audioBase64': null, // nunca sai do device
                'audioName': null,
                'durationMs': null,
                'sljaHash': m['sljaHash'],
                'lyrics': _slidesToLyrics(m['slides']),
              })
          .toList(),
    };
  }

  /// Converte o shape canônico desktop p/ o shape do store local (APK).
  ///
  /// Mapeamento inverso: `lyrics[]` → `slides[]` (text=lyric, order);
  /// `audioBase64/audioName` descartados; `description` → `author`.
  static Map<String, dynamic> _canonicalToLocal(Map<String, dynamic> db) {
    return {
      'collections': (db['collections'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((c) => {
                'id': ((c['id'] as num?) ?? 0).toInt(),
                'name': c['name'],
                'author': c['author'] ?? c['description'] ?? 'Sync',
                'created_at': c['created_at'] ?? c['createdAt'],
              })
          .toList(),
      'musics': (db['musics'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((m) => {
                'id': ((m['id'] as num?) ?? 0).toInt(),
                'collection_id': ((m['collection_id'] as num?) ??
                        (m['collectionId'] as num?) ??
                        0)
                    .toInt(),
                'name': m['name'],
                'lyric': _lyricsToFullLyric(m['lyrics']),
                'audio_path': null, // paths locais nunca chegam por pacote
                'slides': _lyricsToSlides(m['lyrics']),
                'created_at': m['createdAt'] ?? m['created_at'],
              })
          .toList(),
    };
  }

  static List<Map<String, dynamic>> _slidesToLyrics(dynamic slides) {
    if (slides is! List<dynamic>) return const [];
    return [
      for (var i = 0; i < slides.length; i++)
        if (slides[i] is Map)
          {
            'id': -i - 1,
            'lyric':
                (slides[i] as Map)['text']?.toString() ?? '',
            'time': (slides[i] as Map)['time']?.toString(),
            'order': ((slides[i] as Map)['order'] as num?)?.toInt() ?? i,
            'show_slide': true,
          },
    ];
  }

  static String? _lyricsToFullLyric(dynamic lyrics) {
    if (lyrics is! List<dynamic> || lyrics.isEmpty) return null;
    return lyrics
        .whereType<Map>()
        .map((l) => l['lyric']?.toString() ?? '')
        .join('\n');
  }

  static List<Map<String, dynamic>> _lyricsToSlides(dynamic lyrics) {
    if (lyrics is! List<dynamic>) return const [];
    return [
      for (var i = 0; i < lyrics.length; i++)
        if (lyrics[i] is Map)
          {
            'text': (lyrics[i] as Map)['lyric']?.toString() ?? '',
            'time': (lyrics[i] as Map)['time']?.toString() ?? '00:00.000',
            'order': ((lyrics[i] as Map)['order'] as num?)?.toInt() ?? i,
          },
    ];
  }

  static int _minId(dynamic list) {
    if (list is! List<dynamic>) return 0;
    return list
        .whereType<Map>()
        .map((e) => ((e['id'] as num?) ?? 0).toInt())
        .fold(0, (a, b) => a < b ? a : b);
  }
}
