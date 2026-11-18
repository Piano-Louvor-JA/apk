import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_adapter.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_package.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_timestamps.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'pacote leva as rotações e os conteúdos agendados com data de calendário',
    () async {
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      await SyncTimestamps.init(prefs);
      final repo = ScheduledRepository(prefs);
      final category = await repo.upsertCategory(name: 'Provai');
      await repo.upsertItem(
        ScheduledItem(
          id: 'e',
          categoryId: category.id,
          date: DateTime(2026, 11, 14, 23, 59),
          name: 'Episódio',
          content: {
            'kind': 'online_video',
            'url': 'https://example.org/video.mp4',
          },
        ),
      );
      final package = await SyncAdapter(prefs).export();
      expect(package.entities['scheduled'], isNotNull);
      expect(
        (package.entities['scheduled']!.data['items'] as List).single['date'],
        '2026-11-14',
      );
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      await SyncTimestamps.init(prefs);
      final result = await SyncAdapter(prefs).importPackage(package);
      expect(result.applied, contains('scheduled'));
      final restored = ScheduledRepository(prefs);
      expect(restored.loadCategories().single.name, 'Provai');
      expect(
        restored.findOn(category.id, DateTime(2026, 11, 14))!.content?['kind'],
        'online_video',
      );
    },
  );
  test(
    'importar ES usa seu relógio e não o de uma edição PT mais recente',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await SyncTimestamps.init(prefs);
      await LiturgyRepository(prefs, locale: 'pt').createCustom('Português');
      final esState = LiturgyRepository.emptyState();
      esState['customLiturgies'] = [
        {'id': 'es', 'name': 'Español', 'items': [], 'notes': ''},
      ];
      final package = SyncPackage(
        appVersion: 'test',
        platform: 'desktop',
        exportedAt: DateTime(2026),
        entities: {
          'liturgy': SyncEntity(
            type: 'liturgy',
            modified: DateTime(2026),
            data: {'locale': 'es', 'state': esState},
          ),
        },
      );
      final result = await SyncAdapter(prefs).importPackage(package);
      expect(result.applied, ['liturgy']);
      expect(
        LiturgyRepository(
          prefs,
          locale: 'es',
        ).loadCustomLiturgies().single.name,
        'Español',
      );
      expect(
        LiturgyRepository(
          prefs,
          locale: 'pt',
        ).loadCustomLiturgies().single.name,
        'Português',
      );
    },
  );
  test(
    'pacote transfere semana, avulsas, horários, cadeado e idioma sem perder compatibilidade antiga',
    () async {
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      await SyncTimestamps.init(prefs);
      final repo = LiturgyRepository(prefs, locale: 'pt');
      final custom = await repo.createCustom('Especial');
      await repo.writeItems('custom:${custom.id}', [
        const LiturgyItem(
          id: 'x',
          type: LiturgyItemType.annotation,
          name: 'Aviso',
          notesHtml: '<p><b>Texto</b></p>',
        ),
      ]);
      await repo.writeSessionTimes(
        'custom:${custom.id}',
        startTime: '08:00',
        endTime: '09:00',
      );
      await repo.writeLock('custom:${custom.id}', true);
      await repo.saveItems(LiturgyWeekday.saturday, [
        const LiturgyItem(id: 'm', type: LiturgyItemType.music, name: 'Hino'),
      ]);
      final package = await SyncAdapter(prefs).export();
      expect(package.liturgy!.data['saturday'], isA<Map>());
      expect(package.liturgy!.data['state']['customLiturgies'], hasLength(1));
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      await SyncTimestamps.init(prefs);
      await SyncAdapter(prefs).importPackage(package);
      final other = LiturgyRepository(prefs);
      final restored = other.loadCustomLiturgies().single;
      expect(restored.name, 'Especial');
      expect(restored.startTime, '08:00');
      expect(restored.items.single.notesHtml, '<p><b>Texto</b></p>');
      expect(other.readLock('custom:${custom.id}'), isTrue);
      expect(other.loadItems(LiturgyWeekday.saturday).single.name, 'Hino');
    },
  );
}
