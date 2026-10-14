import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_avulsa_page.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: LiturgyAvulsaPage()));
  // _init: SharedPreferences (mock) → repos → _load
  await tester.pumpAndSettle();
}

Future<LiturgyRepository> _seedItem(DateTime date) async {
  final prefs = await SharedPreferences.getInstance();
  final repo = LiturgyRepository(prefs);
  await repo.saveAvulsa(date, [
    LiturgyItem(id: 'a1', type: LiturgyItemType.otherFiles, name: 'Hino 1'),
    LiturgyItem(id: 'a2', type: LiturgyItemType.otherFiles, name: 'Hino 2'),
  ]);
  return repo;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LiturgyAvulsaPage — carregamento e estado vazio', () {
    testWidgets('sem itens mostra estado vazio e data de hoje', (tester) async {
      await _pump(tester);

      expect(find.byKey(const Key('avulsa-date-picker')), findsOneWidget);
      expect(
        find.textContaining(
          '${DateTime.now().day.toString().padLeft(2, '0')}/'
          '${DateTime.now().month.toString().padLeft(2, '0')}/',
        ),
        findsOneWidget,
      );
      // estado vazio: FAB habilitado (add primeiro item como categoria)
      expect(find.byKey(const Key('avulsa-add-item')), findsOneWidget);
    });

    testWidgets('com itens salvos lista e permite marcar feito', (
      tester,
    ) async {
      await _seedItem(DateTime.now());
      await _pump(tester);

      expect(find.text('Hino 1'), findsOneWidget);
      expect(find.text('Hino 2'), findsOneWidget);

      // marcar o primeiro como feito (ícone circulo vira check) e persiste
      await tester.tap(find.byIcon(TablerIcons.circle).first);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final repo = LiturgyRepository(prefs);
      final items = repo.loadAvulsa(DateTime.now());
      expect(items.first.done, isTrue);
    });
  });

  group('LiturgyAvulsaPage — trava (lock)', () {
    testWidgets('travar esconde FAB, desabilita delete e impede editar', (
      tester,
    ) async {
      await _seedItem(DateTime.now());
      await _pump(tester);

      await tester.tap(
        find.byKey(const Key('avulsa-lock-toggle')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // delete desabilitado (onPressed null → não abre diálogo)
      final delete = tester.widget<IconButton>(
        find.byKey(const Key('avulsa-delete')),
      );
      expect(delete.onPressed, isNull);
      // FAB some quando travado (floatingActionButton: null)
      expect(find.byKey(const Key('avulsa-add-item')), findsNothing);
      // tap no check NÃO altera (map skip em locked)
      await tester.tap(find.byIcon(TablerIcons.circle).first);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final items = LiturgyRepository(prefs).loadAvulsa(DateTime.now());
      expect(items.first.done, isFalse);
    });

    testWidgets('destravar volta a habilitar', (tester) async {
      await _seedItem(DateTime.now());
      await _pump(tester);

      await tester.tap(
        find.byKey(const Key('avulsa-lock-toggle')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('avulsa-lock-toggle')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final delete = tester.widget<IconButton>(
        find.byKey(const Key('avulsa-delete')),
      );
      expect(delete.onPressed, isNotNull);
    });
  });

  group('LiturgyAvulsaPage — excluir dia', () {
    testWidgets('excluir com confirm apaga itens do dia', (tester) async {
      await _seedItem(DateTime.now());
      await _pump(tester);

      await tester.tap(find.byKey(const Key('avulsa-delete')));
      await tester.pumpAndSettle();

      // diálogo de confirmação: confirmar (botão preenchido destrutivo)
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect((await _listNow()).isEmpty, isTrue);
      expect(find.text('Hino 1'), findsNothing);
    });

    testWidgets('cancelar mantém itens', (tester) async {
      await _seedItem(DateTime.now());
      await _pump(tester);

      await tester.tap(find.byKey(const Key('avulsa-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      expect(find.text('Hino 1'), findsOneWidget);
    });
  });

  group('LiturgyAvulsaPage — reordenar', () {
    testWidgets('drag handle presente quando destravado', (tester) async {
      await _seedItem(DateTime.now());
      await _pump(tester);

      // 2 itens → 2 drag handles (ReorderableDragStartListener)
      expect(
        find.byType(ReorderableDragStartListener),
        findsNWidgets(2),
      );
    });
  });
}

Future<List<LiturgyItem>> _listNow() async {
  final prefs = await SharedPreferences.getInstance();
  return LiturgyRepository(prefs).loadAvulsa(DateTime.now());
}
