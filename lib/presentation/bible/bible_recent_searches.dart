library;

import 'package:shared_preferences/shared_preferences.dart';

/// Últimas buscas da Bíblia (passagens abertas e textos buscados), no
/// aparelho. Mais recente primeiro, sem repetição.
class BibleRecentSearches {
  static const _key = 'bible_recent_searches';
  static const _max = 8;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  static Future<void> add(String entry) async {
    final value = entry.trim();
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? const <String>[];
    final next = [
      value,
      ...current.where((e) => e.toLowerCase() != value.toLowerCase()),
    ].take(_max).toList();
    await prefs.setStringList(_key, next);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
