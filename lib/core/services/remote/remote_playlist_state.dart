class RemotePlaylistItem {
  const RemotePlaylistItem({
    required this.musicId,
    required this.title,
    this.albumId,
  });
  final int musicId;
  final int? albumId;
  final String title;
  Map<String, dynamic> toJson() => {
    'musicId': musicId,
    'albumId': albumId,
    'title': title,
  };
}

class RemotePlaylist {
  const RemotePlaylist({
    required this.id,
    required this.name,
    required this.items,
  });
  final String id, name;
  final List<RemotePlaylistItem> items;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

/// Catálogo de playlists e fila de reprodução do desktop conectado.
class RemotePlaylistState {
  const RemotePlaylistState({
    required this.lists,
    this.queue = const [],
    this.queueIndex = -1,
    this.queueLabel,
    this.shuffled = false,
    this.currentMusicId,
  });
  final List<RemotePlaylist> lists;
  final List<RemotePlaylistItem> queue;
  final int queueIndex;
  final String? queueLabel;
  final bool shuffled;
  final int? currentMusicId;
  Map<String, dynamic> toJson() => {
    'lists': lists.map((list) => list.toJson()).toList(),
    'queue': queue.map((item) => item.toJson()).toList(),
    'queueIndex': queueIndex,
    'queueLabel': queueLabel,
    'shuffled': shuffled,
    'currentMusicId': currentMusicId,
  };
  static List<RemotePlaylistItem> _items(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .where(
          (item) =>
              item['musicId'] is num &&
              item['musicId'] != 0 &&
              item['title'] is String,
        )
        .map(
          (item) => RemotePlaylistItem(
            musicId: (item['musicId'] as num).toInt(),
            title: item['title'] as String,
            albumId: (item['albumId'] as num?)?.toInt(),
          ),
        )
        .toList();
  }

  static RemotePlaylistState? parse(Object? raw) {
    if (raw is! Map) return null;
    try {
      return RemotePlaylistState(
        lists: (raw['lists'] as List? ?? [])
            .whereType<Map>()
            .where((list) => list['id'] is String && list['name'] is String)
            .map(
              (list) => RemotePlaylist(
                id: list['id'] as String,
                name: list['name'] as String,
                items: _items(list['items']),
              ),
            )
            .toList(),
        queue: _items(raw['queue']),
        queueIndex: (raw['queueIndex'] as num?)?.toInt() ?? -1,
        queueLabel: raw['queueLabel'] as String?,
        shuffled: raw['shuffled'] == true,
        currentMusicId: (raw['currentMusicId'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
