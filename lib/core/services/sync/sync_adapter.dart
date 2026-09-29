library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/sync/sync_package.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_timestamps.dart';
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

  final SharedPreferences prefs;

  SyncAdapter(this.prefs);

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

      default:
        return false; // entidade desconhecida — ignora
    }
  }
}
