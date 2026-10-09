library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_adapter.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_package.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_timestamps.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/local_custom_store.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncTimestamps.init();
  });

  LiturgyItem item(String t) =>
      LiturgyItem(id: 'x', type: LiturgyItemType.music, name: t);

  test('export contém liturgia com dados de todos os dias tocados', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LiturgyRepository(prefs);
    await repo.saveItems(LiturgyWeekday.saturday, [item('hino 1')]);
    await repo.saveNotes(LiturgyWeekday.saturday, 'nota');

    final pkg = await SyncAdapter(prefs).export();
    final lit = pkg.entities['liturgy']!;
    expect(lit.data['saturday'], isNotNull);
    expect(lit.modified, isNotNull);
  });

  test(
    'import aplicado: liturgia remota mais nova SOBRESCREVE local',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LiturgyRepository(prefs);
      await repo.saveItems(LiturgyWeekday.sunday, [item('antiga local')]);

      final remoto = SyncPackage(
        appVersion: '0.1.17',
        platform: 'web',
        exportedAt: DateTime.now().toUtc(),
        entities: {
          'liturgy': SyncEntity(
            type: 'liturgy',
            modified: DateTime.now().toUtc().add(const Duration(hours: 1)),
            data: {
              'sunday': {
                'items': [
                  {'id': 'y', 'type': 'music', 'name': 'nova remota'},
                ],
                'notes': 'nota remota',
              },
            },
          ),
        },
      );

      final r = await SyncAdapter(prefs).importPackage(remoto);
      expect(r.applied, contains('liturgy'));
      final carregada = repo.loadItems(LiturgyWeekday.sunday);
      expect(carregada.single.name, 'nova remota');
      expect(repo.loadNotes(LiturgyWeekday.sunday), 'nota remota');
    },
  );

  test('import NÃO sobrescreve quando local é mais novo (LWW)', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LiturgyRepository(prefs);
    await repo.saveItems(LiturgyWeekday.saturday, [item('local nova')]);

    final remoto = SyncPackage(
      appVersion: '0.1.17',
      platform: 'web',
      exportedAt: DateTime.now().toUtc(),
      entities: {
        'liturgy': SyncEntity(
          type: 'liturgy',
          modified: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
          data: {
            'saturday': {
              'items': [
                {'id': 'z', 'type': 'music', 'name': 'remota velha'},
              ],
              'notes': '',
            },
          },
        ),
      },
    );

    final r = await SyncAdapter(prefs).importPackage(remoto);
    expect(r.skipped, contains('liturgy'));
    expect(repo.loadItems(LiturgyWeekday.saturday).single.name, 'local nova');
  });

  test('import de entidade desconhecida é ignorada sem quebrar', () async {
    final prefs = await SharedPreferences.getInstance();
    final pkg = SyncPackage(
      appVersion: '9.9',
      platform: 'web',
      exportedAt: DateTime.now().toUtc(),
      entities: {
        'schedule': SyncEntity(
          type: 'schedule',
          modified: DateTime.now().toUtc(),
          data: {'x': 1},
        ),
      },
    );
    final r = await SyncAdapter(prefs).importPackage(pkg);
    expect(r.skipped, contains('schedule'));
  });

  test('round-trip: export do A importado no B reproduz liturgia', () async {
    final prefsA = await SharedPreferences.getInstance();
    final repoA = LiturgyRepository(prefsA);
    await repoA.saveItems(LiturgyWeekday.wednesday, [item('hino A')]);
    final pkg = await SyncAdapter(prefsA).export();

    SharedPreferences.setMockInitialValues({});
    await SyncTimestamps.init();
    final prefsB = await SharedPreferences.getInstance();
    await SyncAdapter(prefsB).importPackage(pkg);

    final repoB = LiturgyRepository(prefsB);
    expect(repoB.loadItems(LiturgyWeekday.wednesday).single.name, 'hino A');
  });

  test('settings e timerPresets exportados e aplicados no B', () async {
    final prefsA = await SharedPreferences.getInstance();
    await prefsA.setString('themeMode', 'dark');
    await prefsA.setInt('glassIntensity', 80);
    await prefsA.setString('timer.countdown.presets.v1', '[{"name":"culto"}]');
    await SyncTimestamps.touch('settings');
    await SyncTimestamps.touch('timerPresets');

    final pkg = await SyncAdapter(prefsA).export();
    SharedPreferences.setMockInitialValues({});
    await SyncTimestamps.init();
    final prefsB = await SharedPreferences.getInstance();
    final r = await SyncAdapter(prefsB).importPackage(pkg);

    expect(r.applied, containsAll(['settings', 'timerPresets']));
    expect(prefsB.getString('themeMode'), 'dark');
    expect(prefsB.getInt('glassIntensity'), 80);
    expect(
      prefsB.getString('timer.countdown.presets.v1'),
      '[{"name":"culto"}]',
    );
  });

  test('mediaCustomCatalog: round-trip export A → import B (t_c1ea317a)',
      () async {
    final dirA = await Directory.systemTemp.createTemp('sync_a');
    final dirB = await Directory.systemTemp.createTemp('sync_b');
    addTearDown(() async => await dirA.delete(recursive: true));
    addTearDown(() async => await dirB.delete(recursive: true));
    final storeA = LocalCustomStore(dirA);
    storeA.createLocalCollection('Coletânea Sacra');
    storeA.saveLocalMusic(collectionId: -1, name: 'Hino Sacro', lyric: 'G');
    await SyncTimestamps.touch('mediaCustomCatalog');

    final prefsA = await SharedPreferences.getInstance();
    final pkg = await SyncAdapter(prefsA, localCustomStore: storeA).export();
    expect(pkg.entities['mediaCustomCatalog'], isNotNull);

    final prefsB = await SharedPreferences.getInstance();
    final storeB = LocalCustomStore(dirB);
    // B nunca viu esta entidade: zera o LWW local antes do import.
    SharedPreferences.setMockInitialValues({});
    await SyncTimestamps.init();
    final prefsB2 = await SharedPreferences.getInstance();
    final r = await SyncAdapter(
      prefsB2,
      localCustomStore: storeB,
    ).importPackage(pkg);

    expect(r.applied, contains('mediaCustomCatalog'));
    expect(
      storeB.listLocalCollections().single['name'],
      'Coletânea Sacra',
    );
    expect(storeB.listLocalMusics(-1).single['name'], 'Hino Sacro');

    // LWW: pacote antigo não sobrescreve.
    final antigo = SyncPackage(
      appVersion: '0.1.0',
      platform: 'desktop',
      exportedAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      entities: {
        'mediaCustomCatalog': SyncEntity(
          type: 'mediaCustomCatalog',
          modified: DateTime.now().toUtc().subtract(const Duration(days: 2)),
          data: {
            'db': {
              'collections': [
                {'id': -1, 'name': 'antiga', 'created_at': 'x'},
              ],
              'musics': [],
            },
          },
        ),
      },
    );
    final r2 = await SyncAdapter(
      prefsB,
      localCustomStore: storeB,
    ).importPackage(antigo);
    expect(r2.skipped, contains('mediaCustomCatalog'));
    expect(storeB.listLocalCollections().single['name'], 'Coletânea Sacra');
  });

  test('preferences: round-trip com allowlist stage.settings.*', () async {
    final prefsA = await SharedPreferences.getInstance();
    await prefsA.setString('stage.settings.global', '{"bg":1,"size":90}');
    await prefsA.setString('stage.settings.hymns', '{"size":110}');
    await prefsA.setString('stage.settings.evil', '{"hack":true}');
    await SyncTimestamps.touch('preferences');

    final pkg = await SyncAdapter(prefsA).export();
    final pref = pkg.entities['preferences']!;
    expect(pref.data.containsKey('stage.settings.global'), isTrue);
    expect(pref.data.containsKey('stage.settings.evil'), isFalse);

    SharedPreferences.setMockInitialValues({});
    await SyncTimestamps.init();
    final prefsB = await SharedPreferences.getInstance();
    final r = await SyncAdapter(prefsB).importPackage(pkg);
    expect(r.applied, contains('preferences'));
    expect(prefsB.getString('stage.settings.global'), '{"bg":1,"size":90}');
    expect(prefsB.getString('stage.settings.hymns'), '{"size":110}');
  });
}
