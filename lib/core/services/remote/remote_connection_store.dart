import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedRemoteConnection {
  const SavedRemoteConnection({
    required this.host,
    required this.port,
    required this.token,
    this.autoReconnect = true,
  });
  final String host;
  final int port;
  final String token;
  final bool autoReconnect;
  bool matches(SavedRemoteConnection other) =>
      host == other.host && port == other.port && token == other.token;
}

/// Credenciais ficam no armazenamento seguro; operações mantêm a ordem.
class RemoteConnectionStore {
  RemoteConnectionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const key = 'remote.last_successful_connection.v1';
  Future<void> _pending = Future.value();
  Future<SavedRemoteConnection?> _read() async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final host = data['host'] as String;
      final port = data['port'] as int;
      final token = data['token'] as String;
      if (host.trim().isEmpty || token.isEmpty || port < 1 || port > 65535) {
        return null;
      }
      return SavedRemoteConnection(
        host: host,
        port: port,
        token: token,
        autoReconnect: data['autoReconnect'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<SavedRemoteConnection?> read() async {
    await _pending;
    return _read();
  }

  Future<void> _write(SavedRemoteConnection value) => _storage.write(
    key: key,
    value: jsonEncode({
      'host': value.host,
      'port': value.port,
      'token': value.token,
      'autoReconnect': value.autoReconnect,
    }),
  );
  Future<void> save(SavedRemoteConnection value) =>
      _enqueue(() => _write(value));
  Future<void> disableAutoReconnect({SavedRemoteConnection? matching}) =>
      _enqueue(() async {
        final old = await _read();
        if (old == null || (matching != null && !old.matches(matching))) return;
        await _write(
          SavedRemoteConnection(
            host: old.host,
            port: old.port,
            token: old.token,
            autoReconnect: false,
          ),
        );
      });
  Future<void> _enqueue(Future<void> Function() action) {
    _pending = _pending.then((_) async {
      try {
        await action();
      } catch (_) {
        /* Falha local não derruba o controle remoto. */
      }
    });
    return _pending;
  }
}
