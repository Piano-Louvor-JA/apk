import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_item_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Keys de tradução cruas (sem bundle no teste) esticam os Rows do dialog —
    // overflow de layout é ruído AQUI, não comportamento sob teste.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
      original?.call(details);
    };
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    LiturgyItem? existing,
    required ValueChanged<LiturgyItem> onSubmit,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    await tester.pumpWidget(
      MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 0.5),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showLiturgyItemDialog(
                    ctx,
                    existing: existing,
                    onSubmit: onSubmit,
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets(
    'edição de música importada: subtitle vazio + name preenchido → save usa name',
    (tester) async {
      LiturgyItem? saved;
      const existing = LiturgyItem(
        id: '1',
        type: LiturgyItemType.music,
        name: 'Hino Importado',
        subtitle: '',
        musicId: 42,
      );
      await pumpDialog(tester, existing: existing, onSubmit: (i) => saved = i);

      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(saved, isNotNull);
      expect(saved!.name, 'Hino Importado');
    },
  );

  testWidgets(
    'edição com name vazio e subtitle preenchido → cascata subtitle → name (app a60ddfd)',
    (tester) async {
      LiturgyItem? saved;
      const existing = LiturgyItem(
        id: '2',
        type: LiturgyItemType.music,
        name: '',
        subtitle: 'Título do .slja',
        musicId: 43,
      );
      await pumpDialog(tester, existing: existing, onSubmit: (i) => saved = i);

      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(saved, isNotNull);
      expect(saved!.name, 'Título do .slja');
    },
  );
}
