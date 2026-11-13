import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_page.dart';

/// O bloc da Liturgia nasce uma vez por página: reconstruir a página (tela
/// pai, hot reload) não pode trocar de bloc — senão o item adicionado vai
/// para um bloc e a tela escuta outro (só aparecia ao sair e voltar).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dia vazio permite criar momento sem exigir categoria', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LiturgyPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('liturgy-add-moment')), findsOneWidget);
    await tester.tap(find.byKey(const Key('liturgy-add-moment')));
    await tester.pumpAndSettle();
    expect(find.text('liturgy.types.music'), findsOneWidget);
    expect(find.text('liturgy.types.annotation'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('itens agendados avisam que ainda não existem no APK', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LiturgyPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liturgy-add-moment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('liturgy.types.scheduled'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('liturgy-type-coming-soon')), findsOneWidget);
    expect(find.text('liturgy.parity.scheduledComingSoon'), findsOneWidget);
    await tester.tap(find.text('common.close'));
    await tester.pumpAndSettle();
    // Continua no tipo anterior, sem os campos de agendado.
    expect(find.byKey(const Key('liturgy-type-coming-soon')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('reconstruir a página mantém o mesmo bloc e o item adicionado', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return const LiturgyPage();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    LiturgyBloc bloc() => BlocProvider.of<LiturgyBloc>(
      tester.element(find.byType(Scaffold).last),
    );
    final first = bloc();
    first.add(
      LiturgyAddItem(
        const LiturgyItem(
          id: 'c1',
          type: LiturgyItemType.category,
          name: 'Início de culto',
          subtitle: '',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Início de culto'), findsOneWidget);

    rebuild(() {});
    await tester.pumpAndSettle();
    expect(identical(bloc(), first), isTrue);
    expect(find.text('Início de culto'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(first.isClosed, isTrue);
  });
}
