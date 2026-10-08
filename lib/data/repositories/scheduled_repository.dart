// Persistência de itens agendados (SharedPreferences, volume baixo).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_timestamps.dart';

class ScheduledRepository {
  ScheduledRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _catsKey = 'scheduled_categories';
  static const _itemsKey = 'scheduled_items';

  List<ScheduledCategory> loadCategories() {
    final raw = _prefs.getString(_catsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ScheduledCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCategories(
    List<ScheduledCategory> categories, {
    Future<void> Function(
      List<ScheduledCategory> categories,
      List<ScheduledItem> items,
    )? outbox,
  }) async {
    await _prefs.setString(
      _catsKey,
      jsonEncode(categories.map((e) => e.toJson()).toList()),
    );
    await SyncTimestamps.touch('scheduled');
    if (outbox != null) {
      try {
        await outbox(categories, loadItems());
      } catch (_) {
        // outbox nunca bloqueia o fluxo local
      }
    }
  }

  List<ScheduledItem> loadItems() {
    final raw = _prefs.getString(_itemsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ScheduledItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveItems(
    List<ScheduledItem> items, {
    Future<void> Function(
      List<ScheduledCategory> categories,
      List<ScheduledItem> items,
    )? outbox,
  }) async {
    await _prefs.setString(
      _itemsKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    await SyncTimestamps.touch('scheduled');
    // sync v2 (apk#107): mutação sincronizável grava na outbox (local-first).
    // Hook injetado pelo chamador — o repo nunca toca rede e segue
    // funcionando sem hook (testes/unit legados intatos).
    if (outbox != null) {
      try {
        await outbox(loadCategories(), items);
      } catch (_) {
        // outbox nunca bloqueia o fluxo local
      }
    }
  }

  /// Itens de uma data (qualquer categoria).
  List<ScheduledItem> itemsOn(DateTime date) => loadItems()
      .where(
        (i) =>
            i.date.year == date.year &&
            i.date.month == date.month &&
            i.date.day == date.day,
      )
      .toList();

  /// Importa DATAPACKETs já parseados. Categorias por id; itens cuja
  /// categoria não exista ficam sem categoria (categoryId '').
  /// Merge: id existente → substitui.
  /// [categories]/[items] são as ROWs do DataPacketParser (Map<String,String>).
  Future<int> importFromDelphi({
    required List<Map<String, String>> categories,
    required List<Map<String, String>> items,
    Future<void> Function(
      List<ScheduledCategory> categories,
      List<ScheduledItem> items,
    )? outbox,
  }) async {
    final cats = loadCategories().toList();
    final catIds = cats.map((c) => c.id).toSet();
    for (final row in categories) {
      final id = row['ID'] ?? '';
      if (id.isEmpty || catIds.contains(id)) continue;
      cats.add(ScheduledCategory(id: id, name: row['NOME'] ?? ''));
      catIds.add(id);
    }
    await saveCategories(cats, outbox: outbox);

    final current = loadItems().toList();
    final byId = {for (final i in current) i.id: i};
    var changed = 0;
    for (final row in items) {
      final id = row['ID'] ?? '';
      if (id.isEmpty) continue;
      final date = _parseDate(row['DATA'] ?? '');
      if (date == null) continue;
      byId[id] = ScheduledItem(
        id: id,
        categoryId: row['CATEGORIA'] ?? '',
        date: date,
        name: row['NOME'] ?? '',
        filePath: row['ARQUIVO'] ?? '',
        isRelativePath: (row['ARQUIVO_INFO'] ?? '') == 'I',
      );
      changed++;
    }
    await saveItems(byId.values.toList(), outbox: outbox);
    return changed;
  }

  /// Datas no ClientDataset podem vir dd/mm/yyyy, yyyy-mm-dd ou float
  /// (TDateTime: dias desde 30/12/1899). Tolerante a todos.
  DateTime? _parseDate(String v) {
    if (v.isEmpty) return null;
    final parts = v.split('/');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) {
        return DateTime(y, m, d);
      }
    }
    final iso = DateTime.tryParse(v); // yyyy-mm-dd[Thh:mm]
    if (iso != null) return iso;
    // TDateTime float (ex: "46023" ou "46023.5")
    final days = double.tryParse(v);
    if (days != null && days > 0 && days < 3000000) {
      return DateTime(
        1899,
        12,
        30,
      ).add(Duration(milliseconds: (days * 86400000).round()));
    }
    return null;
  }
}
