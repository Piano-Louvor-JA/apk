// ignore_for_file: unrelated_type_equality_checks, unnecessary_null_comparison
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/utils/liturgy_format.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

void main() {
  group('LiturgyWeekday', () {
    test('tab order: comeca no domingo', () {
      expect(liturgyDayTabOrder.first, LiturgyWeekday.sunday);
      expect(liturgyDayTabOrder.last, LiturgyWeekday.saturday);
      expect(liturgyDayTabOrder.length, 7);
    });
  });

  group('LiturgyTypeRegistry', () {
    test('category tem cor amarela', () {
      expect(
        LiturgyTypeRegistry.colorFor(LiturgyItemType.category).toARGB32(),
        0xFFFFD600,
      );
    });

    test('music tem cor verde neon', () {
      expect(
        LiturgyTypeRegistry.colorFor(LiturgyItemType.music).toARGB32(),
        0xFF00E676,
      );
    });

    test('annotation tem cor laranja', () {
      expect(
        LiturgyTypeRegistry.colorFor(LiturgyItemType.annotation).toARGB32(),
        0xFFFF6D00,
      );
    });

    test('prayer tem cor azul', () {
      expect(
        LiturgyTypeRegistry.colorFor(LiturgyItemType.prayer).toARGB32(),
        0xFF42A5F5,
      );
    });

    test('verse tem cor roxa', () {
      expect(
        LiturgyTypeRegistry.colorFor(LiturgyItemType.verse).toARGB32(),
        0xFFAB47BC,
      );
    });

    test('allTypes tem todos os tipos suportados', () {
      expect(LiturgyTypeRegistry.allTypes.length, greaterThanOrEqualTo(5));
    });

    test('iconFor retorna IconData', () {
      expect(LiturgyTypeRegistry.iconFor(LiturgyItemType.music), isNotNull);
    });
  });

  group('LiturgyItem', () {
    test('fromJson mapeia campos', () {
      final item = LiturgyItem.fromJson({
        'id': 'abc',
        'type': 'music',
        'name': 'Hino 1',
        'subtitle': 'Regencia',
        'done': true,
        'durationMs': 180000,
        'accentColor': '#00E676',
      });
      expect(item.id, 'abc');
      expect(item.type, LiturgyItemType.music);
      expect(item.name, 'Hino 1');
      expect(item.subtitle, 'Regencia');
      expect(item.done, true);
      expect(item.durationMs, 180000);
      expect(item.accentColor, '#00E676');
    });

    test('fromJson com dados faltantes usa defaults', () {
      final item = LiturgyItem.fromJson({});
      expect(item.id, '');
      expect(item.type, LiturgyItemType.annotation);
      expect(item.name, '');
      expect(item.done, false);
      expect(item.durationMs, 0);
    });

    test('toJson roundtrip', () {
      const item = LiturgyItem(
        id: 'x',
        type: LiturgyItemType.prayer,
        name: 'Oracao',
      );
      final json = item.toJson();
      final parsed = LiturgyItem.fromJson(json);
      expect(parsed.id, 'x');
      expect(parsed.type, LiturgyItemType.prayer);
      expect(parsed.name, 'Oracao');
    });

    test('== por id', () {
      const a = LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'A');
      const b = LiturgyItem(id: '1', type: LiturgyItemType.verse, name: 'B');
      expect(a == b, true);
    });

    test('!= por id diferente', () {
      const a = LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'A');
      const b = LiturgyItem(id: '2', type: LiturgyItemType.music, name: 'A');
      expect(a == b, false);
    });

    test('hashCode consistente', () {
      const a = LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'A');
      const b = LiturgyItem(id: '1', type: LiturgyItemType.verse, name: 'B');
      expect(a.hashCode, b.hashCode);
    });

    test('== tipo diferente', () {
      const a = LiturgyItem(id: '1', type: LiturgyItemType.music, name: 'A');
      expect(a == 'str', false);
      expect(a == 42, false);
    });

    test('toString contem id e name', () {
      const item = LiturgyItem(
        id: '42',
        type: LiturgyItemType.music,
        name: 'Hino',
      );
      expect(item.toString(), contains('42'));
      expect(item.toString(), contains('Hino'));
    });

    test('copyWith altera apenas campos especificados', () {
      const original = LiturgyItem(
        id: '1',
        type: LiturgyItemType.music,
        name: 'Original',
      );
      final copy = original.copyWith(name: 'Editado', done: true);
      expect(copy.id, '1');
      expect(copy.name, 'Editado');
      expect(copy.done, true);
      expect(copy.type, LiturgyItemType.music);
    });

    test('copyWith sem done preserva done original', () {
      const original = LiturgyItem(
        id: '1',
        type: LiturgyItemType.music,
        name: 'Original',
        done: true,
      );
      final copy = original.copyWith(name: 'Trocou');
      expect(copy.done, true);
    });

    test('fromJson com filePaths lista multiplos arquivos', () {
      final item = LiturgyItem.fromJson({
        'id': 'x',
        'type': 'images',
        'name': 'Fotos',
        'filePaths': ['img1.jpg', 'img2.png', 'img3.gif'],
      });
      expect(item.filePaths.length, 3);
      expect(item.filePaths[0], 'img1.jpg');
      expect(item.filePaths[2], 'img3.gif');
    });

    test('fromJson com type desconhecido cai no orElse annotation', () {
      final item = LiturgyItem.fromJson({
        'id': 'x',
        'type': 'unknown_type',
        'name': 'Desconhecido',
      });
      expect(item.type, LiturgyItemType.annotation);
    });

    test('toJson mapeia other_files e online_video para wire format', () {
      const item1 = LiturgyItem(
        id: '1',
        type: LiturgyItemType.otherFiles,
        name: 'Doc',
      );
      expect(item1.toJson()['type'], 'other_files');

      const item2 = LiturgyItem(
        id: '2',
        type: LiturgyItemType.onlineVideo,
        name: 'Video',
      );
      expect(item2.toJson()['type'], 'online_video');
    });

    test('toJson inclui filePaths quando preenchido', () {
      const item = LiturgyItem(
        id: '1',
        type: LiturgyItemType.images,
        name: 'Fotos',
        filePaths: ['a.jpg', 'b.png'],
      );
      final json = item.toJson();
      expect(json['filePaths'], ['a.jpg', 'b.png']);
    });
  });

  group('LiturgyFormat', () {
    test('pad2 com 1 digito', () {
      expect(LiturgyFormat.pad2(5), '05');
    });

    test('pad2 com 2 digitos', () {
      expect(LiturgyFormat.pad2(12), '12');
    });

    test('formatElapsed 0 ms', () {
      expect(LiturgyFormat.formatElapsed(0), '00:00:00');
    });

    test('formatElapsed 90 segundos', () {
      expect(LiturgyFormat.formatElapsed(90000), '00:01:30');
    });

    test('formatElapsed 1 hora', () {
      expect(LiturgyFormat.formatElapsed(3600000), '01:00:00');
    });

    test('formatDurationLabel null retorna traco', () {
      expect(LiturgyFormat.formatDurationLabel(null), '\u2014');
    });

    test('formatDurationLabel 0 retorna traco', () {
      expect(LiturgyFormat.formatDurationLabel(0), '\u2014');
    });

    test('formatDurationLabel 180000 retorna 00:03:00', () {
      expect(LiturgyFormat.formatDurationLabel(180000), '00:03:00');
    });

    test('normalizeTimeHHmm valida HH:MM', () {
      expect(LiturgyFormat.normalizeTimeHHmm('09:30'), '09:30');
    });

    test('normalizeTimeHHmm aceita HH:MM:SS', () {
      expect(LiturgyFormat.normalizeTimeHHmm('09:30:45'), '09:30');
    });

    test('normalizeTimeHHmm rejeita hora > 23', () {
      expect(LiturgyFormat.normalizeTimeHHmm('25:00'), null);
    });

    test('normalizeTimeHHmm rejeita minuto > 59', () {
      expect(LiturgyFormat.normalizeTimeHHmm('10:60'), null);
    });

    test('normalizeTimeHHmm rejeita formato invalido', () {
      expect(LiturgyFormat.normalizeTimeHHmm('abc'), null);
    });

    test('normalizeTimeHHmm null retorna null', () {
      expect(LiturgyFormat.normalizeTimeHHmm(null), null);
    });
  });
}
