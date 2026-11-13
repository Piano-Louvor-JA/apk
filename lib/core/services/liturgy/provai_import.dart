import 'package:louvorja_piano_mobile/core/services/liturgy/provai_catalog.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

class ProvaiImportReport {
  const ProvaiImportReport(
    this.rotationId,
    this.created,
    this.skipped,
    this.skippedPast,
  );
  final String rotationId;
  final int created;
  final int skipped;
  final int skippedPast;
}

class ProvaiImport {
  const ProvaiImport(this.repository);
  final ScheduledRepository repository;
  Future<ProvaiImportReport> apply(
    ProvaiSource source,
    List<ProvaiEpisode> episodes,
    Future<String> Function(ProvaiEpisode) resolveLocalPath, {
    DateTime? now,
    bool onlyUpcoming = true,
    void Function(int, int)? onProgress,
  }) async {
    final rotation =
        repository
            .loadCategories()
            .where((e) => e.name == source.rotationName)
            .firstOrNull ??
        await repository.upsertCategory(name: source.rotationName);
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    var created = 0;
    var skipped = 0;
    var skippedPast = 0;
    for (var index = 0; index < episodes.length; index++) {
      final episode = episodes[index];
      if (onlyUpcoming && episode.date.isBefore(today)) {
        skippedPast++;
        continue;
      }
      final existing = repository.findOn(rotation.id, episode.date);
      if ((existing?.content?['filePath'] as String? ?? '').isNotEmpty) {
        skipped++;
        continue;
      }
      onProgress?.call(index + 1, episodes.length);
      final path = await resolveLocalPath(episode);
      if (path.trim().isEmpty) throw StateError('download vazio');
      await repository.upsertItem(
        ScheduledItem(
          id:
              existing?.id ??
              'sch-${rotation.id}-${episode.date.toIso8601String().substring(0, 10)}',
          categoryId: rotation.id,
          date: episode.date,
          name: episode.title,
          filePath: path,
          content: {'kind': 'file', 'filePath': path},
        ),
      );
      if (existing == null) {
        created++;
      } else {
        skipped++;
      }
    }
    return ProvaiImportReport(rotation.id, created, skipped, skippedPast);
  }
}
