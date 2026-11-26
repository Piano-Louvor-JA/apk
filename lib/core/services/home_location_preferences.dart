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

  /// Ultimo distrito/igreja nao vazios ja digitados (por campo). Local: nao
  /// sincroniza. A telemetria usa quando o campo foi apagado (mesma chave do
  /// desktop: `home.locationLastKnown`).
  static const lastKnownKey = 'home.locationLastKnown';

  /// Avisa quem escuta (heartbeat da telemetria) que o usuario salvou.
  static final ValueNotifier<int> savedChanges = ValueNotifier<int>(0);

  /// Avisa a Home quando o valor mudou fora dela (pull do sync v2).
  static final ValueNotifier<int> externalChanges = ValueNotifier<int>(0);

  const HomeLocationPreferences._();

  static void notifyExternalChange() => externalChanges.value++;

  static HomeLocation _read(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.getString(key);
      return raw == null
          ? const HomeLocation()
          : HomeLocation.fromJson(jsonDecode(raw));
    } catch (_) {
      return const HomeLocation();
    }
  }

  static String _firstFilled(String a, String b, String c) =>
      a.isNotEmpty ? a : (b.isNotEmpty ? b : c);

  static Future<HomeLocation> loadLastKnown() async {
    try {
      return _read(await SharedPreferences.getInstance(), lastKnownKey);
    } catch (_) {
      return const HomeLocation();
    }
  }

  /// Distrito/igreja para a telemetria: o campo atual; se estiver vazio, o
  /// ultimo valor ja digitado nele.
  static Future<HomeLocation> resolveReported() async {
    final current = await load();
    final known = await loadLastKnown();
    return HomeLocation(
      district: current.district.isNotEmpty ? current.district : known.district,
      church: current.church.isNotEmpty ? current.church : known.church,
    );
  }

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
      // Le antes de sobrescrever: quem preencheu antes desta versao (ou
      // recebeu pelo sync) e apaga agora ainda tem o valor guardado.
      final previous = _read(prefs, storageKey);
      final known = _read(prefs, lastKnownKey);
      final next = HomeLocation.fromJson(location.toJson());
      await prefs.setString(storageKey, jsonEncode(next.toJson()));
      final lastKnown = HomeLocation(
        district: _firstFilled(
          next.district,
          previous.district,
          known.district,
        ),
        church: _firstFilled(next.church, previous.church, known.church),
      );
      if (lastKnown.district != known.district ||
          lastKnown.church != known.church) {
        await prefs.setString(lastKnownKey, jsonEncode(lastKnown.toJson()));
      }
    } catch (_) {
      // Best-effort: a tela continua com o valor digitado.
    }
    savedChanges.value++;
    try {
      await outbox?.call(storageKey, location.toJson());
    } catch (_) {
      // outbox nunca bloqueia
    }
  }
}
