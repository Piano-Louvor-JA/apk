library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_package.dart';

void main() {
  final t1 = DateTime.utc(2026, 8, 16, 10);
  final t2 = DateTime.utc(2026, 8, 16, 14);

  SyncEntity ent(String type, DateTime m, [Map<String, dynamic>? d]) =>
      SyncEntity(type: type, modified: m, data: d ?? {'k': 'v'});

  group('SyncPackage (formato .louvorja cross-platform)...'.trim(), () {
    test('encode/decode round-trip preserva entidades', () {
      final pkg = SyncPackage(
        appVersion: '0.1.17',
        platform: 'mobile',
        exportedAt: t1,
        entities: {
          'liturgy:2026-08-22': ent('liturgy', t1, {'weekday': 'sabado'}),
          'favorites': ent('favorites', t2, {
            'ids': [1, 2],
          }),
        },
      );
      final raw = pkg.encode();
      final back = SyncPackage.decode(raw);
      expect(back.entities.length, 2);
      expect(back.entities['favorites']!.data['ids'], [1, 2]);
      expect(back.entities['liturgy:2026-08-22']!.data['weekday'], 'sabado');
    });

    test('merge LWW mantém versão mais recente por entidade', () {
      final a = SyncPackage(
        appVersion: 'a',
        platform: 'mobile',
        exportedAt: t1,
        entities: {
          'liturgy:2026-08-22': ent('liturgy', t2, {'v': 'nova'}),
          'favorites': ent('favorites', t1, {'v': 'antiga'}),
        },
      );
      final b = SyncPackage(
        appVersion: 'b',
        platform: 'web',
        exportedAt: t2,
        entities: {
          'liturgy:2026-Vue.': ent('liturgy', t2, {'v': 'velha'}),
          'favorites': ent('favorites', t2, {'v': 'nova'}),
        },
      );
      // liturgia: a tem t2 14:00 == b tem t2 14:00 — isAfter false → mantém a
      final m = a.merge(b);
      expect(m.entities['favorites']!.data['v'], 'nova'); // b ganhou (t2>t1)
      expect(m.entities['liturgy:2026-08-22']!.data['v'], 'nova');
    });

    test('merge LWW: mesma entidade com timestamps iguais mantém local', () {
      final a = SyncPackage(
        appVersion: 'a',
        platform: 'mobile',
        exportedAt: t1,
        entities: {
          'liturgy:d': ent('liturgy', t2, {'v': 'local'}),
        },
      );
      final b = SyncPackage(
        appVersion: 'b',
        platform: 'web',
        exportedAt: t2,
        entities: {
          'liturgy:d': ent('liturgy', t2, {'v': 'remoto'}),
        },
      );
      final m = a.merge(b);
      expect(m.entities['liturgy:d']!.data['v'], 'local');
    });

    test('schema do futuro lança SyncSchemaException', () {
      final j = '{"schema": 99, "entities": {}}';
      expect(() => SyncPackage.decode(j), throwsA(isA<SyncSchemaException>()));
    });

    test('entidade desconhecida passa ilesa (cross-version seguro)', () {
      final pkg = SyncPackage(
        appVersion: '0.1.17',
        platform: 'web',
        exportedAt: t1,
        entities: {
          'schedule': ent('schedule', t1, {'when': 'domingo'}),
        },
      );
      final raw = pkg.encode();
      final back = SyncPackage.decode(raw);
      expect(back.entities['schedule']!.data['when'], 'domingo');
    });
  });
}
