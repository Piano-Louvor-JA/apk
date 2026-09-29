import 'dart:convert';
import 'dart:io';

/// Store local (offline-first) de músicas e coletâneas criadas SEM auth.
///
/// O usuário pode criar músicas/coletâneas sem conta — ficam salvas só
/// neste dispositivo (JSON em app-support dir), nunca vão pra API. Se um
/// dia ele logar, um "publicar" futuro pode promovê-las; por ora é
/// somente-local.
///
/// Em Web (kIsWeb / dir null) vira no-op em memória — a camada de UI
/// funciona igual, mas nada persiste (limitação conhecida do sandbox web).
class LocalCustomStore {
  final Directory? _dir;
  final Map<String, dynamic> _memWeb;

  LocalCustomStore(this._dir) : _memWeb = {};
  const LocalCustomStore.noop() : _dir = null, _memWeb = const {};

  File? _file() => _dir == null ? null : File('${_dir.path}/local_custom.json');

  Map<String, dynamic> _read() {
    final f = _file();
    if (f == null) return _memWeb;
    if (!f.existsSync()) return {};
    try {
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void _write(Map<String, dynamic> data) {
    final snapshot = Map<String, dynamic>.of(
      data,
    ); // cópia ANTES de tocar em _memWeb
    final f = _file();
    if (f == null) {
      _memWeb.clear();
      _memWeb.addAll(snapshot);
      return;
    }
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(snapshot));
  }

  // ---------- Coletâneas locais ----------

  List<Map<String, dynamic>> listLocalCollections() {
    final data = _read();
    return (data['collections'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// id negativo p/ não colidir com ids da API (positivos).
  Map<String, dynamic> createLocalCollection(String name, {String? author}) {
    final data = _read();
    final collections = (data['collections'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final minId = collections
        .map((c) => (c['id'] as num).toInt())
        .fold(0, (a, b) => a < b ? a : b);
    final coll = {
      'id': minId - 1,
      'name': name,
      'author': author ?? 'Este dispositivo',
      'created_at': DateTime.now().toIso8601String(),
    };
    collections.add(coll);
    data['collections'] = collections;
    _write(data);
    return coll;
  }

  void renameLocalCollection(int id, String name) {
    final data = _read();
    final collections = (data['collections'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final c in collections) {
      if ((c['id'] as num).toInt() == id) c['name'] = name;
    }
    data['collections'] = collections;
    _write(data);
  }

  void deleteLocalCollection(int id) {
    final data = _read();
    final collections = (data['collections'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    collections.removeWhere((c) => (c['id'] as num).toInt() == id);
    data['collections'] = collections;
    _write(data);
  }

  // ---------- Músicas locais ----------

  List<Map<String, dynamic>> listLocalMusics(int collectionId) {
    final data = _read();
    return ((data['musics'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .where((m) => (m['collection_id'] as num).toInt() == collectionId))
        .toList();
  }

  Map<String, dynamic> saveLocalMusic({
    required int collectionId,
    required String name,
    String? lyric,
    String? audioPath,
    List<Map<String, dynamic>>? slides,
  }) {
    final data = _read();
    final musics = (data['musics'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final minId = musics
        .map((m) => (m['id'] as num).toInt())
        .fold(0, (a, b) => a < b ? a : b);
    final music = {
      'id': minId - 1,
      'collection_id': collectionId,
      'name': name,
      'lyric': lyric,
      'audio_path': audioPath,
      'slides': slides ?? const [],
      'created_at': DateTime.now().toIso8601String(),
    };
    musics.add(music);
    data['musics'] = musics;
    _write(data);
    return music;
  }

  void deleteLocalMusic(int id) {
    final data = _read();
    final musics = (data['musics'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    musics.removeWhere((m) => (m['id'] as num).toInt() == id);
    data['musics'] = musics;
    _write(data);
  }
}
