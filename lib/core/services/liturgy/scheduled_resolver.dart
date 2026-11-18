import 'package:louvorja_piano_mobile/core/services/music_search.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

/// Resolve a rotação na data do culto, como scheduled-resolver.ts do desktop.
abstract final class ScheduledResolver {
  static Map<String, dynamic> toContent(LiturgyItem item) =>
      switch (item.type) {
        LiturgyItemType.music => {
          'kind': 'music',
          'musicId': item.musicId,
          'musicMode': item.musicMode ?? 'audio',
        },
        LiturgyItemType.verse => {
          'kind': 'verse',
          'verseBookId': item.verseBookId,
          'verseChapter': item.verseChapter,
          'verseNumbers': item.verseNumbers ?? '',
        },
        LiturgyItemType.annotation => {
          'kind': 'annotation',
          'text': item.subtitle.isNotEmpty ? item.subtitle : item.notes ?? '',
        },
        LiturgyItemType.onlineVideo => {
          'kind': 'online_video',
          'url': item.url ?? '',
          'name': item.name,
        },
        _ => {
          'kind': 'file',
          'filePath': item.filePath ?? item.filePaths.firstOrNull ?? '',
        },
      };
  static LiturgyItemType fileType(String path) {
    final ext = path.toLowerCase().split('?').first.split('.').last;
    if (['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'].contains(ext))
      return LiturgyItemType.audio;
    if (['mp4', 'mkv', 'avi', 'webm', 'mov', 'm4v'].contains(ext))
      return LiturgyItemType.video;
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext))
      return LiturgyItemType.images;
    if (ext == 'pdf') return LiturgyItemType.pdf;
    if (['ppt', 'pptx', 'odp'].contains(ext))
      return LiturgyItemType.presentation;
    return LiturgyItemType.otherFiles;
  }

  static String? rotationId(
    LiturgyItem item,
    List<ScheduledCategory> categories,
  ) {
    if (item.type != LiturgyItemType.scheduled) return null;
    if (item.scheduledRotationId?.trim().isNotEmpty == true)
      return item.scheduledRotationId;
    final name = MusicSearch.fold(item.name.trim());
    if (name.isEmpty) return null;
    final matches = categories
        .where((e) => MusicSearch.fold(e.name.trim()) == name)
        .toList();
    return matches.length == 1 ? matches.single.id : null;
  }

  static LiturgyItem? resolve(
    LiturgyItem placeholder,
    DateTime date,
    List<ScheduledCategory> categories,
    List<ScheduledItem> items,
  ) {
    final rotation = rotationId(placeholder, categories);
    if (rotation == null || !categories.any((e) => e.id == rotation))
      return null;
    final entry = items
        .where(
          (e) =>
              e.categoryId == rotation &&
              e.date.year == date.year &&
              e.date.month == date.month &&
              e.date.day == date.day,
        )
        .firstOrNull;
    if (entry == null) return null;
    final content =
        entry.content ??
        (entry.filePath.trim().isEmpty
            ? null
            : <String, dynamic>{'kind': 'file', 'filePath': entry.filePath});
    if (content == null) return null;
    final base = <String, dynamic>{
      'id': placeholder.id,
      'name': entry.name.trim().isEmpty ? placeholder.name : entry.name,
      'categoryId': placeholder.categoryId,
      'done': placeholder.done,
      'notes': entry.notes,
    };
    switch (content['kind']) {
      case 'music':
        if (content['musicId'] is! num) return null;
        return LiturgyItem.fromJson({
          ...base,
          'type': 'music',
          'musicId': content['musicId'],
          'musicMode': content['musicMode'] ?? 'audio',
        });
      case 'file':
        final path = content['filePath'];
        if (path is! String || path.trim().isEmpty) return null;
        return LiturgyItem(
          id: placeholder.id,
          type: fileType(path),
          name: base['name'] as String,
          categoryId: placeholder.categoryId,
          filePath: path,
          filePaths: [path],
          notes: entry.notes,
          done: placeholder.done,
        );
      case 'verse':
        if (content['verseBookId'] is! num || content['verseChapter'] is! num)
          return null;
        return LiturgyItem.fromJson({
          ...base,
          'type': 'verse',
          'verseBookId': content['verseBookId'],
          'verseChapter': content['verseChapter'],
          'verseNumbers': content['verseNumbers'] ?? '',
        });
      case 'annotation':
        final text = content['text'];
        if (text is! String || text.trim().isEmpty) return null;
        return LiturgyItem.fromJson({
          ...base,
          'type': 'annotation',
          'subtitle': text,
        });
      case 'online_video':
        final url = content['url'];
        if (url is! String || url.trim().isEmpty) return null;
        return LiturgyItem.fromJson({
          ...base,
          'type': 'online_video',
          'url': url,
        });
      default:
        return null;
    }
  }
}
