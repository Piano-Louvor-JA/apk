library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy_widget_updater.dart';
import 'package:louvorja_piano_mobile/core/services/sync/operator_state_client.dart';
import 'package:louvorja_piano_mobile/core/utils/liturgy_format.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_liturgy.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

/// Estado canônico do desktop, com migração não destrutiva do storage mobile.
class LiturgyRepository {
  LiturgyRepository(this._prefs, {String? locale})
    : locale = languageOf(locale ?? _prefs.getString('locale') ?? 'pt');
  final SharedPreferences _prefs;
  final String locale;
  static final _changes = StreamController<String>.broadcast(sync: true);
  static Stream<String> get changes => _changes.stream;
  static String languageOf(String locale) =>
      switch (locale.toLowerCase().split(RegExp('[-_]')).first) {
        'en' => 'en',
        'es' => 'es',
        _ => 'pt',
      };
  String get storageKey => 'liturgy.state.$locale';

  static Map<String, dynamic> emptyState() => {
    'weekdays': {
      for (final day in LiturgyWeekday.values) day.name: <dynamic>[],
    },
    'dayNotes': {for (final day in LiturgyWeekday.values) day.name: ''},
    'daySessionTimes': {
      for (final day in LiturgyWeekday.values)
        day.name: <String, dynamic>{'startTime': null, 'endTime': null},
    },
    'customLiturgies': <dynamic>[],
    'deletionLocks': <String, dynamic>{},
  };

  Map<String, dynamic> loadState() {
    final saved = _prefs.getString(storageKey);
    if (saved != null) {
      try {
        return normalizeState(jsonDecode(saved) as Map<String, dynamic>);
      } catch (_) {
        /* mantém a cópia legada recuperável */
      }
    }
    final state = emptyState();
    // O storage sem idioma pertence ao português, como na migração desktop.
    if (locale != 'pt') return state;
    for (final day in LiturgyWeekday.values) {
      state['weekdays'][day.name] = _legacyItems(
        'liturgy_items_${day.name}',
      ).map((e) => e.toJson()).toList();
      state['dayNotes'][day.name] =
          _prefs.getString('liturgy_notes_${day.name}') ?? '';
      if (_prefs.getBool('liturgy_lock_${day.name}') == true)
        state['deletionLocks'][day.name] = true;
    }
    final keys =
        _prefs
            .getKeys()
            .where((k) => RegExp(r'^liturgy_avulsa_\d{8}$').hasMatch(k))
            .toList()
          ..sort();
    for (final key in keys) {
      final date = key.substring('liturgy_avulsa_'.length);
      state['customLiturgies'].add({
        'id': 'legacy-$date',
        'name':
            '${date.substring(6, 8)}/${date.substring(4, 6)}/${date.substring(0, 4)}',
        'items': _legacyItems(key).map((e) => e.toJson()).toList(),
        'notes': '',
        'startTime': null,
        'endTime': null,
      });
    }
    return state;
  }

  static Map<String, dynamic> normalizeState(Map<String, dynamic> raw) {
    final state = emptyState();
    final weekdays = raw['weekdays'] ?? raw['liturgies'];
    for (final day in LiturgyWeekday.values) {
      final items = weekdays is Map ? weekdays[day.name] : null;
      state['weekdays'][day.name] = _normalizeItems(items);
      final notes = raw['dayNotes'];
      state['dayNotes'][day.name] = notes is Map && notes[day.name] is String
          ? notes[day.name]
          : '';
      final times = raw['daySessionTimes'];
      final time = times is Map ? times[day.name] : null;
      state['daySessionTimes'][day.name] = _times(
        time is Map ? time : const {},
      );
    }
    final custom = raw['customLiturgies'];
    if (custom is List) {
      for (final entry in custom.whereType<Map>()) {
        if (entry['name'] is! String ||
            (entry['name'] as String).trim().isEmpty)
          continue;
        state['customLiturgies'].add({
          'id': entry['id'] is String ? entry['id'] : _newId(),
          'name': (entry['name'] as String).trim(),
          'items': _normalizeItems(entry['items']),
          'notes': entry['notes'] is String ? entry['notes'] : '',
          ..._times(entry),
        });
      }
    }
    if (raw['deletionLocks'] is Map) {
      state['deletionLocks'] = {
        for (final entry in (raw['deletionLocks'] as Map).entries)
          if (entry.key is String && entry.value == true) entry.key: true,
      };
    }
    return state;
  }

  static List<dynamic> _normalizeItems(Object? raw) {
    final result = <dynamic>[];
    if (raw is! List) return result;
    for (final item in raw.whereType<Map>()) {
      try {
        result.add(LiturgyItem.fromJson(item.cast<String, dynamic>()).toJson());
      } catch (_) {
        /* um item inválido não elimina os demais */
      }
    }
    return result;
  }

  static Map<String, dynamic> _times(Map raw) => {
    'startTime': LiturgyFormat.normalizeTimeHHmm(
      raw['startTime'] is String ? raw['startTime'] as String : null,
    ),
    'endTime': LiturgyFormat.normalizeTimeHHmm(
      raw['endTime'] is String ? raw['endTime'] as String : null,
    ),
  };
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  Future<void> saveState(
    Map<String, dynamic> raw, {
    bool enqueue = true,
  }) async {
    final state = normalizeState(raw);
    if (locale != 'pt' && !_prefs.containsKey('liturgy.state.pt')) {
      final legacy = LiturgyRepository(_prefs, locale: 'pt').loadState();
      await _prefs.setString('liturgy.state.pt', jsonEncode(legacy));
    }
    // setString atualiza o cache imediatamente: a próxima ação lê esta revisão.
    await _prefs.setString(storageKey, jsonEncode(state));
    final latest = loadState();
    if (locale == languageOf(_prefs.getString('locale') ?? 'pt')) {
      for (final day in LiturgyWeekday.values) {
        await _prefs.setString(
          'liturgy_items_${day.name}',
          jsonEncode(latest['weekdays'][day.name]),
        );
        await _prefs.setString(
          'liturgy_notes_${day.name}',
          latest['dayNotes'][day.name] as String,
        );
        await _prefs.setBool(
          'liturgy_lock_${day.name}',
          latest['deletionLocks'][day.name] == true,
        );
      }
    }
    if (enqueue) {
      final now = DateTime.now().toUtc().toIso8601String();
      await _prefs.setString('sync.modified.v1.liturgy', now);
      await _prefs.setString('sync.modified.v1.liturgy.$locale', now);
      await OperatorStateClient(
        _prefs,
      ).enqueueLiturgy(loadState(), locale: locale);
    }
    _changes.add(locale);
    unawaited(LiturgyWidgetUpdater.notify());
  }

  Future<void> resetCompletion() async {
    final state = loadState();
    bool changed = false;
    void clear(List<dynamic> items) {
      for (final item in items.whereType<Map>()) {
        if (item['done'] == true) {
          item['done'] = false;
          changed = true;
        }
      }
    }

    for (final items in (state['weekdays'] as Map).values) {
      clear(items as List);
    }
    for (final custom in state['customLiturgies'] as List) {
      clear(custom['items'] as List);
    }
    if (changed) await saveState(state, enqueue: false);
  }

  Map<String, dynamic>? _custom(Map<String, dynamic> state, String key) {
    if (!key.startsWith('custom:')) return null;
    return (state['customLiturgies'] as List)
        .whereType<Map<String, dynamic>>()
        .where((e) => e['id'] == key.substring(7))
        .firstOrNull;
  }

  bool _weekday(String key) => LiturgyWeekday.values.any((e) => e.name == key);
  List<LiturgyItem> readItems(String key) {
    final state = loadState();
    final raw = _weekday(key)
        ? state['weekdays'][key]
        : _custom(state, key)?['items'];
    return (raw as List? ?? [])
        .map((e) => LiturgyItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> writeItems(String key, List<LiturgyItem> items) async {
    final state = loadState();
    if (_weekday(key)) {
      state['weekdays'][key] = items.map((e) => e.toJson()).toList();
    } else {
      final custom = _custom(state, key);
      if (custom == null) return;
      custom['items'] = items.map((e) => e.toJson()).toList();
    }
    await saveState(state);
  }

  String readNotes(String key) {
    final state = loadState();
    return (_weekday(key)
                ? state['dayNotes'][key]
                : _custom(state, key)?['notes'])
            as String? ??
        '';
  }

  Future<void> writeNotes(String key, String notes) async {
    final state = loadState();
    if (_weekday(key)) {
      state['dayNotes'][key] = notes;
    } else {
      final custom = _custom(state, key);
      if (custom == null) return;
      custom['notes'] = notes;
    }
    await saveState(state);
  }

  Map<String, dynamic> readSessionTimes(String key) {
    final state = loadState();
    return _weekday(key)
        ? Map<String, dynamic>.from(state['daySessionTimes'][key] as Map)
        : _times(_custom(state, key) ?? {});
  }

  Future<void> writeSessionTimes(
    String key, {
    String? startTime,
    String? endTime,
  }) async {
    final state = loadState();
    final times = _times({'startTime': startTime, 'endTime': endTime});
    if (_weekday(key)) {
      state['daySessionTimes'][key] = times;
    } else {
      final custom = _custom(state, key);
      if (custom == null) return;
      custom.addAll(times);
    }
    await saveState(state);
  }

  bool readLock(String key) => loadState()['deletionLocks'][key] == true;
  Future<void> writeLock(String key, bool locked) async {
    final state = loadState();
    if (locked) {
      state['deletionLocks'][key] = true;
    } else {
      (state['deletionLocks'] as Map).remove(key);
    }
    await saveState(state);
  }

  List<CustomLiturgy> loadCustomLiturgies() =>
      (loadState()['customLiturgies'] as List)
          .map((e) => CustomLiturgy.fromJson(e as Map<String, dynamic>))
          .toList();
  Future<CustomLiturgy> createCustom(String name) async {
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    final custom = CustomLiturgy(id: _newId(), name: name.trim());
    final state = loadState();
    state['customLiturgies'].add(custom.toJson());
    await saveState(state);
    return custom;
  }

  Future<void> renameCustom(String id, String name) async {
    if (name.trim().isEmpty) return;
    final state = loadState();
    final custom = _custom(state, 'custom:$id');
    if (custom == null) return;
    custom['name'] = name.trim();
    await saveState(state);
  }

  Future<void> deleteCustom(String id) async {
    final state = loadState();
    (state['customLiturgies'] as List).removeWhere((e) => e['id'] == id);
    (state['deletionLocks'] as Map).remove('custom:$id');
    await saveState(state);
  }

  static List<LiturgyItem> cloneItems(List<LiturgyItem> source) {
    final ids = {for (final item in source) item.id: _newId()};
    return source
        .map(
          (item) => LiturgyItem.fromJson({
            ...item.toJson(),
            'id': ids[item.id],
            'categoryId': ids[item.categoryId],
            'done': false,
          }),
        )
        .toList();
  }

  Future<void> cloneContext(String from, String to) =>
      writeItems(to, cloneItems(readItems(from)));

  List<LiturgyItem> loadItems(LiturgyWeekday day) => readItems(day.name);
  Future<void> saveItems(LiturgyWeekday day, List<LiturgyItem> items) =>
      writeItems(day.name, items);
  String loadNotes(LiturgyWeekday day) => readNotes(day.name);
  Future<void> saveNotes(LiturgyWeekday day, String notes) =>
      writeNotes(day.name, notes);
  Future<void> cloneDay(LiturgyWeekday from, LiturgyWeekday to) async {
    await cloneContext(from.name, to.name);
    await saveNotes(to, loadNotes(from));
  }

  Future<void> clearDay(LiturgyWeekday day) async {
    final state = loadState();
    state['weekdays'][day.name] = <dynamic>[];
    state['dayNotes'][day.name] = '';
    await saveState(state);
  }

  bool isLocked(LiturgyWeekday day) => readLock(day.name);
  Future<void> setLocked(LiturgyWeekday day, bool locked) =>
      writeLock(day.name, locked);
  Future<void> saveOrder(LiturgyWeekday day, List<String> ids) async {
    await _prefs.setString('liturgy_order_${day.name}', jsonEncode(ids));
  }

  List<String> loadOrder(LiturgyWeekday day) {
    try {
      return (jsonDecode(_prefs.getString('liturgy_order_${day.name}') ?? '[]')
              as List)
          .cast<String>();
    } catch (_) {
      return [];
    }
  }

  List<LiturgyItem> _legacyItems(String key) {
    try {
      return (jsonDecode(_prefs.getString(key) ?? '[]') as List)
          .map((e) => LiturgyItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _date(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  Future<void> saveAvulsa(DateTime date, List<LiturgyItem> items) async {
    final stamp = _date(date);
    final state = loadState();
    var custom = _custom(state, 'custom:legacy-$stamp');
    if (custom == null) {
      custom = {
        'id': 'legacy-$stamp',
        'name':
            '${stamp.substring(6, 8)}/${stamp.substring(4, 6)}/${stamp.substring(0, 4)}',
        'items': <dynamic>[],
        'notes': '',
        'startTime': null,
        'endTime': null,
      };
      state['customLiturgies'].add(custom);
    }
    custom['items'] = items.map((e) => e.toJson()).toList();
    await _prefs.setString(
      'liturgy_avulsa_$stamp',
      jsonEncode(custom['items']),
    );
    await saveState(state);
  }

  List<LiturgyItem> loadAvulsa(DateTime date) {
    final key = 'custom:legacy-${_date(date)}';
    return readItems(key);
  }

  Future<void> clearAvulsa(DateTime date) async {
    await _prefs.remove('liturgy_avulsa_${_date(date)}');
    await deleteCustom('legacy-${_date(date)}');
  }
}
