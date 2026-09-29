library;

import '../../core/services/liturgy_widget_updater.dart';

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/sync/sync_timestamps.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

/// Persistencia de liturgia por dia da semana usando SharedPreferences.
class LiturgyRepository {
  final SharedPreferences _prefs;

  static const _itemsPrefix = 'liturgy_items_';
  static const _notesPrefix = 'liturgy_notes_';
  static const _orderPrefix = 'liturgy_order_';
  static const _avulsaPrefix = 'liturgy_avulsa_';
  static const _lockPrefix = 'liturgy_lock_';

  LiturgyRepository(this._prefs);

  String _itemsKey(LiturgyWeekday day) => '$_itemsPrefix${day.name}';
  String _notesKey(LiturgyWeekday day) => '$_notesPrefix${day.name}';

  /// Carrega itens de um dia.
  List<LiturgyItem> loadItems(LiturgyWeekday day) {
    final raw = _prefs.getString(_itemsKey(day));
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LiturgyItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Salva itens de um dia.
  Future<void> saveItems(LiturgyWeekday day, List<LiturgyItem> items) async {
    final json = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_itemsKey(day), json);
    unawaited(SyncTimestamps.touch('liturgy'));
    unawaited(LiturgyWidgetUpdater.notify());
  }

  /// Carrega notas de um dia.
  String loadNotes(LiturgyWeekday day) {
    return _prefs.getString(_notesKey(day)) ?? '';
  }

  /// Salva notas de um dia.
  Future<void> saveNotes(LiturgyWeekday day, String notes) async {
    await _prefs.setString(_notesKey(day), notes);
    unawaited(SyncTimestamps.touch('liturgy'));
    unawaited(LiturgyWidgetUpdater.notify());
  }

  /// Clona liturgia de um dia para outro.
  Future<void> cloneDay(LiturgyWeekday from, LiturgyWeekday to) async {
    final items = loadItems(from);
    final notes = loadNotes(from);
    await saveItems(to, items);
    await saveNotes(to, notes);
  }

  /// Limpa liturgia de um dia.
  Future<void> clearDay(LiturgyWeekday day) async {
    await _prefs.remove(_itemsKey(day));
    await _prefs.remove(_notesKey(day));
  }

  /// Verifica se a liturgia do dia está lockada.
  bool isLocked(LiturgyWeekday day) {
    return _prefs.getBool(_lockKey(day)) ?? false;
  }

  /// Define o estado de lock da liturgia do dia.
  Future<void> setLocked(LiturgyWeekday day, bool locked) async {
    await _prefs.setBool(_lockKey(day), locked);
    unawaited(SyncTimestamps.touch('liturgy_lock'));
    unawaited(LiturgyWidgetUpdater.notify());
  }

  /// Salva a ordem dos itens para o dia.
  Future<void> saveOrder(LiturgyWeekday day, List<String> orderedIds) async {
    final json = jsonEncode(orderedIds);
    await _prefs.setString(_orderKey(day), json);
    unawaited(SyncTimestamps.touch('liturgy_order'));
    unawaited(LiturgyWidgetUpdater.notify());
  }

  /// Carrega a ordem dos itens para o dia.
  List<String> loadOrder(LiturgyWeekday day) {
    final raw = _prefs.getString(_orderKey(day));
    if (raw == null) return [];
    try {
      return jsonDecode(raw) as List<String>;
    } catch (_) {
      return [];
    }
  }

  /// Salva a liturgia avulsa para a data específica.
  Future<void> saveAvulsa(DateTime date, List<LiturgyItem> items) async {
    final key = _avulsaKey(date);
    final json = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(key, json);
    unawaited(SyncTimestamps.touch('liturgy_avulsa'));
    unawaited(LiturgyWidgetUpdater.notify());
  }

  /// Carrega a liturgia avulsa para a data específica.
  List<LiturgyItem> loadAvulsa(DateTime date) {
    final key = _avulsaKey(date);
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LiturgyItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Limpa a liturgia avulsa para a data específica.
  Future<void> clearAvulsa(DateTime date) async {
    await _prefs.remove(_avulsaKey(date));
    unawaited(SyncTimestamps.touch('liturgy_avulsa'));
    unawaited(LiturgyWidgetUpdater.notify());
  }

  String _lockKey(LiturgyWeekday day) => '$_lockPrefix${day.name}';
  String _orderKey(LiturgyWeekday day) => '$_orderPrefix${day.name}';
  String _avulsaKey(DateTime date) =>
      '$_avulsaPrefix${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
}
