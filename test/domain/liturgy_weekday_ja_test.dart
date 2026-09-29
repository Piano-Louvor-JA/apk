// Testa o mapeamento dia .ja Delphi → LiturgyWeekday.
// Delphi: NOMES_DIAS[1]='Domingo' ... [7]='Sábado' (fmCopiaLiturgiaDia.pas).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

void main() {
  test('fromJaDay: 1=domingo até 7=sábado', () {
    expect(LiturgyWeekdayJa.fromJaDay(1), LiturgyWeekday.sunday);
    expect(LiturgyWeekdayJa.fromJaDay(2), LiturgyWeekday.monday);
    expect(LiturgyWeekdayJa.fromJaDay(3), LiturgyWeekday.tuesday);
    expect(LiturgyWeekdayJa.fromJaDay(4), LiturgyWeekday.wednesday);
    expect(LiturgyWeekdayJa.fromJaDay(5), LiturgyWeekday.thursday);
    expect(LiturgyWeekdayJa.fromJaDay(6), LiturgyWeekday.friday);
    expect(LiturgyWeekdayJa.fromJaDay(7), LiturgyWeekday.saturday);
    expect(LiturgyWeekdayJa.fromJaDay(0), isNull);
    expect(LiturgyWeekdayJa.fromJaDay(8), isNull);
  });
}
