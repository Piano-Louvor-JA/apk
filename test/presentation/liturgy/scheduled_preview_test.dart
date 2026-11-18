import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/scheduled_item_preview.dart';

void main() {
  testWidgets(
    'prévia de agendado carrega com idioma e atualiza ao editar agenda',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      final repo = ScheduledRepository(await SharedPreferences.getInstance());
      final rotation = await repo.upsertCategory(name: 'Avisos');
      await repo.upsertItem(
        ScheduledItem(
          id: 'e',
          categoryId: rotation.id,
          date: DateTime(2026, 11, 14),
          name: 'Antes',
          content: {'kind': 'annotation', 'text': 'Texto'},
        ),
      );
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('pt', 'BR')],
          path: 'assets/translations',
          startLocale: const Locale('pt', 'BR'),
          saveLocale: false,
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Scaffold(
                body: ScheduledItemPreview(
                  item: LiturgyItem(
                    id: 's',
                    type: LiturgyItemType.scheduled,
                    name: 'Avisos',
                    scheduledRotationId: rotation.id,
                  ),
                  date: DateTime(2026, 11, 14),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Antes'), findsOneWidget);
      await repo.upsertItem(
        ScheduledItem(
          id: 'e',
          categoryId: rotation.id,
          date: DateTime(2026, 11, 14),
          name: 'Depois',
          content: {'kind': 'annotation', 'text': 'Texto'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Depois'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
