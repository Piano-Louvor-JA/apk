library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Distrito e igreja exibidos na tela inicial.
class HomeLocation {
  final String district;
  final String church;

  const HomeLocation({this.district = '', this.church = ''});

  /// Valor fora do formato esperado vira vazio (normalizeHomeLocation do app).
  factory HomeLocation.fromJson(Object? raw) {
    if (raw is! Map) return const HomeLocation();
    return HomeLocation(
      district: _asTrimmedString(raw['district']),
      church: _asTrimmedString(raw['church']),
    );
  }

  Map<String, String> toJson() => {
    'district': district.trim(),
    'church': church.trim(),
  };

  static String _asTrimmedString(Object? value) =>
      value is String ? value.trim() : '';
}

/// Persistencia local de distrito e igreja.
///
/// Fonte: pianolouvorja/app/src/modules/home/services/home-preferences.ts
/// Mesma chave e mesmo formato do desktop: `home.location` com
/// `{district, church}`, sempre sem espacos nas pontas.
class HomeLocationPreferences {
  static const storageKey = 'home.location';

  /// Avisa a Home quando o valor mudou fora dela (pull do sync v2).
  static final ValueNotifier<int> externalChanges = ValueNotifier<int>(0);

  const HomeLocationPreferences._();

  static void notifyExternalChange() => externalChanges.value++;

  /// Falha de leitura ou valor invalido retorna vazio: a Home nunca quebra
  /// por causa de preferencia.
  static Future<HomeLocation> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return const HomeLocation();
      return HomeLocation.fromJson(jsonDecode(raw));
    } catch (_) {
      return const HomeLocation();
    }
  }

  /// [outbox] enfileira a mudanca para o sync. Falha no sync nunca impede o
  /// salvamento local, e vice-versa.
  static Future<void> save(
    HomeLocation location, {
    Future<void> Function(String key, Object? value)? outbox,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(location.toJson()));
    } catch (_) {
      // Best-effort: a tela continua com o valor digitado.
    }
    try {
      await outbox?.call(storageKey, location.toJson());
    } catch (_) {
      // outbox nunca bloqueia
    }
  }
}
