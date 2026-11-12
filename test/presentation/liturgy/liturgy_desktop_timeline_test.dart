import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_page.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'timeline ${brightness.name}: horários, notas e índice de cada bloco',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({});
        final repo = LiturgyRepository(await SharedPreferences.getInstance());
        await repo.saveItems(LiturgyWeekday.sunday, [
          const LiturgyItem(
            id: 'a',
            type: LiturgyItemType.category,
            name: 'Abertura',
            startTime: '08:30',
            endTime: '09:30',
          ),
          const LiturgyItem(
            id: 'm',
            type: LiturgyItemType.music,
            name: 'Hino',
            categoryId: 'a',
            subtitle: 'Álbum',
            complementaryTitle: 'Entrada',
            notes: 'Cantar duas vezes',
          ),
          const LiturgyItem(
            id: 'b',
            type: LiturgyItemType.category,
            name: 'Encerramento',
          ),
        ]);
        final bloc = LiturgyBloc(repo)
          ..add(const LiturgyLoadRequested(LiturgyWeekday.sunday));
        await bloc.stream.first;
        addTearDown(bloc.close);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: LiturgyPage(testBloc: bloc),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('08:30 – 09:30'), findsOneWidget);
        expect(find.text('Cantar duas vezes'), findsOneWidget);
        expect(find.text('Entrada — Hino'), findsOneWidget);
        expect(
          tester
              .widgetList<ReorderableDragStartListener>(
                find.byType(ReorderableDragStartListener),
              )
              .map((e) => e.index),
          [0, 1],
        );
        await expectLater(
          find.byType(ReorderableListView),
          matchesGoldenFile('goldens/liturgy_timeline_${brightness.name}.png'),
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
