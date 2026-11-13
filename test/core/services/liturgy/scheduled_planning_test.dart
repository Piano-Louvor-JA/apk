import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/scheduled_planning.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'colar trimestre cria rotações e duplicar evita datas já ocupadas',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ScheduledRepository(await SharedPreferences.getInstance());
      final planner = ScheduledPlanning(repo);
      final report = await planner.paste(
        '14/11\ninicial: 42 - Hino\nprovai: https://example.org/video.mp4',
        year: 2026,
        autoCreateSlots: true,
      );
      expect(report.created, 2);
      expect(repo.loadCategories().length, 2);
      expect(repo.loadItems().last.content?['kind'], 'online_video');
      final rotation = repo.loadCategories().first;
      expect(
        await planner.duplicateQuarter(
          rotation.id,
          from: DateTime(2026, 11, 14),
          weeks: 13,
        ),
        1,
      );
      expect(
        await planner.duplicateQuarter(
          rotation.id,
          from: DateTime(2026, 11, 14),
          weeks: 0,
        ),
        0,
      );
      expect(
        repo
            .loadItems()
            .where((e) => e.categoryId == rotation.id)
            .map((e) => e.content?['musicId']),
        [42, 42],
      );
    },
  );
  test('slot sem mapeamento é relatado sem gravar entrada errada', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScheduledRepository(await SharedPreferences.getInstance());
    final report = await ScheduledPlanning(
      repo,
    ).paste('14/11\ninicial: 42 - Hino', year: 2026);
    expect(report.unmappedSlots, ['inicial']);
    expect(repo.loadItems(), isEmpty);
  });
}
