import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Playlist: seleção de hinos do ACERVO OFICIAL (musicId + albumId),
/// salva localmente no dispositivo — paridade 1:1 com o playlist-storage.ts
/// do web (localStorage → SharedPreferences aqui).
///
/// DIFERENTE de coletânea personalizada: coletânea = músicas criadas/
/// importadas pelo usuário (com letra/áudio/timing, via API custom).
/// Playlist = só referências do catálogo, 100% local, sem auth.
class PlaylistStorage {
  static const _key = 'louvorja.playlists';

  final Future<SharedPreferences> Function() _prefs;

  PlaylistStorage({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  Future<List<Playlist>> read() async {
    final prefs = await _prefs();
    final value = prefs.getString(_key);
    if (value == null) return const [];
    try {
      final parsed = jsonDecode(value);
      if (parsed is! List) return const [];
      return parsed
          .whereType<Map<String, dynamic>>()
          .map(Playlist.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _write(List<Playlist> playlists) async {
    final prefs = await _prefs();
    await prefs.setString(
      _key,
      jsonEncode([for (final p in playlists) p.toJson()]),
    );
  }

  Future<List<Playlist>> list() => read();

  /// Salva a lista inteira (usado por import/merge futuro).
  Future<void> saveAll(List<Playlist> playlists) => _write(playlists);

  Future<Playlist> create(String name) async {
    final now = DateTime.now().toUtc();
    final playlist = Playlist(
      id: _uuid(),
      name: name.trim(),
      items: const [],
      createdAt: now,
      updatedAt: now,
    );
    await _write([...await read(), playlist]);
    return playlist;
  }

  Future<Playlist?> rename(String id, String name) async {
    final playlists = await read();
    final index = playlists.indexWhere((p) => p.id == id);
    if (index == -1) return null;
    final updated = playlists[index].withName(name.trim());
    playlists[index] = updated;
    await _write(playlists);
    return updated;
  }

  Future<bool> delete(String id) async {
    final playlists = await read();
    final next = playlists.where((p) => p.id != id).toList();
    if (next.length == playlists.length) return false;
    await _write(next);
    return true;
  }

  /// Adiciona faixa no fim. Evita toque duplo criar a mesma faixa duas
  /// vezes seguidas (mesma regra do web).
  Future<AddPlaylistItemResult?> addItem(String id, PlaylistItem item) async {
    final playlists = await read();
    final index = playlists.indexWhere((p) => p.id == id);
    if (index == -1) return null;
    final playlist = playlists[index];
    final last = playlist.items.isEmpty ? null : playlist.items.last;
    final added =
        last == null ||
        last.musicId != item.musicId ||
        last.albumId != item.albumId;
    if (!added) return AddPlaylistItemResult(playlist: playlist, added: false);
    final updated = playlist.withItems([...playlist.items, item]);
    playlists[index] = updated;
    await _write(playlists);
    return AddPlaylistItemResult(playlist: updated, added: true);
  }

  Future<Playlist?> removeItem(String id, int index) async {
    final playlists = await read();
    final listIndex = playlists.indexWhere((p) => p.id == id);
    if (listIndex == -1) return null;
    final playlist = playlists[listIndex];
    if (index < 0 || index >= playlist.items.length) return null;
    final items = [...playlist.items]..removeAt(index);
    final updated = playlist.withItems(items);
    playlists[listIndex] = updated;
    await _write(playlists);
    return updated;
  }
}

class AddPlaylistItemResult {
  final Playlist playlist;
  final bool added;

  const AddPlaylistItemResult({required this.playlist, required this.added});
}

class Playlist {
  final String id;
  final String name;
  final List<PlaylistItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PlaylistItem.fromJson)
        .toList(),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now().toUtc(),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
        DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': [for (final i in items) i.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Playlist withName(String newName) => Playlist(
    id: id,
    name: newName,
    items: items,
    createdAt: createdAt,
    updatedAt: DateTime.now().toUtc(),
  );

  Playlist withItems(List<PlaylistItem> newItems) => Playlist(
    id: id,
    name: name,
    items: newItems,
    createdAt: createdAt,
    updatedAt: DateTime.now().toUtc(),
  );
}

class PlaylistItem {
  final int musicId;
  final int? albumId;
  final String title;

  const PlaylistItem({
    required this.musicId,
    this.albumId,
    required this.title,
  });

  factory PlaylistItem.fromJson(Map<String, dynamic> json) => PlaylistItem(
    musicId: (json['musicId'] as num).toInt(),
    albumId: json['albumId'] == null ? null : (json['albumId'] as num).toInt(),
    title: json['title'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'musicId': musicId,
    'albumId': albumId,
    'title': title,
  };
}

/// UUID v4 simplificado (web usa crypto.randomUUID; formato aqui é
/// interno ao dispositivo — só precisa ser único).
String _uuid() {
  final rand = DateTime.now().microsecondsSinceEpoch;
  final hex = rand.toRadixString(16).padLeft(12, '0');
  return '$hex-$hex-${DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(16)}'
      .substring(0, 36);
}
