import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_timing.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

void main() {
  const cat = LiturgyItem(
    id: 'c',
    type: LiturgyItemType.category,
    name: 'Culto',
    startTime: '23:55',
  );
  const child = LiturgyItem(
    id: 'm',
    type: LiturgyItemType.music,
    name: 'Hino',
    categoryId: 'c',
    durationMs: 601000,
  );
  test('fim real vence estimativa, sem duração não inventa horário', () {
    expect(LiturgyTiming.categoryEnd(cat, [child]), '00:06');
    expect(
      LiturgyTiming.categoryEnd(cat.copyWith(endTime: '00:30'), [child]),
      '00:30',
    );
    expect(LiturgyTiming.categoryEnd(cat, []), isNull);
  });
  test('fim da sessão considera meia-noite e a duração dos filhos', () {
    expect(
      LiturgyTiming.estimatedEnd([
        cat,
        child,
        const LiturgyItem(
          id: 'b',
          type: LiturgyItemType.category,
          name: 'Anterior',
          startTime: '20:00',
          endTime: '21:00',
        ),
      ]),
      '00:06',
    );
  });
  test('dia do culto pertence à semana corrente, avulsa usa hoje', () {
    final now = DateTime(2026, 11, 12, 20);
    expect(
      LiturgyTiming.activeDate(LiturgyWeekday.sunday, now: now),
      DateTime(2026, 11, 8),
    );
    expect(
      LiturgyTiming.activeDate(LiturgyWeekday.saturday, now: now),
      DateTime(2026, 11, 14),
    );
    expect(LiturgyTiming.activeDate(null, now: now), DateTime(2026, 11, 12));
  });
  test('contagem usa deadline absoluto inclusive ao voltar do background', () {
    final started = DateTime(2026, 11, 12, 19, 45);
    expect(
      LiturgyTiming.remaining('20:45', started, DateTime(2026, 11, 12, 20, 15)),
      const Duration(minutes: 30),
    );
    expect(
      LiturgyTiming.remaining('20:45', started, DateTime(2026, 11, 12, 21)),
      Duration.zero,
    );
  });
}
