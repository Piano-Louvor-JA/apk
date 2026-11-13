import 'package:louvorja_piano_mobile/core/services/liturgy/quarter_paste_parser.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy_music_search.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

class QuarterPasteReport {
  const QuarterPasteReport({
    required this.created,
    required this.errors,
    required this.unmappedSlots,
  });
  final int created;
  final List<String> errors;
  final List<String> unmappedSlots;
}

/// Aplicação da programação do trimestre, conforme useScheduledDialog.ts.
class ScheduledPlanning {
  const ScheduledPlanning(this.repository);
  final ScheduledRepository repository;
  static String slotKey(String raw) =>
      LiturgyMusicSearch.normalize(raw).replaceAll(' ', '');
  Future<QuarterPasteReport> paste(
    String text, {
    required int year,
    Map<String, String> slotMapping = const {},
    bool autoCreateSlots = false,
  }) async {
    final parsed = QuarterPasteParser.parse(text, year: year);
    final unmapped = <String>[];
    var created = 0;
    final categories = repository.loadCategories();
    final items = repository.loadItems();
    final mapping = {
      for (final entry in slotMapping.entries) slotKey(entry.key): entry.value,
    };
    for (final group in parsed.groups) {
      for (final entry in group.entries) {
        final key = slotKey(entry.slotKey);
        var categoryId =
            mapping[key] ??
            categories.where((e) => slotKey(e.name) == key).firstOrNull?.id;
        if (categoryId == null && autoCreateSlots) {
          final label = entry.slotKey
              .split(RegExp(r'\s+'))
              .map(
                (w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
              )
              .join(' ');
          final category = ScheduledCategory(
            id: 'rot-${ScheduledRepository.newId()}',
            name: label,
          );
          categories.add(category);
          categoryId = category.id;
          mapping[key] = categoryId;
        }
        if (categoryId == null) {
          unmapped.add(entry.slotKey);
          continue;
        }
        final raw = entry.filePath ?? entry.name;
        final content = entry.musicId != null
            ? <String, dynamic>{'kind': 'music', 'musicId': entry.musicId}
            : RegExp(r'^https?://', caseSensitive: false).hasMatch(raw)
            ? <String, dynamic>{'kind': 'online_video', 'url': raw}
            : <String, dynamic>{'kind': 'file', 'filePath': raw};
        final stamp = group.date.toIso8601String().substring(0, 10);
        final id =
            'sch-$stamp-$categoryId-${entry.musicId ?? ScheduledRepository.newId()}';
        final item = ScheduledItem(
          id: id,
          categoryId: categoryId,
          date: group.date,
          name: entry.name.isNotEmpty
              ? entry.name
              : entry.filePath ?? '#${entry.musicId ?? ''}',
          filePath: content['filePath'] as String? ?? '',
          content: content,
        );
        final index = items.indexWhere((e) => e.id == id);
        if (index < 0) {
          items.add(item);
        } else {
          items[index] = item;
        }
        created++;
      }
    }
    await repository.saveCategories(categories);
    await repository.saveItems(items);
    return QuarterPasteReport(
      created: created,
      errors: parsed.errors,
      unmappedSlots: unmapped,
    );
  }

  Future<int> duplicateQuarter(
    String categoryId, {
    required DateTime from,
    required int weeks,
  }) async {
    final items = repository.loadItems();
    final source = items
        .where((e) => e.categoryId == categoryId && !e.date.isBefore(from))
        .toList();
    var created = 0;
    for (final entry in source) {
      final date = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day + weeks * 7,
      );
      if (items.any(
        (e) =>
            e.categoryId == categoryId &&
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day,
      ))
        continue;
      items.add(
        ScheduledItem(
          id: '${entry.id}-w$weeks',
          categoryId: categoryId,
          date: date,
          name: entry.name,
          filePath: entry.filePath,
          content: entry.content,
        ),
      );
      created++;
    }
    await repository.saveItems(items);
    return created;
  }
}
