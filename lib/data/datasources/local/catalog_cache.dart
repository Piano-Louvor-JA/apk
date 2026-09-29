library;

import 'dart:convert';
import 'dart:io';

/// Cache de catálogo em disco com TTL e invalidação por hash.
///
/// Em Web, usar [CatalogCache.noop] — todas operações são no-op.
class CatalogCache {
  final Directory? _dir;
  final DateTime Function() _now;

  static const _ttl = Duration(hours: 24);

  CatalogCache(this._dir, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Construtor para Web: sem sistema de arquivos.
  /// Todas operações retornam null/no-op silenciosamente.
  const CatalogCache.noop({DateTime Function()? now})
    : _dir = null,
      _now = DateTime.now;

  File? _file(String key) =>
      _dir == null ? null : File('${_dir.path}/catalog_$key.json');

  /// Lista todas as chaves atualmente em cache no diretório.
  /// Retorna vazio em Web (noop).
  List<String> listKeys() {
    if (_dir == null) return const [];
    if (!_dir.existsSync()) return const [];
    return _dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.startsWith('catalog_') && name.endsWith('.json'))
        .map(
          (name) =>
              name.substring('catalog_'.length, name.length - '.json'.length),
        )
        .toList();
  }

  /// Lê o JSON do cache se existir e for válido.
  /// Retorna null se expirado, inexistente ou Web (noop).
  dynamic read(String key) {
    final f = _file(key);
    if (f == null || !f.existsSync()) return null;

    try {
      final stat = f.statSync();
      if (_now().difference(stat.modified) > _ttl) return null;

      final content = f.readAsStringSync();
      return jsonDecode(content);
    } catch (_) {
      return null;
    }
  }

  /// Lê o cache IGNORANDO o TTL — última instância quando a API está fora.
  ///
  /// Catálogo religioso muda raramente (novo hinário/CD por ano): melhor
  /// servir dados de ontem do que tela de erro. Usado apenas como fallback
  /// no catch de falha de rede, nunca como fonte primária.
  dynamic readStale(String key) {
    final f = _file(key);
    if (f == null || !f.existsSync()) return null;

    try {
      return jsonDecode(f.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  /// Escreve JSON no cache.
  void write(String key, dynamic data) {
    final f = _file(key);
    if (f == null) return;

    try {
      if (_dir != null && !_dir.existsSync()) _dir.createSync(recursive: true);
      f.writeAsStringSync(jsonEncode(data));
    } catch (_) {
      // Cache é best-effort; falha de escrita não quebra o app.
    }
  }

  /// Remove entrada do cache.
  void evict(String key) {
    final f = _file(key);
    try {
      f?.deleteSync();
    } catch (_) {}
  }

  /// Limpa todo o cache.
  void clear() {
    if (_dir == null) return;
    try {
      for (final f in _dir.listSync()) {
        if (f is File && f.path.contains('catalog_')) {
          f.deleteSync();
        }
      }
    } catch (_) {}
  }
}
