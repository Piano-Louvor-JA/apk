library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/empty_state.dart';

void main() {
  group('EmptyState', () {
    testWidgets('exibe título', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyState(title: 'Nenhum hino encontrado')),
        ),
      );

      expect(find.text('Nenhum hino encontrado'), findsOneWidget);
    });

    testWidgets('exibe mensagem quando fornecida', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'Vazio',
              message: 'Tente buscar novamente mais tarde.',
            ),
          ),
        ),
      );

      expect(find.text('Vazio'), findsOneWidget);
      expect(find.text('Tente buscar novamente mais tarde.'), findsOneWidget);
    });

    testWidgets(
      'exibe botão de ação quando actionLabel + onAction fornecidos',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyState(
                title: 'Erro',
                actionLabel: 'Recarregar',
                onAction: () => tapped = true,
              ),
            ),
          ),
        );

        final button = find.text('Recarregar');
        expect(button, findsOneWidget);

        await tester.tap(button);
        await tester.pump();

        expect(tapped, isTrue);
      },
    );

    testWidgets('NÃO exibe botão quando onAction é null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyState(title: 'Vazio')),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
