import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/provai_import.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/provai_catalog.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'edições ficam em rotações separadas e reimportação não duplica conteúdo baixado',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ScheduledRepository(await SharedPreferences.getInstance());
      final importer = ProvaiImport(repo);
      final episode = ProvaiEpisode(
        date: DateTime(2026, 11, 14),
        title: 'Fidelidade',
        url: 'https://example.org/a.mp4',
      );
      var downloads = 0;
      Future<String> resolve(ProvaiEpisode episode) async {
        downloads++;
        return '/download.mp4';
      }

      await importer.apply(
        ProvaiCatalog.source('pt', 2026, 4)!,
        [episode],
        resolve,
        now: DateTime(2026, 11, 12),
      );
      await importer.apply(
        ProvaiCatalog.source('pt', 2026, 4)!,
        [episode],
        resolve,
        now: DateTime(2026, 11, 12),
      );
      await importer.apply(
        ProvaiCatalog.source('es', 2026, 4)!,
        [episode],
        resolve,
        now: DateTime(2026, 11, 12),
      );
      expect(downloads, 2);
      expect(repo.loadItems().length, 2);
      expect(repo.loadCategories().map((e) => e.name), [
        'Provai e Vede',
        'Probad y Ved',
      ]);
    },
  );
}
