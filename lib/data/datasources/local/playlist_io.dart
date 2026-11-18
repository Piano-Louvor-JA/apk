library;

import 'dart:convert';

import 'playlist_storage.dart';

/// Arquivo de playlists no MESMO formato do desktop
/// (app: src/modules/albums/services/playlist-io.ts): o .json exportado
/// num abre no outro.
class PlaylistIo {
  static String encode(List<Playlist> playlists) =>
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'kind': 'playlists',
        'playlists': [for (final p in playlists) p.toJson()],
      });

  /// Valida o arquivo; itens inválidos são descartados. Null = inválido.
  static List<Playlist>? decode(String raw) {
    Object? data;
    try {
      data = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (data is! Map ||
        data['kind'] != 'playlists' ||
        data['version'] != 1 ||
        data['playlists'] is! List) {
      return null;
    }
    final out = <Playlist>[];
    for (final entry in data['playlists'] as List) {
      if (entry is! Map ||
          entry['id'] is! String ||
          entry['name'] is! String ||
          (entry['name'] as String).trim().isEmpty ||
          entry['items'] is! List) {
        continue;
      }
      final items = <PlaylistItem>[];
      for (final item in entry['items'] as List) {
        if (item is Map &&
            item['musicId'] is num &&
            (item['albumId'] == null || item['albumId'] is num) &&
            item['title'] is String &&
            (item['title'] as String).trim().isNotEmpty) {
          items.add(PlaylistItem.fromJson(item.cast<String, dynamic>()));
        }
      }
      out.add(
        Playlist.fromJson({
          ...entry.cast<String, dynamic>(),
          'name': (entry['name'] as String).trim(),
          'items': [for (final i in items) i.toJson()],
        }),
      );
    }
    return out.isEmpty ? null : out;
  }

  /// Merge por nome (igual ao desktop): playlist nova entra; existente
  /// ganha só as faixas que ainda não tem. Devolve (novas, faixas).
  static (List<Playlist>, int, int) merge(
    List<Playlist> current,
    List<Playlist> imported,
  ) {
    final result = [...current];
    var newLists = 0;
    var addedTracks = 0;
    for (final p in imported) {
      final i = result.indexWhere(
        (e) => e.name.toLowerCase() == p.name.toLowerCase(),
      );
      if (i < 0) {
        result.add(p);
        newLists += 1;
        addedTracks += p.items.length;
        continue;
      }
      final items = [...result[i].items];
      for (final item in p.items) {
        final dup = items.any(
          (e) => e.musicId == item.musicId && e.albumId == item.albumId,
        );
        if (!dup) {
          items.add(item);
          addedTracks += 1;
        }
      }
      result[i] = result[i].withItems(items);
    }
    return (result, newLists, addedTracks);
  }
}
