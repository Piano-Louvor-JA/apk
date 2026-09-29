import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:louvorja_piano_mobile/domain/entities/custom_auth.dart';

/// Persistência da sessão custom em storage seguro.
///
/// Token NUNCA vai pra SharedPreferences (requisito de segurança da spec).
/// A sessão é gravada como JSON único — ler/clear são operações atômicas.
class CustomSessionStore {
  static const _key = 'louvorja.custom.session';
  final FlutterSecureStorage _storage;

  CustomSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> save(CustomSession session) async {
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'token': session.token,
        'user': session.user.toJson(),
      }),
    );
  }

  /// Sessão salva ou null (nunca lança — dado corrompido = sessão limpa).
  Future<CustomSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CustomSession(
        token: map['token'] as String,
        user: CustomUser.fromJson(map['user'] as Map<String, dynamic>),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
