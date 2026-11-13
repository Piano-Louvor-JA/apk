/// Estado dos anúncios existentes no desktop, sem caminhos de arquivos locais.
class RemoteAnnouncement {
  const RemoteAnnouncement({
    required this.id,
    required this.title,
    required this.kind,
    this.text = '',
    this.inCarousel = false,
    this.fileCount = 0,
    this.fileName = '',
  });
  final String id, title, kind, text, fileName;
  final bool inCarousel;
  final int fileCount;
  bool get supportsCarousel => kind == 'text' || kind == 'images';
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind,
    'text': text,
    'inCarousel': inCarousel,
    'fileCount': fileCount,
    'fileName': fileName,
  };
}

class RemoteAnnouncementList {
  const RemoteAnnouncementList({
    required this.id,
    required this.name,
    required this.items,
  });
  final String id, name;
  final List<RemoteAnnouncement> items;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class RemoteAnnouncementsState {
  const RemoteAnnouncementsState({
    required this.activeListId,
    required this.lists,
    this.slideMs = 5000,
    this.loop = true,
    this.status = 'idle',
    this.slideIndex = 0,
    this.slideCount = 0,
    this.previewTitle = '',
    this.previewText = '',
  });
  final String activeListId, status, previewTitle, previewText;
  final List<RemoteAnnouncementList> lists;
  final int slideMs, slideIndex, slideCount;
  final bool loop;
  RemoteAnnouncementList? get activeList {
    for (final list in lists) {
      if (list.id == activeListId) return list;
    }
    return lists.isEmpty ? null : lists.first;
  }

  bool get active => status != 'idle';
  Map<String, dynamic> toJson() => {
    'activeListId': activeListId,
    'lists': lists.map((list) => list.toJson()).toList(),
    'slideMs': slideMs,
    'loop': loop,
    'status': status,
    'slideIndex': slideIndex,
    'slideCount': slideCount,
    'previewTitle': previewTitle,
    'previewText': previewText,
  };
  static RemoteAnnouncementsState? parse(Object? raw) {
    if (raw is! Map) return null;
    try {
      final lists = <RemoteAnnouncementList>[];
      for (final entry in (raw['lists'] as List? ?? const [])) {
        if (entry is! Map ||
            entry['id'] is! String ||
            entry['name'] is! String) {
          continue;
        }
        final items = <RemoteAnnouncement>[];
        for (final item in (entry['items'] as List? ?? const [])) {
          if (item is! Map ||
              item['id'] is! String ||
              item['kind'] is! String) {
            continue;
          }
          items.add(
            RemoteAnnouncement(
              id: item['id'] as String,
              title: item['title'] as String? ?? '',
              kind: item['kind'] as String,
              text: item['text'] as String? ?? '',
              fileName: item['fileName'] as String? ?? '',
              fileCount: (item['fileCount'] as num?)?.toInt() ?? 0,
              inCarousel: item['inCarousel'] == true,
            ),
          );
        }
        lists.add(
          RemoteAnnouncementList(
            id: entry['id'] as String,
            name: entry['name'] as String,
            items: items,
          ),
        );
      }
      return RemoteAnnouncementsState(
        activeListId: raw['activeListId'] as String? ?? '',
        lists: lists,
        slideMs: (raw['slideMs'] as num?)?.toInt() ?? 5000,
        loop: raw['loop'] != false,
        status: raw['status'] as String? ?? 'idle',
        slideIndex: (raw['slideIndex'] as num?)?.toInt() ?? 0,
        slideCount: (raw['slideCount'] as num?)?.toInt() ?? 0,
        previewTitle: raw['previewTitle'] as String? ?? '',
        previewText: raw['previewText'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
